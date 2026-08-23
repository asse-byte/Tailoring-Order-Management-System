-- ============================================================================
-- Migration 025 — who cancelled this order?
--
-- The owner opened order cancellation to the secretary (decision 2026-08-23,
-- documented in CLAUDE.md as a deliberate exception to rule 1). An order
-- carries prices and collected cash, so the exception is only acceptable while
-- every cancellation names the exact user who did it — the same accountability
-- the tailor-schedule exception rests on (`entry_corrections.corrected_by`).
--
-- Migration 019 recorded `cancelled_at` and `cancel_reason` but NOT who. With
-- two operating accounts that made a cancellation untraceable, which is
-- precisely what the owner needs to be able to audit.
-- ============================================================================

ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS cancelled_by uuid REFERENCES users(id);

-- Cancelled orders that predate this column keep a NULL author; the API
-- reports them as "Utilisateur inconnu (avant le suivi)" rather than guessing.
CREATE INDEX IF NOT EXISTS orders_cancelled_by_idx
  ON orders (cancelled_by) WHERE cancelled_by IS NOT NULL;
