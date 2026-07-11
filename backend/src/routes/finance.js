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
    // NB: sales.kind is 'produit' / 'pret_a_porter' (see 001_init.sql), NOT
    // 'product' / 'model' — a wrong literal here silently zeroed all COGS.
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
  const salariesTotal = Number(salaries.rows[0].v) * months;
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
