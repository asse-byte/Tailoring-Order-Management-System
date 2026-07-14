const express = require('express');
const db = require('../db');
const { asyncH, dateStr } = require('../util');

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
  const today = new Date().toISOString().slice(0, 10);
  const from = dateStr(req.query.from) || `${today.slice(0, 8)}01`;
  const to = dateStr(req.query.to) || today;

  const [
    sales, ordersRevenue, salesCost, ordersCost, wages, expenses, salaries,
    newClients, servedClients, ordersCreated, ordersDelivered, ordersActive,
    productsUnits, topTailors,
  ] = await Promise.all([
    db.query(
      `SELECT COALESCE(SUM(total), 0)::bigint AS v FROM sales_effective
       WHERE NOT voided AND sold_at >= $1::date AND sold_at < $2::date + 1`, [from, to]),
    db.query(
      `SELECT COALESCE(SUM(oie.line_total), 0)::bigint AS v
       FROM order_items_effective oie JOIN orders o ON o.id = oie.order_id
       WHERE o.status = 'livre' AND o.delivered_date BETWEEN $1::date AND $2::date`, [from, to]),
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
       WHERE NOT voided AND spent_at BETWEEN $1::date AND $2::date`, [from, to]),
    db.query(
      `SELECT COALESCE(SUM(p.monthly_salary), 0)::bigint AS v
       FROM staff_pay p JOIN staff s ON s.id = p.staff_id
       WHERE s.active AND p.monthly_salary IS NOT NULL`),
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
      `SELECT e.tailor_id, s.full_name AS tailor_name,
              SUM(e.pieces_count)::int AS pieces_total,
              SUM(e.amount)::int       AS amount_total
       FROM tailor_entries_effective e JOIN staff s ON s.id = e.tailor_id
       WHERE e.entry_date BETWEEN $1::date AND $2::date
       GROUP BY e.tailor_id, s.full_name
       ORDER BY amount_total DESC LIMIT 10`, [from, to]),
  ]);

  const salesTotal = Number(sales.rows[0].v);
  const ordersTotal = Number(ordersRevenue.rows[0].v);
  const cogs = Number(salesCost.rows[0].v) + Number(ordersCost.rows[0].v);
  const wagesTotal = Number(wages.rows[0].v);
  const expensesTotal = Number(expenses.rows[0].v);
  const salariesTotal = Math.round(Number(salaries.rows[0].v) * salaryMonthsFactor(from, to));
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

module.exports = router;
