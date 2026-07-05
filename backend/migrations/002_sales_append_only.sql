-- ============================================================================
-- PROJECT PRINCIPLE: every financial table is append-only + correction log.
-- No exceptions. This migration brings sales and pay-rate changes in line
-- with tailor_daily_entries and expenses (001).
-- ============================================================================

-- ---------- sales corrections ------------------------------------------------
-- A wrong sale is corrected (qty) or voided (return/cancellation) with a
-- mandatory reason — never edited in place, never deleted.

CREATE TABLE sale_corrections (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sale_id      uuid NOT NULL REFERENCES sales(id),
  old_qty      integer NOT NULL,
  new_qty      integer NOT NULL CHECK (new_qty >= 1),
  voided       boolean NOT NULL DEFAULT false,
  reason       text NOT NULL CHECK (length(trim(reason)) > 0),
  corrected_by uuid NOT NULL REFERENCES users(id),
  corrected_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX sale_corrections_sale_idx ON sale_corrections (sale_id, corrected_at DESC);

CREATE TRIGGER sales_append_only
  BEFORE UPDATE OR DELETE ON sales
  FOR EACH ROW EXECUTE FUNCTION forbid_mutation();
CREATE TRIGGER sale_corrections_append_only
  BEFORE UPDATE OR DELETE ON sale_corrections
  FOR EACH ROW EXECUTE FUNCTION forbid_mutation();

-- Effective values: latest correction wins; totals recomputed from the
-- snapshotted unit price. All revenue sums must read THIS view.
CREATE VIEW sales_effective AS
SELECT s.id, s.kind, s.item_id, s.item_name,
       COALESCE(c.new_qty, s.qty)                AS qty,
       s.unit_price,
       COALESCE(c.new_qty, s.qty) * s.unit_price AS total,
       COALESCE(c.voided, false)                 AS voided,
       (c.id IS NOT NULL)                        AS corrected,
       s.sold_at, s.created_by
FROM sales s
LEFT JOIN LATERAL (
  SELECT id, new_qty, voided FROM sale_corrections c
  WHERE c.sale_id = s.id
  ORDER BY corrected_at DESC, id DESC LIMIT 1
) c ON true;

-- ---------- pay-rate change history -------------------------------------------
-- staff_pay holds the CURRENT rates; every change is journaled here by the
-- API in the same transaction. Append-only like all financial history.

CREATE TABLE staff_pay_history (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id           uuid NOT NULL REFERENCES staff(id),
  old_piece_rate     integer,
  new_piece_rate     integer,
  old_monthly_salary integer,
  new_monthly_salary integer,
  changed_by         uuid NOT NULL REFERENCES users(id),
  changed_at         timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX staff_pay_history_idx ON staff_pay_history (staff_id, changed_at DESC);

CREATE TRIGGER staff_pay_history_append_only
  BEFORE UPDATE OR DELETE ON staff_pay_history
  FOR EACH ROW EXECUTE FUNCTION forbid_mutation();
