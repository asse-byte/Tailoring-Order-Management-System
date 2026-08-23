-- ============================================================================
-- Migration 027 — remove the shop-wide "tarif par pièce par défaut".
--
-- Owner decision, 2026-08-23. The setting was the LAST link in the tailor wage
-- chain used by POST /api/tailor-entries:
--
--     rate typed on the entry  →  the tailor's own piece_rate  →  this default
--
-- In practice it never fired: it is seeded at 0, and a rate of 0 is rejected by
-- the route anyway, so every shop already had to set a real rate per tailor or
-- per entry. The owner was told it sat in the formula and asked for it to go
-- regardless, so the chain is now two links and a tailor with no rate is an
-- explicit error rather than a silent fallback to a number nobody remembers
-- setting.
--
-- Wages already recorded are untouched: `tailor_daily_entries.piece_rate` is
-- snapshotted onto every row at insert time, so no past amount moves.
-- ============================================================================

DELETE FROM settings WHERE key = 'default_piece_rate';
