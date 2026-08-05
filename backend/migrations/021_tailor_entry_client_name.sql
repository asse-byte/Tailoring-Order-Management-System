-- ============================================================================
-- Allow custom_client_name on tailor_daily_entries and corrections, so client
-- names typed manually or linked can be read and corrected.
-- ============================================================================

ALTER TABLE tailor_daily_entries ADD COLUMN custom_client_name text;
ALTER TABLE entry_corrections ADD COLUMN new_custom_client_name text;

DROP VIEW tailor_entries_effective;
CREATE VIEW tailor_entries_effective AS
SELECT e.id, e.tailor_id, e.tailor_name_snapshot, e.entry_date, e.week_id,
       COALESCE(c.new_piece_rate, e.piece_rate)      AS piece_rate,
       COALESCE(c.new_garment_type, e.garment_type)  AS garment_type,
       e.order_id,
       COALESCE(c.new_custom_client_name, e.custom_client_name, cl.full_name, o.client_name_snapshot) AS client_name,
       COALESCE(c.new_pieces, e.pieces_count)         AS pieces_count,
       CASE WHEN COALESCE(c.voided, false) THEN 0
            ELSE COALESCE(c.new_pieces, e.pieces_count)
               * COALESCE(c.new_piece_rate, e.piece_rate) END AS amount,
       COALESCE(c.voided, false)                      AS voided,
       (c.id IS NOT NULL)                             AS corrected,
       e.created_by, e.created_at
FROM tailor_daily_entries e
LEFT JOIN orders o ON o.id = e.order_id
LEFT JOIN clients cl ON cl.id = o.client_id
LEFT JOIN LATERAL (
  SELECT id, new_pieces, new_piece_rate, new_garment_type, new_custom_client_name, voided
  FROM entry_corrections c
  WHERE c.entry_id = e.id
  ORDER BY corrected_at DESC, id DESC LIMIT 1
) c ON true;
