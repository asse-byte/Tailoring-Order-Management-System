-- ============================================================================
-- Item 6 — the tailor's daily log becomes itemised: each entry now records
-- WHICH garment type was sewn and, optionally, links to the order it belongs
-- to (so the client name is derived, never re-typed). A tailor can therefore
-- have SEVERAL entries on the same day (one per garment type / client), which
-- means the old one-row-per-day rule has to go.
-- Still append-only: edits go through entry_corrections (pieces only).
-- ============================================================================

ALTER TABLE tailor_daily_entries ADD COLUMN garment_type text;
ALTER TABLE tailor_daily_entries ADD COLUMN order_id uuid REFERENCES orders(id);

-- Multiple garment lines per tailor per day are now allowed.
ALTER TABLE tailor_daily_entries
  DROP CONSTRAINT tailor_daily_entries_tailor_id_entry_date_key;

-- Recreate the effective view to carry the new descriptive columns. The
-- financial logic (latest correction wins, amount = pieces × rate) is
-- unchanged.
DROP VIEW tailor_entries_effective;
CREATE VIEW tailor_entries_effective AS
SELECT e.id, e.tailor_id, e.entry_date, e.week_id, e.piece_rate,
       e.garment_type, e.order_id,
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
