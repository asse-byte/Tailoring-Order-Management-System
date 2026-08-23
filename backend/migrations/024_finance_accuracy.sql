-- ============================================================================
-- Migration 024 — financial accuracy audit (2026-08-23).
--
-- Three money bugs found while auditing every calculation behind the
-- "Rapport et statistique" screen. All three belong to the same family as the
-- COGS bug (item 5) and the delivery-cash bug (Antigravity review): money that
-- is never counted, or a past period whose figures change under your feet.
--
--   1. COGS was read from the product's CURRENT cost_price. Updating a cost
--      price today silently rewrote the profit of every past period in which
--      that item had been sold. A sale must carry the cost it had that day.
--
--   2. Wholesale orders (sales to merchants) collect real cash — an advance
--      plus later settlements — and NONE of it appeared in revenue. Same for
--      the advance on a supplier purchase, which is real cash going out.
--      Both advances were plain columns with no dated payment row, so they
--      could never be attributed to a period at all.
--
--   3. Weekly-paid staff (migration 014) were invisible to every cost total:
--      the finance query summed monthly_salary only. That is fixed in
--      src/routes/finance.js + reports.js; nothing to migrate here.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Freeze the purchase cost onto the sale, exactly like unit_price already is
-- ---------------------------------------------------------------------------
ALTER TABLE sales ADD COLUMN IF NOT EXISTS unit_cost integer CHECK (unit_cost >= 0);

-- Backfill historical rows from the item they point at. This is the best
-- information that exists: the cost price is not versioned before today, so
-- past COGS keeps exactly the value the reports show right now, and stops
-- moving from here on.
UPDATE sales s
   SET unit_cost = COALESCE(p.cost_price, 0)
  FROM products p
 WHERE s.unit_cost IS NULL AND s.kind = 'produit' AND s.item_id = p.id;

UPDATE sales s
   SET unit_cost = COALESCE(m.cost_price, 0)
  FROM pret_a_porter_models m
 WHERE s.unit_cost IS NULL AND s.kind = 'pret_a_porter' AND s.item_id = m.id;

-- Anything whose item was already deleted keeps a 0 cost (unknowable).
UPDATE sales SET unit_cost = 0 WHERE unit_cost IS NULL;

-- The effective view gains the frozen cost so every COGS sum reads it and
-- never joins the live catalogue again.
DROP VIEW IF EXISTS sales_effective;
CREATE VIEW sales_effective AS
SELECT s.id, s.kind, s.item_id, s.item_name,
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

-- ---------------------------------------------------------------------------
-- 2. Give every wholesale / supplier advance a real, dated cash row
-- ---------------------------------------------------------------------------
-- `advance_amount` counted towards `reste` but had no row in the payments
-- table, so it was cash with no date: impossible to place in a period. Convert
-- the existing advances into ordinary payment rows dated on the order/purchase
-- day, then stop using the column as a second source of truth.

INSERT INTO wholesale_payments (order_id, amount, paid_at, note, created_by, created_at)
SELECT wo.id, wo.advance_amount, wo.order_date,
       'Acompte initial (régularisé migration 024)', wo.created_by, wo.created_at
  FROM wholesale_orders wo
 WHERE wo.advance_amount > 0
   AND NOT EXISTS (
     SELECT 1 FROM wholesale_payments p
      WHERE p.order_id = wo.id
        AND p.note = 'Acompte initial (régularisé migration 024)');

INSERT INTO supplier_payments (purchase_id, amount, paid_at, note, created_by, created_at)
SELECT sp.id, sp.advance_amount, sp.purchase_date,
       'Acompte initial (régularisé migration 024)', sp.created_by, sp.created_at
  FROM supplier_purchases sp
 WHERE sp.advance_amount > 0
   AND NOT EXISTS (
     SELECT 1 FROM supplier_payments p
      WHERE p.purchase_id = sp.id
        AND p.note = 'Acompte initial (régularisé migration 024)');

-- The advance is now one of the payment rows, so `reste` must stop subtracting
-- it a second time — it was being double-counted against the balance owed.
CREATE OR REPLACE VIEW wholesale_orders_effective AS
SELECT wo.id, wo.merchant_name, wo.merchant_phone, wo.items,
       wo.total_amount, wo.advance_amount,
       COALESCE(pay.paid_total, 0)::int AS paid_total,
       (wo.total_amount - COALESCE(pay.paid_total, 0))::int AS reste,
       wo.status, wo.order_date, wo.delivered_date, wo.notes,
       wo.created_by, wo.created_at
FROM wholesale_orders wo
LEFT JOIN LATERAL (
  SELECT SUM(amount)::int AS paid_total
  FROM wholesale_payments_effective
  WHERE order_id = wo.id AND NOT voided
) pay ON true;

CREATE OR REPLACE VIEW supplier_purchases_effective AS
SELECT sp.id, sp.supplier_id,
       COALESCE(s.name, sp.supplier_name_snapshot) AS supplier_name,
       (s.id IS NULL) AS supplier_deleted,
       sp.description, sp.total_amount, sp.advance_amount,
       COALESCE(pay.paid_total, 0)::int AS paid_total,
       (sp.total_amount - COALESCE(pay.paid_total, 0))::int AS reste,
       sp.purchase_date, sp.created_by, sp.created_at
FROM supplier_purchases sp
LEFT JOIN suppliers s ON s.id = sp.supplier_id
LEFT JOIN LATERAL (
  SELECT SUM(amount)::int AS paid_total
  FROM supplier_payments_effective
  WHERE purchase_id = sp.id AND NOT voided
) pay ON true;

-- Dated-cash lookups for the finance period filters.
CREATE INDEX IF NOT EXISTS wholesale_payments_paid_idx ON wholesale_payments (paid_at);
CREATE INDEX IF NOT EXISTS supplier_payments_paid_idx  ON supplier_payments (paid_at);
