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

  // 7 — what the goods sold WHOLESALE cost the shop, frozen on the order
  //     (migration 028). Query 2 counted the merchant's cash with no cost at
  //     all against it, so every wholesale lot showed a 100 % margin.
  //     Dated on the order, matching how the lot is priced and delivered;
  //     `cost_amount` is 0 for lots bought before this existed, which is why
  //     no past figure moves.
  `SELECT COALESCE(SUM(cost_amount), 0)::bigint AS v FROM wholesale_orders
    WHERE order_date BETWEEN $1::date AND $2::date`,
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
  const [sales, orders, wholesale, goodsCost, wages, expenses, salaryPaid,
    wholesaleCost, payroll] = results.map((r) => r.rows[0]);

  const revenue = {
    sales: Number(sales.v),
    orders: Number(orders.v),
    wholesale: Number(wholesale.v),
  };
  revenue.total = revenue.sales + revenue.orders + revenue.wholesale;

  const costs = {
    // Retail COGS (frozen unit_cost) plus what the wholesale lots cost. Both
    // are the purchase price of goods that left the shop, so they belong on
    // the same line — the Finances screen already labels it "Achat de la
    // marchandise vendue".
    cost_of_goods_sold: Number(goodsCost.v) + Number(wholesaleCost.v),
    tailor_wages: Number(wages.v),
    salaries: salaryCost(payroll, salaryPaid.v, from, to),
    expenses: Number(expenses.v),
  };
  costs.total = costs.cost_of_goods_sold + costs.tailor_wages
    + costs.salaries + costs.expenses;

  return { revenue, costs, net_profit: revenue.total - costs.total };
}

// ============================================================================
// The operation-by-operation breakdown behind each KPI card.
//
// The Finances screen lists the operations under every category with a
// subtotal. Those subtotals used to be added up IN THE APP, by folding the
// rows of a PAGINATED list endpoint: 20 orders, 50 sales, 50 expenses. On any
// busy month the app therefore printed a subtotal covering only the first page,
// directly beneath a KPI card holding the true figure — two different numbers
// for the same thing, on the same screen.
//
// The subtotal is computed HERE now, over the whole window, from the very same
// effective views financeTotals() reads, so a category's subtotal cannot drift
// from its card. The row list stays capped (a shop does not scroll 4 000 rows
// on a phone) and says how many were left out; the TOTAL always covers all of
// them.
//
// Delivered-order rows carry the CASH COLLECTED in the window, not the order's
// price. The card above them is cash-basis (query 1) — listing order totals
// there could never reconcile with it, and made a delivered order with an
// unpaid balance look like money the shop had received.
// ============================================================================

const DETAIL_ROW_CAP = 300;

const DETAIL_QUERIES = {
  // Money in — tailoring: one row per payment actually collected.
  orders: {
    total: `SELECT COALESCE(SUM(p.amount), 0)::bigint AS v
              FROM order_payments_effective p
             WHERE NOT p.voided AND p.paid_at BETWEEN $1::date AND $2::date`,
    rows: `SELECT COALESCE(c.full_name, o.client_name_snapshot, 'Client') AS title,
                  p.paid_at::text AS on_date,
                  COALESCE(NULLIF(p.note, ''), 'Règlement')  AS detail,
                  p.amount::int AS amount
             FROM order_payments_effective p
             JOIN orders o ON o.id = p.order_id
             LEFT JOIN clients c ON c.id = o.client_id
            WHERE NOT p.voided AND p.paid_at BETWEEN $1::date AND $2::date
            ORDER BY p.paid_at DESC, p.created_at DESC
            LIMIT ${DETAIL_ROW_CAP}`,
  },
  // Money in — the counter.
  sales: {
    total: `SELECT COALESCE(SUM(total), 0)::bigint AS v FROM sales_effective
             WHERE NOT voided AND sold_at >= $1::date AND sold_at < $2::date + 1`,
    rows: `SELECT item_name AS title,
                  sold_at::date::text AS on_date,
                  ('×' || qty) AS detail,
                  total::int AS amount
             FROM sales_effective
            WHERE NOT voided AND sold_at >= $1::date AND sold_at < $2::date + 1
            ORDER BY sold_at DESC
            LIMIT ${DETAIL_ROW_CAP}`,
  },
  // Money out — piece-work wages.
  wages: {
    total: `SELECT COALESCE(SUM(amount), 0)::bigint AS v
              FROM tailor_entries_effective
             WHERE entry_date BETWEEN $1::date AND $2::date`,
    rows: `SELECT COALESCE(s.full_name, e.tailor_name_snapshot, 'Couturier') AS title,
                  e.entry_date::text AS on_date,
                  (COALESCE(NULLIF(e.garment_type, ''), 'Pièces')
                    || ' · ' || e.pieces_count || ' pc') AS detail,
                  e.amount::int AS amount
             FROM tailor_entries_effective e
             LEFT JOIN staff s ON s.id = e.tailor_id
            WHERE e.entry_date BETWEEN $1::date AND $2::date AND NOT e.voided
            ORDER BY e.entry_date DESC, e.created_at DESC
            LIMIT ${DETAIL_ROW_CAP}`,
  },
  // Money out — manual expenses.
  expenses: {
    total: `SELECT COALESCE(SUM(amount), 0)::bigint AS v FROM expenses_effective
             WHERE NOT voided AND spent_at >= $1::date AND spent_at < $2::date + 1`,
    rows: `SELECT reason AS title,
                  spent_at::date::text AS on_date,
                  'Dépense' AS detail,
                  amount::int AS amount
             FROM expenses_effective
            WHERE NOT voided AND spent_at >= $1::date AND spent_at < $2::date + 1
            ORDER BY spent_at DESC, created_at DESC
            LIMIT ${DETAIL_ROW_CAP}`,
  },
};

/**
 * Rows + an authoritative subtotal for each finance category in [from, to].
 * `truncated` says the list was capped; `total` never is.
 */
async function financeDetail(db, from, to) {
  const keys = Object.keys(DETAIL_QUERIES);
  const results = await Promise.all(keys.flatMap((k) => [
    db.query(DETAIL_QUERIES[k].total, [from, to]),
    db.query(DETAIL_QUERIES[k].rows, [from, to]),
  ]));

  const out = {};
  keys.forEach((key, i) => {
    const total = Number(results[i * 2].rows[0].v);
    const rows = results[i * 2 + 1].rows.map((r) => ({
      title: r.title,
      on_date: r.on_date,
      detail: r.detail,
      amount: Number(r.amount),
    }));
    out[key] = { total, rows, truncated: rows.length >= DETAIL_ROW_CAP };
  });
  return out;
}

module.exports = {
  FINANCE_QUERIES, PAYROLL_QUERY, DETAIL_QUERIES, DETAIL_ROW_CAP,
  financeTotals, financeDetail,
  monthsTouched, daysInWindow, salaryMonthsFactor, salaryCost,
};
