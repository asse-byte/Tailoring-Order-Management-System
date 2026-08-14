const express = require('express');
const db = require('../db');
const { asyncH, dateStr, pagination } = require('../util');

// Mounted manager-only in app.js — a full business report, never the secretary.
// Extends the finance summary with activity stats (clients, orders, top
// tailors) for a printable monthly/yearly report + an advanced stats board.
const router = express.Router();

/** Fraction of a monthly salary owed for [from, to] (day-fraction per month). */
function salaryMonthsFactor(from, to) {
  const start = new Date(`${from}T00:00:00Z`);
  const end = new Date(`${to}T00:00:00Z`);
  if (Number.isNaN(start) || Number.isNaN(end) || end < start) return 0;
  let factor = 0;
  let y = start.getUTCFullYear();
  let m = start.getUTCMonth();
  while (y < end.getUTCFullYear() || (y === end.getUTCFullYear() && m <= end.getUTCMonth())) {
    const daysInMonth = new Date(Date.UTC(y, m + 1, 0)).getUTCDate();
    const overlapStart = Math.max(start.getTime(), Date.UTC(y, m, 1));
    const overlapEnd = Math.min(end.getTime(), Date.UTC(y, m, daysInMonth));
    if (overlapEnd >= overlapStart) {
      factor += (Math.round((overlapEnd - overlapStart) / 86400000) + 1) / daysInMonth;
    }
    m += 1;
    if (m > 11) { m = 0; y += 1; }
  }
  return factor;
}

router.get('/summary', asyncH(async (req, res) => {
  if (req.user && req.user.role !== 'manager') {
    return res.status(403).json({ error: 'Accès réservé au manager.' });
  }
  const today = new Date().toISOString().slice(0, 10);
  const from = dateStr(req.query.from) || `${today.slice(0, 8)}01`;
  const to = dateStr(req.query.to) || today;

  const [
    sales, ordersRevenue, salesCost, ordersCost, wages, expenses, salaries, salaryPayments,
    newClients, servedClients, ordersCreated, ordersDelivered, ordersActive,
    productsUnits, topTailors,
  ] = await Promise.all([
    db.query(
      `SELECT COALESCE(SUM(total), 0)::bigint AS v FROM sales_effective
       WHERE NOT voided AND sold_at >= $1::date AND sold_at < $2::date + 1`, [from, to]),
    db.query(
      `SELECT COALESCE(SUM(amount), 0)::bigint AS v
       FROM order_payments_effective
       WHERE NOT voided AND paid_at BETWEEN $1::date AND $2::date`, [from, to]),
    db.query(
      `SELECT COALESCE(SUM(se.qty * p.cost_price), 0)::bigint AS v
       FROM sales_effective se JOIN products p ON se.item_id = p.id
       WHERE se.kind = 'produit' AND NOT se.voided
         AND se.sold_at >= $1::date AND se.sold_at < $2::date + 1`, [from, to]),
    db.query(
      `SELECT COALESCE(SUM(se.qty * m.cost_price), 0)::bigint AS v
       FROM sales_effective se JOIN pret_a_porter_models m ON se.item_id = m.id
       WHERE se.kind = 'pret_a_porter' AND NOT se.voided
         AND se.sold_at >= $1::date AND se.sold_at < $2::date + 1`, [from, to]),
    db.query(
      `SELECT COALESCE(SUM(amount), 0)::bigint AS v FROM tailor_entries_effective
       WHERE entry_date BETWEEN $1::date AND $2::date`, [from, to]),
    db.query(
      `SELECT COALESCE(SUM(amount), 0)::bigint AS v FROM expenses_effective
       WHERE NOT voided AND spent_at >= $1::date AND spent_at < $2::date + 1`, [from, to]),
    db.query(
      `SELECT COALESCE(SUM(p.monthly_salary), 0)::bigint AS v
       FROM staff_pay p JOIN staff s ON s.id = p.staff_id
       WHERE s.active AND p.monthly_salary IS NOT NULL`),
    db.query(
      `SELECT COALESCE(SUM(amount), 0)::bigint AS v
       FROM salary_payments_effective
       WHERE NOT voided AND paid_at BETWEEN $1::date AND $2::date`, [from, to]),
    // New clients registered in the window.
    db.query(
      `SELECT COUNT(*)::int AS v FROM clients
       WHERE created_at::date BETWEEN $1::date AND $2::date`, [from, to]),
    // Distinct clients whose order was DELIVERED in the window (served).
    db.query(
      `SELECT COUNT(DISTINCT client_id)::int AS v FROM orders
       WHERE status = 'livre' AND delivered_date BETWEEN $1::date AND $2::date`, [from, to]),
    db.query(
      `SELECT COUNT(*)::int AS v FROM orders
       WHERE created_at::date BETWEEN $1::date AND $2::date`, [from, to]),
    db.query(
      `SELECT COUNT(*)::int AS v FROM orders
       WHERE status = 'livre' AND delivered_date BETWEEN $1::date AND $2::date`, [from, to]),
    db.query(
      "SELECT COUNT(*)::int AS v FROM orders WHERE status <> 'livre'"),
    // Units of products sold (effective, non-voided).
    db.query(
      `SELECT COALESCE(SUM(qty), 0)::int AS v FROM sales_effective
       WHERE kind = 'produit' AND NOT voided
         AND sold_at >= $1::date AND sold_at < $2::date + 1`, [from, to]),
    // Top tailors by amount earned in the window.
    db.query(
      `SELECT e.tailor_id,
              COALESCE(s.full_name, MAX(e.tailor_name_snapshot)) AS tailor_name,
              (s.id IS NULL) AS tailor_deleted,
              SUM(e.pieces_count)::int AS pieces_total,
              SUM(e.amount)::int       AS amount_total
       FROM tailor_entries_effective e LEFT JOIN staff s ON s.id = e.tailor_id
       WHERE e.entry_date BETWEEN $1::date AND $2::date
       GROUP BY e.tailor_id, s.full_name, s.id
       ORDER BY amount_total DESC LIMIT 10`, [from, to]),
  ]);

  const salesTotal = Number(sales.rows[0].v);
  const ordersTotal = Number(ordersRevenue.rows[0].v);
  const cogs = Number(salesCost.rows[0].v) + Number(ordersCost.rows[0].v);
  const wagesTotal = Number(wages.rows[0].v);
  const expensesTotal = Number(expenses.rows[0].v);
  const actualSalaryPaid = Number(salaryPayments.rows[0].v);
  const proratedSalaries = Math.round(Number(salaries.rows[0].v) * salaryMonthsFactor(from, to));
  const salariesTotal = Math.max(actualSalaryPaid, proratedSalaries);
  const revenue = salesTotal + ordersTotal;
  const costs = cogs + wagesTotal + salariesTotal + expensesTotal;

  res.json({
    from,
    to,
    revenue: { sales: salesTotal, orders: ordersTotal, total: revenue },
    costs: {
      cost_of_goods_sold: cogs,
      tailor_wages: wagesTotal,
      salaries: salariesTotal,
      expenses: expensesTotal,
      total: costs,
    },
    net_profit: revenue - costs,
    clients: {
      new: newClients.rows[0].v,
      served: servedClients.rows[0].v,
    },
    orders: {
      created: ordersCreated.rows[0].v,
      delivered: ordersDelivered.rows[0].v,
      active: ordersActive.rows[0].v,
    },
    products_sold_units: productsUnits.rows[0].v,
    top_tailors: topTailors.rows,
  });
}));

// ---------------------------------------------------------------------------
// Live KPI tiles for the home dashboard. Manager-only by virtue of the
// /api/reports mount (app.js) — it carries today's cash and the outstanding
// client debt, which rule 1 keeps away from the secretary.
//
// "Outstanding" is computed over every order that is neither cancelled nor
// fully settled, from the append-only effective views: the order's derived
// total minus the cash actually collected against it. Cancelled orders are
// excluded — they are archived, not owed.
// ---------------------------------------------------------------------------
const ORDER_BALANCES = `
  SELECT o.id, o.client_id, o.status,
         COALESCE(it.total, 0)::int  AS total,
         COALESCE(pay.paid, 0)::int  AS paid,
         (COALESCE(it.total, 0) - COALESCE(pay.paid, 0))::int AS reste
  FROM orders o
  LEFT JOIN LATERAL (
    SELECT SUM(line_total)::int AS total FROM order_items_effective
    WHERE order_id = o.id
  ) it ON true
  LEFT JOIN LATERAL (
    SELECT SUM(amount)::int AS paid FROM order_payments_effective
    WHERE order_id = o.id AND NOT voided
  ) pay ON true
  WHERE o.status <> 'annule'`;

router.get('/dashboard', asyncH(async (req, res) => {
  const [today, cash, byStatus, debt] = await Promise.all([
    db.query(
      `SELECT COUNT(*)::int AS v FROM orders
       WHERE created_at::date = CURRENT_DATE AND status <> 'annule'`),
    db.query(
      `SELECT COALESCE(SUM(amount), 0)::bigint AS v
       FROM order_payments_effective
       WHERE NOT voided AND paid_at = CURRENT_DATE`),
    db.query(
      `SELECT status, COUNT(*)::int AS n FROM orders
       WHERE status <> 'annule' GROUP BY status`),
    db.query(
      `SELECT COUNT(*)::int                         AS orders_count,
              COUNT(DISTINCT client_id)::int        AS clients_count,
              COALESCE(SUM(reste), 0)::bigint       AS total
       FROM (${ORDER_BALANCES}) b
       WHERE b.reste > 0`),
  ]);

  const counts = Object.fromEntries(byStatus.rows.map((r) => [r.status, r.n]));

  res.json({
    date: new Date().toISOString().slice(0, 10),
    today: {
      orders_created: today.rows[0].v,
      payments_collected: Number(cash.rows[0].v),
    },
    orders: {
      en_attente: counts.en_attente || 0,
      en_cours: counts.en_cours || 0,
      termine: counts.termine || 0,
      livre: counts.livre || 0,
    },
    debt: {
      orders_count: debt.rows[0].orders_count,
      clients_count: debt.rows[0].clients_count,
      total: Number(debt.rows[0].total),
    },
  });
}));

// Delivered orders that still carry an unpaid balance — the debt-reminder list.
// Manager-only like the rest of /api/reports. Returns the client's phone so the
// app can open a prefilled WhatsApp reminder (client-side wa.me, no provider).
router.get('/unpaid-orders', asyncH(async (req, res) => {
  const { limit, offset } = pagination(req, 50, 200);
  const { rows } = await db.query(
    `SELECT b.id, b.total, b.paid, b.reste, o.delivered_date, o.created_at,
            COALESCE(c.full_name, o.client_name_snapshot) AS client_name,
            c.phone AS client_phone, (c.id IS NULL) AS client_deleted
     FROM (${ORDER_BALANCES}) b
     JOIN orders o  ON o.id = b.id
     LEFT JOIN clients c ON c.id = o.client_id
     WHERE b.reste > 0 AND b.status = 'livre'
     ORDER BY o.delivered_date DESC NULLS LAST, o.created_at DESC
     LIMIT $1 OFFSET $2`, [limit, offset]);

  const { rows: sum } = await db.query(
    `SELECT COALESCE(SUM(reste), 0)::bigint AS v, COUNT(*)::int AS n
     FROM (${ORDER_BALANCES}) b WHERE b.reste > 0 AND b.status = 'livre'`);

  res.json({
    items: rows,
    total_due: Number(sum[0].v),
    total_count: sum[0].n,
    limit,
    offset,
  });
}));

module.exports = router;
