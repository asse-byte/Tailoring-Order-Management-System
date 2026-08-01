-- ============================================================================
-- Migration 016: Track cash payment entries for tailoring orders
-- Enables real-time daily cash income tracking on the exact date payment is received
-- (initial advance on order creation + subsequent balance settlements).
-- ============================================================================

CREATE TABLE IF NOT EXISTS order_payments (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id    uuid NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  amount      integer NOT NULL CHECK (amount <> 0),
  paid_at     date NOT NULL DEFAULT CURRENT_DATE,
  note        text,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS order_payments_order_idx ON order_payments (order_id);
CREATE INDEX IF NOT EXISTS order_payments_date_idx  ON order_payments (paid_at);

-- Backfill initial payment entries for existing orders with advance > 0
INSERT INTO order_payments (order_id, amount, paid_at, note, created_at)
SELECT o.id, o.advance, COALESCE(o.delivered_date, o.created_at::date), 'Acompte initial', o.created_at
FROM orders o
WHERE o.advance > 0
  AND NOT EXISTS (SELECT 1 FROM order_payments op WHERE op.order_id = o.id);
