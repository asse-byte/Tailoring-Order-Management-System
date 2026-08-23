// ============================================================================
// THE single source of truth for every money figure in the app.
//
// /api/finance/summary and /api/reports/summary previously carried their own
// copies of these eight queries. They had already drifted apart once, and a
// figure that differs between the Finances screen and the Rapport screen is
// exactly what the shop owner reported. Both routes now call in here, so a
// correction lands on both screens at once.
//
// Rules every query below obeys:
//   * read the append-only *_effective views, never the raw tables, so
//     corrections and voids are always respected;
//   * take the period from a DATED column, so cash lands in the period it was
//     actually collected in;
//   * never join the live catalogue for a cost — costs are frozen onto the row
//     at the moment of the sale (migration 024).
// ============================================================================

/**
 * Every query takes exactly [from, to] (inclusive date strings) and returns a
 * single row { v }. The order here is the order the routes destructure them in.
 */
const FINANCE_QUERIES = [
  // 0 — counter sales (products + ready-to-wear), corrected qty, voids excluded.
  `SELECT COALESCE(SUM(total), 0)::bigint AS v FROM sales_effective
    WHERE NOT voided AND sold_at >= $1::date AND sold_at < $2::date + 1`,

  // 1 — tailoring orders, CASH BASIS: every franc collected in the window,
  //     whether it was the advance, a settlement, or the balance taken at
  //     hand-over. Cancelled orders keep the cash they really took in.
  `SELECT COALESCE(SUM(amount), 0)::bigint AS v FROM order_payments_effective
    WHERE NOT voided AND paid_at BETWEEN $1::date AND $2::date`,

  // 2 — wholesale sales to merchants, same cash basis. This whole revenue
  //     stream was missing from both screens until the 2026-08-23 audit.
  `SELECT COALESCE(SUM(amount), 0)::bigint AS v FROM wholesale_payments_effective
    WHERE NOT voided AND paid_at BETWEEN $1::date AND $2::date`,

  // 3 — cost of goods sold, from the cost FROZEN onto each sale. Reading
  //     products.cost_price live meant re-pricing an item today rewrote the
  //     profit of every past period it had been sold in.
  `SELECT COALESCE(SUM(cost_total), 0)::bigint AS v FROM sales_effective
    WHERE NOT voided AND sold_at >= $1::date AND sold_at < $2::date + 1`,

  // 4 — tailor piece-work wages (voided entries carry amount 0 in the view).
  `SELECT COALESCE(SUM(amount), 0)::bigint AS v FROM tailor_entries_effective
    WHERE entry_date BETWEEN $1::date AND $2::date`,

  // 5 — manual expenses.
  `SELECT COALESCE(SUM(amount), 0)::bigint AS v FROM expenses_effective
    WHERE NOT voided AND spent_at >= $1::date AND spent_at < $2::date + 1`,

  // 6 — salary disbursements actually recorded for the window.
  `SELECT COALESCE(SUM(amount), 0)::bigint AS v FROM salary_payments_effective
    WHERE NOT voided AND paid_at BETWEEN $1::date AND $2::date`,
];

/**
 * The fixed payroll obligation, split by how each employee is paid. Weekly
 * staff (migration 014) were summed nowhere at all until the 2026-08-23 audit,
 * so their wages never reached any cost total and net profit was overstated by
 * the entire weekly payroll. Takes no date parameters — it is the CURRENT
 * roster, prorated to the window by salaryCost().
 */
const PAYROLL_QUERY = `
  SELECT COALESCE(SUM(p.monthly_salary) FILTER (
           WHERE COALESCE(p.pay_frequency, 'mensuel') = 'mensuel'), 0)::bigint AS monthly,
         COALESCE(SUM(p.weekly_salary) FILTER (
           WHERE p.pay_frequency = 'hebdo'), 0)::bigint AS weekly
    FROM staff_pay p JOIN staff s ON s.id = p.staff_id
   WHERE s.active`;

/** Number of calendar months touched by [from, to] (informational only). */
function monthsTouched(from, to) {
  const [fy, fm] = from.split('-').map(Number);
  const [ty, tm] = to.split('-').map(Number);
  return Math.max((ty * 12 + tm) - (fy * 12 + fm) + 1, 1);
}

/** Inclusive day count of [from, to], or 0 if the window is invalid. */
function daysInWindow(from, to) {
  const start = Date.parse(`${from}T00:00:00Z`);
  const end = Date.parse(`${to}T00:00:00Z`);
  if (Number.isNaN(start) || Number.isNaN(end) || end < start) return 0;
  return Math.round((end - start) / 86400000) + 1;
}

/**
 * Fraction of a MONTHLY salary owed for the inclusive window [from, to].
 * Each calendar month contributes (days of it inside the window / its length),
 * so a full month = 1.0, a full year = 12.0, and a single day = 1/daysInMonth.
 * Fixed salaries are thus prorated to the period, keeping net profit honest for
 * the Jour / Semaine presets (a whole month was previously charged to one day).
 */
function salaryMonthsFactor(from, to) {
  const start = new Date(`${from}T00:00:00Z`);
  const end = new Date(`${to}T00:00:00Z`);
  if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime()) || end < start) return 0;
  let factor = 0;
  let y = start.getUTCFullYear();
  let m = start.getUTCMonth(); // 0-based
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

/**
 * The payroll cost to charge to [from, to].
 *
 * Monthly staff are prorated by calendar-month day-fraction; weekly staff by
 * whole weeks (7 days = one weekly salary). The accrued obligation is compared
 * with what was actually disbursed in the window and the LARGER is charged:
 * the shop owes the accrual whether or not it has paid yet, and a catch-up
 * payment covering several months must not vanish from the month it left the
 * till in.
 *
 * @param {{monthly: string|number, weekly: string|number}} row query 6's row
 * @param {string|number} paidInWindow query 7's value
 */
function salaryCost(row, paidInWindow, from, to) {
  const monthly = Math.round(Number(row.monthly) * salaryMonthsFactor(from, to));
  const weekly = Math.round(Number(row.weekly) * (daysInWindow(from, to) / 7));
  return Math.max(Number(paidInWindow), monthly + weekly);
}

/**
 * Run every money query for [from, to] and return the finished revenue / costs
 * / net_profit block that BOTH screens publish. One function, so a fix can
 * never reach one screen and miss the other.
 */
async function financeTotals(db, from, to) {
  const results = await Promise.all([
    ...FINANCE_QUERIES.map((q) => db.query(q, [from, to])),
    db.query(PAYROLL_QUERY),
  ]);
  const [sales, orders, wholesale, goodsCost, wages, expenses, salaryPaid, payroll] =
    results.map((r) => r.rows[0]);

  const revenue = {
    sales: Number(sales.v),
    orders: Number(orders.v),
    wholesale: Number(wholesale.v),
  };
  revenue.total = revenue.sales + revenue.orders + revenue.wholesale;

  const costs = {
    cost_of_goods_sold: Number(goodsCost.v),
    tailor_wages: Number(wages.v),
    salaries: salaryCost(payroll, salaryPaid.v, from, to),
    expenses: Number(expenses.v),
  };
  costs.total = costs.cost_of_goods_sold + costs.tailor_wages
    + costs.salaries + costs.expenses;

  return { revenue, costs, net_profit: revenue.total - costs.total };
}

module.exports = {
  FINANCE_QUERIES, PAYROLL_QUERY, financeTotals,
  monthsTouched, daysInWindow, salaryMonthsFactor, salaryCost,
};
