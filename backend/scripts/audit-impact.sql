-- ===========================================================================
-- How much did the 2026-08-24 audit bugs actually affect THIS shop?
-- ===========================================================================
--
-- Read-only. Changes nothing. Run it against one shop's database to size the
-- damage before deciding what to tell that shop:
--
--   docker compose exec -T db psql -U couture -d couture_mali \
--     < backend/scripts/audit-impact.sql
--
-- Run it BEFORE deploying the fixes: afterwards no NEW damage accumulates, but
-- everything already recorded stays exactly as it is (the fixes are forward
-- looking on purpose — rewriting past financial rows is what the append-only
-- rule exists to prevent).
-- ===========================================================================

\echo ''
\echo '=== 1. Orders where MORE cash is recorded than the order is worth ==='
\echo '    Cause: raising the advance after delivery inserted the difference'
\echo '    as a new payment even though nothing was owed. Each row is revenue'
\echo '    the shop never actually took.'
\echo ''

WITH balances AS (
  SELECT o.id,
         COALESCE(o.client_name_snapshot, c.full_name, '?')  AS client,
         o.created_at::date                                  AS created,
         o.status,
         COALESCE((SELECT SUM(line_total)::int FROM order_items_effective
                    WHERE order_id = o.id), 0)               AS order_total,
         COALESCE((SELECT SUM(amount)::int FROM order_payments_effective
                    WHERE order_id = o.id AND NOT voided), 0) AS collected
    FROM orders o
    LEFT JOIN clients c ON c.id = o.client_id
   WHERE o.status <> 'annule'
)
SELECT client, created, status, order_total, collected,
       (collected - order_total) AS phantom_revenue
  FROM balances
 WHERE collected > order_total
 ORDER BY (collected - order_total) DESC;

\echo ''
\echo '--- total phantom revenue on this shop ---'
WITH balances AS (
  SELECT o.id,
         COALESCE((SELECT SUM(line_total)::int FROM order_items_effective
                    WHERE order_id = o.id), 0)                AS order_total,
         COALESCE((SELECT SUM(amount)::int FROM order_payments_effective
                    WHERE order_id = o.id AND NOT voided), 0) AS collected
    FROM orders o WHERE o.status <> 'annule'
)
SELECT COUNT(*)                                           AS orders_affected,
       COALESCE(SUM(collected - order_total), 0)          AS fcfa_overstated
  FROM balances WHERE collected > order_total;

\echo ''
\echo '=== 2. Wholesale revenue that was counted with no cost against it ==='
\echo '    Cause: nothing recorded what a bulk lot cost until migration 028.'
\echo '    Net profit was overstated by whatever these lots really cost —'
\echo '    a figure only the owner knows. This lists the exposure.'
\echo ''

SELECT wo.order_date,
       wo.merchant_name,
       wo.total_amount                                    AS sold_for,
       COALESCE(SUM(p.amount) FILTER (WHERE NOT p.voided), 0)::int AS cash_collected
  FROM wholesale_orders wo
  LEFT JOIN wholesale_payments_effective p ON p.order_id = wo.id
 WHERE wo.cost_amount = 0
 GROUP BY wo.id, wo.order_date, wo.merchant_name, wo.total_amount
 ORDER BY wo.order_date DESC;

\echo ''
\echo '--- total wholesale cash carrying no recorded cost ---'
SELECT COUNT(DISTINCT wo.id)                              AS lots_without_cost,
       COALESCE(SUM(p.amount) FILTER (WHERE NOT p.voided), 0)::int
                                                          AS fcfa_counted_as_pure_profit
  FROM wholesale_orders wo
  LEFT JOIN wholesale_payments_effective p ON p.order_id = wo.id
 WHERE wo.cost_amount = 0;

\echo ''
\echo '=== 3. Products whose cost price CHANGED after they had been sold ==='
\echo '    Cause: /stats multiplied today''s cost price by everything ever'
\echo '    sold, so the profit shown on the Produits page for these items was'
\echo '    wrong until the fix. Finances itself was always right (the cost is'
\echo '    frozen on the sale row) — this is a display bug, not lost money.'
\echo '    A row here means the two screens disagreed about this item.'
\echo ''

SELECT p.name,
       p.cost_price                                       AS cost_price_today,
       MIN(s.unit_cost)                                   AS lowest_frozen_cost,
       MAX(s.unit_cost)                                   AS highest_frozen_cost,
       SUM(s.qty)::int                                    AS units_sold,
       (SUM(s.qty) * p.cost_price - SUM(s.cost_total))::int AS profit_error_shown
  FROM products p
  JOIN sales_effective s ON s.item_id = p.id AND s.kind = 'produit'
 WHERE NOT s.voided
 GROUP BY p.id, p.name, p.cost_price
HAVING p.cost_price <> MIN(s.unit_cost) OR p.cost_price <> MAX(s.unit_cost)
 ORDER BY ABS(SUM(s.qty) * p.cost_price - SUM(s.cost_total)) DESC;

\echo ''
\echo '=== 4. Same check for ready-to-wear models ==='
\echo ''

SELECT m.name,
       m.cost_price                                       AS cost_price_today,
       SUM(s.qty)::int                                    AS units_sold,
       (SUM(s.qty) * m.cost_price - SUM(s.cost_total))::int AS profit_error_shown
  FROM pret_a_porter_models m
  JOIN sales_effective s ON s.item_id = m.id AND s.kind = 'pret_a_porter'
 WHERE NOT s.voided
 GROUP BY m.id, m.name, m.cost_price
HAVING m.cost_price <> MIN(s.unit_cost) OR m.cost_price <> MAX(s.unit_cost)
 ORDER BY ABS(SUM(s.qty) * m.cost_price - SUM(s.cost_total)) DESC;

\echo ''
\echo '=== 5. Weekly-paid employees whose weekly salary was wiped ==='
\echo '    Cause: PUT /api/staff-pay rebuilt every field, so an edit that did'
\echo '    not carry weekly_salary reset it — and that person''s wages then'
\echo '    reached no cost total at all. A row here is payroll going uncounted.'
\echo ''

SELECT s.full_name, s.type, s.active,
       sp.pay_frequency, sp.weekly_salary, sp.monthly_salary
  FROM staff s JOIN staff_pay sp ON sp.staff_id = s.id
 WHERE s.active
   AND (
     (sp.pay_frequency = 'hebdo'  AND COALESCE(sp.weekly_salary, 0) = 0) OR
     (sp.pay_frequency = 'mensuel' AND COALESCE(sp.monthly_salary, 0) = 0
       AND s.type = 'autre')
   )
 ORDER BY s.full_name;

\echo ''
\echo '=== done ==='
