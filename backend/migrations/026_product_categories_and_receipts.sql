-- ============================================================================
-- Migration 026 — the shop defines its own product types, and one sale at the
-- counter is ONE receipt.
--
-- Two owner requests (2026-08-23):
--
--   1. Products were locked to three categories by a CHECK constraint
--      (parfum / chaussure / tissu). Most shops carry more — watches and caps
--      were asked for by name — and the owner must be able to add a type
--      himself without anyone touching the code again. The list therefore
--      becomes a table the manager edits, never a hardcoded enum.
--
--   2. A customer buying two ready-to-wear pieces, a cap, shoes, a perfume and
--      a watch produced six unrelated `sales` rows with no client attached and
--      no way to print one invoice. Sales now belong to a `sale_receipts`
--      header carrying the client, so the till prints a single document.
--
-- `sales` stays append-only and untouched as a table: a receipt groups rows,
-- it does not replace them, and every existing correction/void path keeps
-- working exactly as before.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Product categories as data
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS product_categories (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Stable key stored on the product row; never shown to the user.
  slug       text NOT NULL UNIQUE CHECK (slug ~ '^[a-z0-9_]+$'),
  -- What the shop actually sees, in French, and editable.
  label      text NOT NULL CHECK (length(trim(label)) > 0),
  -- Material icon name the app maps to a glyph; NULL falls back to a default.
  icon       text,
  sort_order integer NOT NULL DEFAULT 100,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- The three original categories, plus the two the owner asked for. Seeded
-- ON CONFLICT DO NOTHING so re-running the migration (and `npm run setup-shop`)
-- never disturbs a shop that has since renamed or reordered them.
INSERT INTO product_categories (slug, label, icon, sort_order) VALUES
  ('parfum',    'Parfums',    'spray',     10),
  ('chaussure', 'Chaussures', 'shoe',      20),
  ('tissu',     'Tissus',     'fabric',    30),
  ('montre',    'Montres',    'watch',     40),
  ('bonnet',    'Bonnets',    'hat',       50)
ON CONFLICT (slug) DO NOTHING;

-- Any category a shop already had in its data but that is not in the seed
-- (impossible today because of the CHECK, but free after it is dropped).
INSERT INTO product_categories (slug, label, sort_order)
SELECT DISTINCT p.category, initcap(p.category), 900
  FROM products p
 WHERE NOT EXISTS (SELECT 1 FROM product_categories c WHERE c.slug = p.category)
ON CONFLICT (slug) DO NOTHING;

-- Replace the hardcoded CHECK with a real reference. ON DELETE RESTRICT: a
-- category still carrying products cannot be removed out from under them.
ALTER TABLE products DROP CONSTRAINT IF EXISTS products_category_check;
ALTER TABLE products DROP CONSTRAINT IF EXISTS products_category_fkey;
ALTER TABLE products
  ADD CONSTRAINT products_category_fkey
  FOREIGN KEY (category) REFERENCES product_categories(slug)
  ON UPDATE CASCADE ON DELETE RESTRICT;

-- ---------------------------------------------------------------------------
-- 2. One counter sale = one receipt
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sale_receipts (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  -- The client is optional: a walk-in who gives no name still gets a receipt.
  -- Snapshots keep the document readable after the client record is deleted,
  -- exactly like orders.client_name_snapshot (migration 012).
  client_id             uuid REFERENCES clients(id) ON DELETE SET NULL,
  client_name_snapshot  text,
  client_phone_snapshot text,
  note       text,
  sold_at    timestamptz NOT NULL DEFAULT now(),
  created_by uuid NOT NULL REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS sale_receipts_sold_idx   ON sale_receipts (sold_at DESC);
CREATE INDEX IF NOT EXISTS sale_receipts_client_idx ON sale_receipts (client_id);

-- A sale line points at its receipt. NULL = one of the single-item sales made
-- before this migration, which stay valid and keep showing on their own.
ALTER TABLE sales ADD COLUMN IF NOT EXISTS receipt_id uuid REFERENCES sale_receipts(id);
CREATE INDEX IF NOT EXISTS sales_receipt_idx ON sales (receipt_id);

-- sales_effective (migration 024) has to carry the new column so the receipt
-- view can group corrected, non-voided lines by receipt.
DROP VIEW IF EXISTS sales_effective CASCADE;
CREATE VIEW sales_effective AS
SELECT s.id, s.kind, s.item_id, s.item_name, s.receipt_id,
       COALESCE(c.new_qty, s.qty)                AS qty,
       s.unit_price,
       COALESCE(s.unit_cost, 0)                  AS unit_cost,
       COALESCE(c.new_qty, s.qty) * s.unit_price AS total,
       COALESCE(c.new_qty, s.qty) * COALESCE(s.unit_cost, 0) AS cost_total,
       COALESCE(c.voided, false)                 AS voided,
       (c.id IS NOT NULL)                        AS corrected,
       s.sold_at, s.created_by
FROM sales s
LEFT JOIN LATERAL (
  SELECT id, new_qty, voided FROM sale_corrections c
  WHERE c.sale_id = s.id
  ORDER BY corrected_at DESC, id DESC LIMIT 1
) c ON true;

-- `sales` is append-only, so the receipt header must be too: without this a
-- receipt could be silently re-pointed at another client, or deleted out from
-- under rows that are themselves immutable. Changing a receipt means
-- correcting its lines, which already has a correction log.
DROP TRIGGER IF EXISTS sale_receipts_append_only ON sale_receipts;
CREATE TRIGGER sale_receipts_append_only
  BEFORE UPDATE OR DELETE ON sale_receipts
  FOR EACH ROW EXECUTE FUNCTION forbid_mutation();

-- The whole receipt with its effective (corrected, non-voided) total, which is
-- what the history screen lists and what an invoice prints.
CREATE OR REPLACE VIEW sale_receipts_effective AS
SELECT r.id,
       r.client_id,
       COALESCE(c.full_name, r.client_name_snapshot)  AS client_name,
       COALESCE(c.phone, r.client_phone_snapshot)     AS client_phone,
       (r.client_id IS NOT NULL AND c.id IS NULL)     AS client_deleted,
       r.note, r.sold_at, r.created_by, r.created_at,
       COALESCE(l.lines_count, 0)::int                AS lines_count,
       COALESCE(l.items_count, 0)::int                AS items_count,
       COALESCE(l.total, 0)::int                      AS total,
       COALESCE(l.all_voided, false)                  AS voided
FROM sale_receipts r
LEFT JOIN clients c ON c.id = r.client_id
LEFT JOIN LATERAL (
  SELECT COUNT(*)::int                                          AS lines_count,
         COALESCE(SUM(qty) FILTER (WHERE NOT voided), 0)::int    AS items_count,
         COALESCE(SUM(total) FILTER (WHERE NOT voided), 0)::int  AS total,
         BOOL_AND(voided)                                        AS all_voided
  FROM sales_effective WHERE receipt_id = r.id
) l ON true;
