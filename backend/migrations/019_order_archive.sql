-- ============================================================================
-- Migration 019: cancel/archive an order instead of hard-deleting it.
--
-- Migration 015 + the DELETE /orders route made order deletion "work" by
-- running `ALTER TABLE ... DISABLE TRIGGER` on order_items,
-- order_item_corrections and tailor_daily_entries, deleting the rows, then
-- re-enabling. That defeats the append-only guarantee entirely: DISABLE
-- TRIGGER is table-wide DDL (not session-local), so while one order was being
-- deleted the protection was off for every connection — and the re-enable was
-- wrapped in a silent catch, so a failure could leave it off for good.
--
-- Orders always have at least one order_items row and those rows are
-- append-only, so an order can never be hard-deleted without bypassing the
-- protection. Cancelling is therefore a STATUS CHANGE (the same mechanism
-- Historique already uses for 'livre'): line items, corrections, collected
-- cash and tailor entries all stay exactly as they were.
-- ============================================================================

ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_status_check;
ALTER TABLE orders ADD CONSTRAINT orders_status_check
  CHECK (status IN ('en_attente', 'en_cours', 'termine', 'livre', 'annule'));

ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS cancelled_at   timestamptz,
  ADD COLUMN IF NOT EXISTS cancel_reason  text;

CREATE INDEX IF NOT EXISTS orders_cancelled_idx ON orders (cancelled_at)
  WHERE cancelled_at IS NOT NULL;
