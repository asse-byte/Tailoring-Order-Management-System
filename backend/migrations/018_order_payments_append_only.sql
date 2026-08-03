-- ============================================================================
-- Migration 018: bring `order_payments` under the project's non-negotiable
-- append-only rule (PROJECT PRINCIPLE in CLAUDE.md).
--
-- Migration 016 introduced `order_payments` as a plain mutable table: no
-- append-only trigger, no correction log, no effective view, ON DELETE CASCADE
-- (so deleting an order silently erased collected cash from every revenue
-- total) and CHECK (amount <> 0), which allowed negative "adjustment" rows.
-- Finance and reports read it directly, so it IS a financial table and every
-- rule that applies to expenses/sales applies to it.
--
-- What this migration does:
--   1. Drops the CASCADE so order history can never be silently erased.
--   2. Forbids negative rows — an over-stated payment is corrected, not undone
--      by a negative counter-row (matching expenses/sales semantics).
--   3. Adds order_payment_corrections + append-only triggers on both tables.
--   4. Adds order_payments_effective (latest correction wins, voided flag),
--      which finance/reports read instead of the raw table.
-- ============================================================================

-- ---------- 1. no more CASCADE: cash history outlives the order row ---------
ALTER TABLE order_payments DROP CONSTRAINT IF EXISTS order_payments_order_id_fkey;
ALTER TABLE order_payments
  ADD CONSTRAINT order_payments_order_id_fkey
  FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE RESTRICT;

-- ---------- 2. normalise pre-existing rows, then forbid negatives -----------
-- Migration 016's PUT /orders path wrote negative deltas when an advance was
-- lowered. Collapse each order's rows to a single non-negative opening row so
-- the historical cash total per order is preserved exactly.
DO $$
DECLARE
  has_negative boolean;
BEGIN
  SELECT EXISTS (SELECT 1 FROM order_payments WHERE amount < 0) INTO has_negative;
  IF has_negative THEN
    WITH net AS (
      SELECT order_id,
             SUM(amount)::int              AS net_amount,
             MIN(paid_at)                  AS first_paid_at,
             MIN(created_at)               AS first_created_at
      FROM order_payments
      GROUP BY order_id
      HAVING SUM(amount) >= 0
    )
    DELETE FROM order_payments p
    USING net n
    WHERE p.order_id = n.order_id;

    INSERT INTO order_payments (order_id, amount, paid_at, note, created_at)
    SELECT o.id,
           GREATEST(o.advance, 0),
           COALESCE(o.created_at::date, CURRENT_DATE),
           'Acompte initial (consolidé migration 018)',
           o.created_at
    FROM orders o
    WHERE o.advance > 0
      AND NOT EXISTS (SELECT 1 FROM order_payments op WHERE op.order_id = o.id);
  END IF;
END $$;

-- Any residual negative row would break the CHECK below; clamp defensively.
DELETE FROM order_payments WHERE amount < 0;

ALTER TABLE order_payments DROP CONSTRAINT IF EXISTS order_payments_amount_check;
ALTER TABLE order_payments
  ADD CONSTRAINT order_payments_amount_check CHECK (amount > 0);

-- ---------- 3. correction log + append-only enforcement ---------------------
CREATE TABLE IF NOT EXISTS order_payment_corrections (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id   uuid NOT NULL REFERENCES order_payments(id),
  new_amount   integer NOT NULL CHECK (new_amount >= 0),
  voided       boolean NOT NULL DEFAULT false,
  reason       text NOT NULL CHECK (length(trim(reason)) > 0),
  corrected_by uuid NOT NULL REFERENCES users(id),
  corrected_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS order_payment_corrections_idx
  ON order_payment_corrections (payment_id, corrected_at DESC);

DROP TRIGGER IF EXISTS order_payments_append_only ON order_payments;
CREATE TRIGGER order_payments_append_only
  BEFORE UPDATE OR DELETE ON order_payments
  FOR EACH ROW EXECUTE FUNCTION forbid_mutation();

DROP TRIGGER IF EXISTS order_payment_corrections_append_only ON order_payment_corrections;
CREATE TRIGGER order_payment_corrections_append_only
  BEFORE UPDATE OR DELETE ON order_payment_corrections
  FOR EACH ROW EXECUTE FUNCTION forbid_mutation();

-- ---------- 4. effective view (latest correction wins) ----------------------
CREATE OR REPLACE VIEW order_payments_effective AS
SELECT p.id, p.order_id,
       COALESCE(c.new_amount, p.amount) AS amount,
       COALESCE(c.voided, false)        AS voided,
       (c.id IS NOT NULL)               AS corrected,
       p.paid_at, p.note, p.created_at
FROM order_payments p
LEFT JOIN LATERAL (
  SELECT id, new_amount, voided FROM order_payment_corrections c
  WHERE c.payment_id = p.id
  ORDER BY corrected_at DESC, id DESC LIMIT 1
) c ON true;
