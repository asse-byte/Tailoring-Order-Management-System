-- ===========================================================================
-- 028 — give wholesale sales a cost side, and index the salary date lookup
-- ===========================================================================
--
-- WHY (verification audit 2026-08-24)
--
-- `wholesale_orders` is a real revenue stream and, since migration 024, its
-- cash is correctly counted in Finances. Its COST, however, was counted
-- NOWHERE: a bulk lot bought for 1 000 000 and resold to a merchant for
-- 1 300 000 showed +1 300 000 of revenue against +0 of cost, so net profit was
-- overstated by the entire purchase price of everything sold wholesale.
--
-- Retail is not affected and must not be "fixed" the same way: a counter sale
-- freezes its purchase price onto the row (`sales.unit_cost`, migration 024)
-- and `sales_effective.cost_total` is what COGS reads. Wholesale had no
-- equivalent because `wholesale_orders.items` is free text with no link to
-- `products`, so there was no row to freeze a cost onto.
--
-- `cost_amount` is that missing side: what THIS lot cost the shop, entered
-- alongside its selling price and frozen on the order exactly like a sale's
-- unit_cost. It defaults to 0, so every existing order keeps the figure the
-- owner has already seen — past periods do not jump, they simply stop being
-- blind from here on.
--
-- WHAT THIS DELIBERATELY DOES **NOT** DO
--
-- It does not add `supplier_purchases` / `supplier_payments` to any cost total.
-- Those record what the shop owes its suppliers; the same money reaches the
-- P&L through `products.cost_price` → `sales.unit_cost` → COGS when the goods
-- are actually sold. Counting both would charge every retail purchase twice.
-- Suppliers stay a debt ledger, not a P&L input. Do not "fix" that.
--
-- `wholesale_orders` is Type-A master data (it is editable in place and
-- deletable while it carries no payments — CLAUDE.md), so `cost_amount` is a
-- plain editable column. The append-only rule applies to the CASH
-- (`wholesale_payments`), which is untouched here.
-- ===========================================================================

ALTER TABLE wholesale_orders
  ADD COLUMN IF NOT EXISTS cost_amount integer NOT NULL DEFAULT 0
    CHECK (cost_amount >= 0);

COMMENT ON COLUMN wholesale_orders.cost_amount IS
  'What this bulk lot cost the shop (FCFA). Frozen on the order, like '
  'sales.unit_cost for a counter sale. 0 = not recorded.';

-- Expose it on the effective view so the route and Finances read one shape.
-- The two new columns are APPENDED, never inserted: CREATE OR REPLACE VIEW
-- cannot renumber existing columns, so anything else is a failed migration.
CREATE OR REPLACE VIEW wholesale_orders_effective AS
SELECT wo.id, wo.merchant_name, wo.merchant_phone, wo.items,
       wo.total_amount, wo.advance_amount,
       COALESCE(pay.paid_total, 0)::int AS paid_total,
       (wo.total_amount - COALESCE(pay.paid_total, 0))::int AS reste,
       wo.status, wo.order_date, wo.delivered_date, wo.notes,
       wo.created_by, wo.created_at,
       wo.cost_amount,
       (wo.total_amount - wo.cost_amount)::int AS margin
FROM wholesale_orders wo
LEFT JOIN LATERAL (
  SELECT SUM(amount)::int AS paid_total
  FROM wholesale_payments_effective
  WHERE order_id = wo.id AND NOT voided
) pay ON true;

-- ---------------------------------------------------------------------------
-- Finance query 6 filters salary_payments by `paid_at`, but the only index was
-- (staff_id, period) — every period total scanned the whole table.
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS salary_payments_paid_idx ON salary_payments (paid_at);
