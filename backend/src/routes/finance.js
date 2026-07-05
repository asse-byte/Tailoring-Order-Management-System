const express = require('express');
const db = require('../db');
const { asyncH, dateStr } = require('../util');

// Mounted manager-only in app.js — THE financial screen's data source.
const router = express.Router();

/** Number of calendar months touched by [from, to] (for salary totals). */
function monthsTouched(from, to) {
  const [fy, fm] = from.split('-').map(Number);
  const [ty, tm] = to.split('-').map(Number);
  return Math.max((ty * 12 + tm) - (fy * 12 + fm) + 1, 1);
}

router.get('/summary', asyncH(async (req, res) => {
  const today = new Date().toISOString().slice(0, 10);
  const from = dateStr(req.query.from) || `${today.slice(0, 8)}01`;
  const to = dateStr(req.query.to) || today;

  const [sales, ordersRevenue, wages, expenses, salaries] = await Promise.all([
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
  const wagesTotal = Number(wages.rows[0].v);
  const expensesTotal = Number(expenses.rows[0].v);
  const salariesTotal = Number(salaries.rows[0].v) * months;
  const revenue = salesTotal + ordersTotal;
  const costs = wagesTotal + salariesTotal + expensesTotal;

  res.json({
    from,
    to,
    months_counted: months,
    revenue: { sales: salesTotal, orders: ordersTotal, total: revenue },
    costs: {
      tailor_wages: wagesTotal,
      salaries: salariesTotal,
      expenses: expensesTotal,
      total: costs,
    },
    net_profit: revenue - costs,
  });
}));

module.exports = router;
