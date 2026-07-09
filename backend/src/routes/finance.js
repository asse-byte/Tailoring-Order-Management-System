const express = require('express');
const db = require('../db');
const { asyncH, dateStr } = require('../util');

// Mounted manager-only in app.js — THE financial screen's data source.
const router = express.Router();

/** Number of calendar months touched by [from, to] (informational label). */
function monthsTouched(from, to) {
  const [fy, fm] = from.split('-').map(Number);
  const [ty, tm] = to.split('-').map(Number);
  return Math.max((ty * 12 + tm) - (fy * 12 + fm) + 1, 1);
}

/**
 * Sum of calendar-month fractions covered by [from, to] inclusive, used to
 * prorate fixed monthly salaries. A full calendar month contributes 1.0; a
 * single day of a 31-day month contributes 1/31 — so a day/week filter is no
 * longer charged a whole month of salary (which distorted net profit).
 */
function proratedSalaryMonths(from, to) {
  const start = new Date(`${from}T00:00:00Z`);
  const end = new Date(`${to}T00:00:00Z`);
  if (end < start) return 0;
  let fraction = 0;
  let y = start.getUTCFullYear();
  let m = start.getUTCMonth(); // 0-based
  const endY = end.getUTCFullYear();
  const endM = end.getUTCMonth();
  while (y < endY || (y === endY && m <= endM)) {
    const daysInMonth = new Date(Date.UTC(y, m + 1, 0)).getUTCDate();
    const lo = Math.max(start.getTime(), Date.UTC(y, m, 1));
    const hi = Math.min(end.getTime(), Date.UTC(y, m, daysInMonth));
    fraction += (Math.floor((hi - lo) / 86400000) + 1) / daysInMonth;
    m += 1;
    if (m > 11) { m = 0; y += 1; }
  }
  return fraction;
}

router.get('/summary', asyncH(async (req, res) => {
  const today = new Date().toISOString().slice(0, 10);
  const from = dateStr(req.query.from) || `${today.slice(0, 8)}01`;
  const to = dateStr(req.query.to) || today;

  const [sales, ordersRevenue, salesCost, ordersCost, wages, expenses, salaries] = await Promise.all([
    // Effective view: corrected quantities, voided sales excluded.
    db.query(
      `SELECT COALESCE(SUM(total), 0)::bigint AS v FROM sales_effective
       WHERE NOT voided AND sold_at >= $1::date AND sold_at < $2::date + 1`,
      [from, to]),
    // Tailoring revenue counts when the order is delivered.
    db.query(
      `SELECT COALESCE(SUM(price), 0)::bigint AS v FROM orders
       WHERE status = 'livre' AND delivered_date BETWEEN $1::date AND $2::date`,
      [from, to]),
    // Cost of goods sold: sum of (qty × cost_price) for products sold.
    // NOTE: sales.kind values are 'produit' / 'pret_a_porter' (see the CHECK
    // constraint and sales.js) — 'product' / 'model' never matched, so COGS
    // was silently always 0.
    db.query(
      `SELECT COALESCE(SUM(se.qty * p.cost_price), 0)::bigint AS v
       FROM sales_effective se JOIN products p ON se.item_id = p.id
       WHERE se.kind = 'produit' AND NOT se.voided
         AND se.sold_at >= $1::date AND se.sold_at < $2::date + 1`,
      [from, to]),
    // Cost of ready-to-wear models sold.
    db.query(
      `SELECT COALESCE(SUM(se.qty * m.cost_price), 0)::bigint AS v
       FROM sales_effective se JOIN pret_a_porter_models m ON se.item_id = m.id
       WHERE se.kind = 'pret_a_porter' AND NOT se.voided
         AND se.sold_at >= $1::date AND se.sold_at < $2::date + 1`,
      [from, to]),
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
  ]);

  const months = monthsTouched(from, to);
  const salesTotal = Number(sales.rows[0].v);
  const ordersTotal = Number(ordersRevenue.rows[0].v);
  const costOfSalesGoods = Number(salesCost.rows[0].v) + Number(ordersCost.rows[0].v);
  const wagesTotal = Number(wages.rows[0].v);
  const expensesTotal = Number(expenses.rows[0].v);
  // Fixed salaries are prorated over the period (a day is not a whole month).
  const salariesTotal = Math.round(
    Number(salaries.rows[0].v) * proratedSalaryMonths(from, to));
  const revenue = salesTotal + ordersTotal;
  const costs = costOfSalesGoods + wagesTotal + salariesTotal + expensesTotal;

  res.json({
    from,
    to,
    months_counted: months,
    revenue: { sales: salesTotal, orders: ordersTotal, total: revenue },
    costs: {
      cost_of_goods_sold: costOfSalesGoods,
      tailor_wages: wagesTotal,
      salaries: salariesTotal,
      expenses: expensesTotal,
      total: costs,
    },
    net_profit: revenue - costs,
  });
}));

module.exports = router;
