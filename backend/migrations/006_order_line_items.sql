-- ============================================================================
-- Item 2 — Commandes redesign: multiple line items per order, each with its
-- own price; the order total is derived from the (append-only) items so any
-- edit that changes the financial total leaves a correction trail, exactly
-- like sales / expenses / tailor entries.
--
-- Also: link an order to the tailor who made it, and widen the status enum to
-- the four fixed states (en_attente → en_cours → termine → livre).
-- ============================================================================

-- ---------- header changes ---------------------------------------------------

-- The tailor responsible for the order (nullable: assigned at creation or later).
ALTER TABLE orders ADD COLUMN tailor_id uuid REFERENCES staff(id);

-- Widen the status enum. Old 'pret' (ready) maps to the new 'termine'.
ALTER TABLE orders DROP CONSTRAINT orders_status_check;
UPDATE orders SET status = 'termine' WHERE status = 'pret';
ALTER TABLE orders ALTER COLUMN status SET DEFAULT 'en_attente';
ALTER TABLE orders ADD CONSTRAINT orders_status_check
  CHECK (status IN ('en_attente', 'en_cours', 'termine', 'livre'));

-- ---------- line items (append-only) -----------------------------------------
-- One row per garment type/line. Quantity and unit price are snapshotted; a
-- change is a NEW correction row, never an in-place edit.

CREATE TABLE order_items (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id     uuid NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  garment_type text NOT NULL,
  quantity     integer NOT NULL CHECK (quantity >= 1),
  unit_price   integer NOT NULL CHECK (unit_price >= 0),
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX order_items_order_idx ON order_items (order_id);

CREATE TABLE order_item_corrections (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_item_id  uuid NOT NULL REFERENCES order_items(id),
  new_quantity   integer NOT NULL CHECK (new_quantity >= 1),
  new_unit_price integer NOT NULL CHECK (new_unit_price >= 0),
  voided         boolean NOT NULL DEFAULT false,
  reason         text NOT NULL CHECK (length(trim(reason)) > 0),
  corrected_by   uuid NOT NULL REFERENCES users(id),
  corrected_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX order_item_corrections_item_idx
  ON order_item_corrections (order_item_id, corrected_at DESC);

-- Append-only at the DB level (same forbid_mutation() used by sales/expenses).
CREATE TRIGGER order_items_append_only
  BEFORE UPDATE OR DELETE ON order_items
  FOR EACH ROW EXECUTE FUNCTION forbid_mutation();
CREATE TRIGGER order_item_corrections_append_only
  BEFORE UPDATE OR DELETE ON order_item_corrections
  FOR EACH ROW EXECUTE FUNCTION forbid_mutation();

-- Effective line: latest correction wins; voided lines contribute 0.
-- Every order-total sum must read THIS view.
CREATE VIEW order_items_effective AS
SELECT i.id, i.order_id, i.garment_type,
       COALESCE(c.new_quantity, i.quantity)     AS quantity,
       COALESCE(c.new_unit_price, i.unit_price)  AS unit_price,
       COALESCE(c.voided, false)                 AS voided,
       (c.id IS NOT NULL)                        AS corrected,
       CASE WHEN COALESCE(c.voided, false) THEN 0
            ELSE COALESCE(c.new_quantity, i.quantity)
               * COALESCE(c.new_unit_price, i.unit_price) END AS line_total,
       i.created_at
FROM order_items i
LEFT JOIN LATERAL (
  SELECT id, new_quantity, new_unit_price, voided FROM order_item_corrections c
  WHERE c.order_item_id = i.id
  ORDER BY corrected_at DESC, id DESC LIMIT 1
) c ON true;

-- ---------- backfill ---------------------------------------------------------
-- Turn every existing single-line order into one order_items row so its total
-- is preserved under the new model (qty 1 at the old price).
INSERT INTO order_items (order_id, garment_type, quantity, unit_price, created_at)
SELECT id, garment_type, 1, price, created_at FROM orders;

-- There has never been a unique constraint forcing one order per client per
-- day, and none is added — a client may place several orders the same day.
