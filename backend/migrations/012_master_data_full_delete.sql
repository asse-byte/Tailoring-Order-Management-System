-- ============================================================================
-- Type-A master data (staff, clients, products/models) becomes FULLY deletable
-- by the manager, WITHOUT losing any Type-B financial/historical record.
--
-- The mechanism is name SNAPSHOTS on the historical rows, so a report can still
-- show "who" long after the master row is gone — exactly the pattern already
-- used by sales (item_id is not an FK; item_name is snapshotted).
--
-- WHY snapshot + DROP FK (not ON DELETE SET NULL) on the financial tables:
-- tailor_daily_entries, staff_pay_history and salary_payments are APPEND-ONLY
-- (forbid_mutation trigger blocks UPDATE/DELETE). A cascaded ON DELETE SET NULL
-- performs an UPDATE on the referencing row → the trigger fires → the whole
-- delete aborts. So on those three we snapshot the name and DROP the FK.
-- orders is NOT append-only, so it keeps a real FK switched to ON DELETE SET
-- NULL plus a snapshot (delivered orders stay in Historique after the client
-- or tailor is deleted).
--
-- Products/prêt-à-porter need NOTHING here: sales.item_id is already a plain
-- uuid (no FK) and sales.item_name is already snapshotted, so a product can be
-- deleted freely while its past sales keep their name and totals.
-- ============================================================================

-- ---------- tailor_daily_entries: snapshot + drop FK -------------------------
ALTER TABLE tailor_daily_entries ADD COLUMN tailor_name_snapshot text;
-- Backfill existing rows. The append-only trigger blocks UPDATE, so disable it
-- for this one controlled backfill, then re-enable — history stays immutable
-- everywhere else.
ALTER TABLE tailor_daily_entries DISABLE TRIGGER tde_append_only;
UPDATE tailor_daily_entries e
   SET tailor_name_snapshot = s.full_name
  FROM staff s WHERE s.id = e.tailor_id;
ALTER TABLE tailor_daily_entries ENABLE TRIGGER tde_append_only;
ALTER TABLE tailor_daily_entries DROP CONSTRAINT tailor_daily_entries_tailor_id_fkey;

DROP VIEW tailor_entries_effective;
CREATE VIEW tailor_entries_effective AS
SELECT e.id, e.tailor_id, e.tailor_name_snapshot, e.entry_date, e.week_id,
       e.piece_rate, e.garment_type, e.order_id,
       COALESCE(c.new_pieces, e.pieces_count)                AS pieces_count,
       COALESCE(c.new_pieces, e.pieces_count) * e.piece_rate AS amount,
       (c.id IS NOT NULL)                                    AS corrected,
       e.created_by, e.created_at
FROM tailor_daily_entries e
LEFT JOIN LATERAL (
  SELECT id, new_pieces FROM entry_corrections c
  WHERE c.entry_id = e.id
  ORDER BY corrected_at DESC, id DESC LIMIT 1
) c ON true;

-- ---------- staff_pay_history: snapshot + drop FK ---------------------------
ALTER TABLE staff_pay_history ADD COLUMN staff_name_snapshot text;
ALTER TABLE staff_pay_history DISABLE TRIGGER staff_pay_history_append_only;
UPDATE staff_pay_history h
   SET staff_name_snapshot = s.full_name
  FROM staff s WHERE s.id = h.staff_id;
ALTER TABLE staff_pay_history ENABLE TRIGGER staff_pay_history_append_only;
ALTER TABLE staff_pay_history DROP CONSTRAINT staff_pay_history_staff_id_fkey;

-- ---------- salary_payments: snapshot + drop FK -----------------------------
ALTER TABLE salary_payments ADD COLUMN staff_name_snapshot text;
ALTER TABLE salary_payments DISABLE TRIGGER salary_payments_append_only;
UPDATE salary_payments p
   SET staff_name_snapshot = s.full_name
  FROM staff s WHERE s.id = p.staff_id;
ALTER TABLE salary_payments ENABLE TRIGGER salary_payments_append_only;
ALTER TABLE salary_payments DROP CONSTRAINT salary_payments_staff_id_fkey;

DROP VIEW salary_payments_effective;
CREATE VIEW salary_payments_effective AS
SELECT p.id, p.staff_id, p.staff_name_snapshot, p.period, p.kind,
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

-- ---------- orders: snapshots + FK RESTRICT → SET NULL ----------------------
-- orders is NOT append-only, so a plain UPDATE backfill and a real FK are fine.
ALTER TABLE orders ADD COLUMN client_name_snapshot text;
ALTER TABLE orders ADD COLUMN tailor_name_snapshot text;
UPDATE orders o SET client_name_snapshot = c.full_name
  FROM clients c WHERE c.id = o.client_id;
UPDATE orders o SET tailor_name_snapshot = s.full_name
  FROM staff s WHERE s.id = o.tailor_id;

-- client_id was NOT NULL + RESTRICT; make it nullable and SET NULL on delete so
-- a delivered order survives (by snapshot) after the client is deleted.
ALTER TABLE orders ALTER COLUMN client_id DROP NOT NULL;
ALTER TABLE orders DROP CONSTRAINT orders_client_id_fkey;
ALTER TABLE orders ADD CONSTRAINT orders_client_id_fkey
  FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE SET NULL;

ALTER TABLE orders DROP CONSTRAINT orders_tailor_id_fkey;
ALTER TABLE orders ADD CONSTRAINT orders_tailor_id_fkey
  FOREIGN KEY (tailor_id) REFERENCES staff(id) ON DELETE SET NULL;
