-- ============================================================================
-- Migration 014: Weekly staff salaries, supplier credits & wholesale distribution
-- ============================================================================

-- ---------- staff_pay extensions -------------------------------------------
ALTER TABLE staff_pay
  ADD COLUMN IF NOT EXISTS weekly_salary integer CHECK (weekly_salary >= 0),
  ADD COLUMN IF NOT EXISTS pay_frequency text NOT NULL DEFAULT 'mensuel'
    CHECK (pay_frequency IN ('mensuel', 'hebdo'));

-- ---------- suppliers & credit purchases -----------------------------------
CREATE TABLE IF NOT EXISTS suppliers (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name       text NOT NULL,
  phone      text NOT NULL DEFAULT '',
  address    text,
  notes      text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS suppliers_name_idx ON suppliers (lower(name) text_pattern_ops);

CREATE TABLE IF NOT EXISTS supplier_purchases (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  supplier_id            uuid REFERENCES suppliers(id) ON DELETE SET NULL,
  supplier_name_snapshot text NOT NULL,
  description            text NOT NULL,
  total_amount           integer NOT NULL CHECK (total_amount >= 0),
  advance_amount         integer NOT NULL DEFAULT 0 CHECK (advance_amount >= 0),
  purchase_date          date NOT NULL DEFAULT CURRENT_DATE,
  created_by             uuid NOT NULL REFERENCES users(id),
  created_at             timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS supplier_purchases_date_idx ON supplier_purchases (purchase_date DESC);
CREATE INDEX IF NOT EXISTS supplier_purchases_supp_idx ON supplier_purchases (supplier_id);

CREATE TABLE IF NOT EXISTS supplier_payments (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  purchase_id uuid NOT NULL REFERENCES supplier_purchases(id) ON DELETE RESTRICT,
  amount      integer NOT NULL CHECK (amount > 0),
  paid_at     date NOT NULL DEFAULT CURRENT_DATE,
  note        text,
  created_by  uuid NOT NULL REFERENCES users(id),
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS supplier_payments_pur_idx ON supplier_payments (purchase_id);

CREATE TABLE IF NOT EXISTS supplier_payment_corrections (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id   uuid NOT NULL REFERENCES supplier_payments(id),
  new_amount   integer NOT NULL CHECK (new_amount >= 0),
  voided       boolean NOT NULL DEFAULT false,
  reason       text NOT NULL CHECK (length(trim(reason)) > 0),
  corrected_by uuid NOT NULL REFERENCES users(id),
  corrected_at timestamptz NOT NULL DEFAULT now()
);

-- Triggers for supplier_payments append-only
CREATE TRIGGER supplier_payments_append_only
  BEFORE UPDATE OR DELETE ON supplier_payments
  FOR EACH ROW EXECUTE FUNCTION forbid_mutation();

CREATE TRIGGER supplier_payment_corrections_append_only
  BEFORE UPDATE OR DELETE ON supplier_payment_corrections
  FOR EACH ROW EXECUTE FUNCTION forbid_mutation();

-- Effective view for supplier payments
CREATE VIEW supplier_payments_effective AS
SELECT p.id, p.purchase_id,
       COALESCE(c.new_amount, p.amount) AS amount,
       COALESCE(c.voided, false)        AS voided,
       (c.id IS NOT NULL)               AS corrected,
       p.paid_at, p.note, p.created_by, p.created_at
FROM supplier_payments p
LEFT JOIN LATERAL (
  SELECT id, new_amount, voided FROM supplier_payment_corrections c
  WHERE c.payment_id = p.id
  ORDER BY corrected_at DESC, id DESC LIMIT 1
) c ON true;

-- Effective view for supplier purchases with derived paid_total and reste
CREATE VIEW supplier_purchases_effective AS
SELECT sp.id, sp.supplier_id,
       COALESCE(s.name, sp.supplier_name_snapshot) AS supplier_name,
       (s.id IS NULL) AS supplier_deleted,
       sp.description, sp.total_amount, sp.advance_amount,
       COALESCE(pay.paid_total, 0)::int AS paid_total,
       (sp.total_amount - sp.advance_amount - COALESCE(pay.paid_total, 0))::int AS reste,
       sp.purchase_date, sp.created_by, sp.created_at
FROM supplier_purchases sp
LEFT JOIN suppliers s ON s.id = sp.supplier_id
LEFT JOIN LATERAL (
  SELECT SUM(amount)::int AS paid_total
  FROM supplier_payments_effective
  WHERE purchase_id = sp.id AND NOT voided
) pay ON true;

-- ---------- wholesale orders & merchant distributions ----------------------
CREATE TABLE IF NOT EXISTS wholesale_orders (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_name  text NOT NULL,
  merchant_phone text NOT NULL DEFAULT '',
  items          jsonb NOT NULL DEFAULT '[]'::jsonb,
  total_amount   integer NOT NULL CHECK (total_amount >= 0),
  advance_amount integer NOT NULL DEFAULT 0 CHECK (advance_amount >= 0),
  status         text NOT NULL DEFAULT 'en_cours' CHECK (status IN ('en_cours', 'livre')),
  order_date     date NOT NULL DEFAULT CURRENT_DATE,
  delivered_date date,
  notes          text,
  created_by     uuid NOT NULL REFERENCES users(id),
  created_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS wholesale_orders_date_idx ON wholesale_orders (order_date DESC);

CREATE TABLE IF NOT EXISTS wholesale_payments (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id   uuid NOT NULL REFERENCES wholesale_orders(id) ON DELETE RESTRICT,
  amount     integer NOT NULL CHECK (amount > 0),
  paid_at    date NOT NULL DEFAULT CURRENT_DATE,
  note       text,
  created_by uuid NOT NULL REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE supplier_payments DROP CONSTRAINT IF EXISTS supplier_payments_purchase_id_fkey;
ALTER TABLE supplier_payments ADD CONSTRAINT supplier_payments_purchase_id_fkey FOREIGN KEY (purchase_id) REFERENCES supplier_purchases(id) ON DELETE RESTRICT;

ALTER TABLE wholesale_payments DROP CONSTRAINT IF EXISTS wholesale_payments_order_id_fkey;
ALTER TABLE wholesale_payments ADD CONSTRAINT wholesale_payments_order_id_fkey FOREIGN KEY (order_id) REFERENCES wholesale_orders(id) ON DELETE RESTRICT;

CREATE INDEX IF NOT EXISTS wholesale_payments_ord_idx ON wholesale_payments (order_id);

CREATE TABLE IF NOT EXISTS wholesale_payment_corrections (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id   uuid NOT NULL REFERENCES wholesale_payments(id),
  new_amount   integer NOT NULL CHECK (new_amount >= 0),
  voided       boolean NOT NULL DEFAULT false,
  reason       text NOT NULL CHECK (length(trim(reason)) > 0),
  corrected_by uuid NOT NULL REFERENCES users(id),
  corrected_at timestamptz NOT NULL DEFAULT now()
);

-- Triggers for wholesale_payments append-only
CREATE TRIGGER wholesale_payments_append_only
  BEFORE UPDATE OR DELETE ON wholesale_payments
  FOR EACH ROW EXECUTE FUNCTION forbid_mutation();

CREATE TRIGGER wholesale_payment_corrections_append_only
  BEFORE UPDATE OR DELETE ON wholesale_payment_corrections
  FOR EACH ROW EXECUTE FUNCTION forbid_mutation();

-- Effective view for wholesale payments
CREATE VIEW wholesale_payments_effective AS
SELECT p.id, p.order_id,
       COALESCE(c.new_amount, p.amount) AS amount,
       COALESCE(c.voided, false)        AS voided,
       (c.id IS NOT NULL)               AS corrected,
       p.paid_at, p.note, p.created_by, p.created_at
FROM wholesale_payments p
LEFT JOIN LATERAL (
  SELECT id, new_amount, voided FROM wholesale_payment_corrections c
  WHERE c.payment_id = p.id
  ORDER BY corrected_at DESC, id DESC LIMIT 1
) c ON true;

-- Effective view for wholesale orders with derived paid_total and reste
CREATE VIEW wholesale_orders_effective AS
SELECT wo.id, wo.merchant_name, wo.merchant_phone, wo.items,
       wo.total_amount, wo.advance_amount,
       COALESCE(pay.paid_total, 0)::int AS paid_total,
       (wo.total_amount - wo.advance_amount - COALESCE(pay.paid_total, 0))::int AS reste,
       wo.status, wo.order_date, wo.delivered_date, wo.notes,
       wo.created_by, wo.created_at
FROM wholesale_orders wo
LEFT JOIN LATERAL (
  SELECT SUM(amount)::int AS paid_total
  FROM wholesale_payments_effective
  WHERE order_id = wo.id AND NOT voided
) pay ON true;
