-- ============================================================================
-- Make a tailor daily entry fully correctable — quantity, garment type
-- (model) AND price-per-piece (which drives the montant) — plus a void flag
-- so a mistaken entry can be "cancelled" (counts 0) instead of hard-deleted.
--
-- Still 100% append-only: entry_corrections stays INSERT-only (trigger from
-- 001), a correction is a NEW row with a mandatory reason, and the effective
-- value is the latest correction. Nothing about the money model is weakened —
-- amount is still pieces × rate, just now both are correctable, and a voided
-- entry contributes 0.
-- ============================================================================

ALTER TABLE entry_corrections
  ADD COLUMN new_piece_rate   integer CHECK (new_piece_rate >= 0),
  ADD COLUMN new_garment_type text,
  ADD COLUMN voided           boolean NOT NULL DEFAULT false;

-- Recreate the effective view: latest correction wins for pieces, rate and
-- garment type; a voided correction zeroes the amount. Carries the
-- tailor_name_snapshot added in migration 012.
DROP VIEW tailor_entries_effective;
CREATE VIEW tailor_entries_effective AS
SELECT e.id, e.tailor_id, e.tailor_name_snapshot, e.entry_date, e.week_id,
       COALESCE(c.new_piece_rate, e.piece_rate)      AS piece_rate,
       COALESCE(c.new_garment_type, e.garment_type)  AS garment_type,
       e.order_id,
       COALESCE(c.new_pieces, e.pieces_count)         AS pieces_count,
       CASE WHEN COALESCE(c.voided, false) THEN 0
            ELSE COALESCE(c.new_pieces, e.pieces_count)
               * COALESCE(c.new_piece_rate, e.piece_rate) END AS amount,
       COALESCE(c.voided, false)                      AS voided,
       (c.id IS NOT NULL)                             AS corrected,
       e.created_by, e.created_at
FROM tailor_daily_entries e
LEFT JOIN LATERAL (
  SELECT id, new_pieces, new_piece_rate, new_garment_type, voided
  FROM entry_corrections c
  WHERE c.entry_id = e.id
  ORDER BY corrected_at DESC, id DESC LIMIT 1
) c ON true;
