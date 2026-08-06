-- ============================================================================
-- Fix pieces_count for voided tailor daily entries (should be 0 when voided)
-- and expose correction audit columns (corrected_by, corrected_by_name,
-- corrected_at, correction_reason) so the API & UI show who modified/voided
-- the entry and when.
-- ============================================================================

DROP VIEW IF EXISTS tailor_entries_effective;
CREATE VIEW tailor_entries_effective AS
SELECT e.id, e.tailor_id, e.tailor_name_snapshot, e.entry_date, e.week_id,
       COALESCE(c.new_piece_rate, e.piece_rate)      AS piece_rate,
       COALESCE(c.new_garment_type, e.garment_type)  AS garment_type,
       e.order_id,
       COALESCE(c.new_custom_client_name, e.custom_client_name, cl.full_name, o.client_name_snapshot) AS client_name,
       CASE WHEN COALESCE(c.voided, false) THEN 0
            ELSE COALESCE(c.new_pieces, e.pieces_count) END AS pieces_count,
       CASE WHEN COALESCE(c.voided, false) THEN 0
            ELSE COALESCE(c.new_pieces, e.pieces_count)
               * COALESCE(c.new_piece_rate, e.piece_rate) END AS amount,
       COALESCE(c.voided, false)                      AS voided,
       (c.id IS NOT NULL)                             AS corrected,
       c.corrected_by,
       u.name                                         AS corrected_by_name,
       c.corrected_at,
       c.reason                                       AS correction_reason,
       e.created_by, e.created_at
FROM tailor_daily_entries e
LEFT JOIN orders o ON o.id = e.order_id
LEFT JOIN clients cl ON cl.id = o.client_id
LEFT JOIN LATERAL (
  SELECT id, new_pieces, new_piece_rate, new_garment_type, new_custom_client_name, voided, corrected_by, corrected_at, reason
  FROM entry_corrections c
  WHERE c.entry_id = e.id
  ORDER BY corrected_at DESC, id DESC LIMIT 1
) c ON true
LEFT JOIN users u ON u.id = c.corrected_by;
