-- ============================================================================
-- Item 3 — salary payment tracking + receipts.
-- A ledger of ACTUAL disbursements so the manager can mark a period paid and
-- print a receipt for documentation: monthly staff paid per calendar month
-- ('YYYY-MM'), tailors paid per ISO week ('YYYY-Www').
--
-- Follows the PROJECT PRINCIPLE (append-only + correction log): a wrong payment
-- is corrected or voided with a mandatory reason, never edited or deleted.
-- This ledger is documentation only — it does NOT feed the finance net-profit
-- calc (tailor wages already come from tailor_daily_entries, and the monthly
-- salary obligation from staff_pay), so nothing is double-counted.
-- ============================================================================

CREATE TABLE salary_payments (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id   uuid NOT NULL REFERENCES staff(id),
  -- Period covered: monthly staff use 'YYYY-MM'; tailors use 'YYYY-Www'.
  period     text NOT NULL CHECK (length(trim(period)) > 0),
  kind       text NOT NULL CHECK (kind IN ('mensuel', 'hebdo')),
  amount     integer NOT NULL CHECK (amount >= 0),
  paid_at    date NOT NULL DEFAULT CURRENT_DATE,
  note       text,
  created_by uuid NOT NULL REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  -- One payment record per staff per period (re-recording is a correction).
  UNIQUE (staff_id, period)
);
CREATE INDEX salary_payments_staff_idx ON salary_payments (staff_id, period);

CREATE TABLE salary_payment_corrections (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id   uuid NOT NULL REFERENCES salary_payments(id),
  new_amount   integer NOT NULL CHECK (new_amount >= 0),
  voided       boolean NOT NULL DEFAULT false,
  reason       text NOT NULL CHECK (length(trim(reason)) > 0),
  corrected_by uuid NOT NULL REFERENCES users(id),
  corrected_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX salary_payment_corrections_idx
  ON salary_payment_corrections (payment_id, corrected_at DESC);

-- Append-only at the DB level (same forbid_mutation() used everywhere else).
CREATE TRIGGER salary_payments_append_only
  BEFORE UPDATE OR DELETE ON salary_payments
  FOR EACH ROW EXECUTE FUNCTION forbid_mutation();
CREATE TRIGGER salary_payment_corrections_append_only
  BEFORE UPDATE OR DELETE ON salary_payment_corrections
  FOR EACH ROW EXECUTE FUNCTION forbid_mutation();

-- Effective payment: latest correction wins; voided = not actually paid.
CREATE VIEW salary_payments_effective AS
SELECT p.id, p.staff_id, p.period, p.kind,
       COALESCE(c.new_amount, p.amount) AS amount,
       COALESCE(c.voided, false)        AS voided,
       (c.id IS NOT NULL)               AS corrected,
       p.paid_at, p.note, p.created_by, p.created_at
FROM salary_payments p
LEFT JOIN LATERAL (
  SELECT id, new_amount, voided FROM salary_payment_corrections c
  WHERE c.payment_id = p.id
  ORDER BY corrected_at DESC, id DESC LIMIT 1
) c ON true;
