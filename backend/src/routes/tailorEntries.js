const express = require('express');
const db = require('../db');
const { asyncH, intOrNull, dateStr, isoWeekId, str } = require('../util');

// Mounted manager-only in app.js. The tables behind this router are
// APPEND-ONLY at the database level: there is no update/delete route here,
// and even direct SQL raises an exception (trigger). Mistakes are fixed by
// POSTing a correction with a mandatory reason — the audit trail is total.
const router = express.Router();

router.post('/', asyncH(async (req, res) => {
  const piecesCount = intOrNull(req.body.pieces_count);
  const entryDate = dateStr(req.body.entry_date);
  const tailorId = req.body.tailor_id;
  if (!tailorId || piecesCount == null || !entryDate) {
    return res.status(400).json({ error: 'tailor_id, entry_date et pieces_count requis.' });
  }
  // Rate priority: per-tailor rate → shop default. Snapshotted on the row so
  // later rate changes never rewrite past wages.
  const { rows: rateRows } = await db.query(
    `SELECT COALESCE(
       (SELECT piece_rate FROM staff_pay WHERE staff_id = $1),
       (SELECT (value #>> '{}')::int FROM settings WHERE key = 'default_piece_rate')
     ) AS rate`, [tailorId]);
  const rate = rateRows[0].rate;
  if (rate == null || rate <= 0) {
    return res.status(400).json({
      error: 'Aucun prix par pièce défini pour ce couturier (ni de valeur par défaut).',
    });
  }
  const { rows } = await db.query(
    `INSERT INTO tailor_daily_entries
       (tailor_id, entry_date, pieces_count, piece_rate, week_id, created_by)
     VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
    [tailorId, entryDate, piecesCount, rate, isoWeekId(entryDate), req.user.id]);
  res.status(201).json(rows[0]);
}));

// Effective values (latest correction wins) — used by every list & total.
router.get('/', asyncH(async (req, res) => {
  const weekId = str(req.query.week_id);
  const tailorId = str(req.query.tailor_id);
  const from = dateStr(req.query.from);
  const to = dateStr(req.query.to);
  const { rows } = await db.query(
    `SELECT e.*, s.full_name AS tailor_name
     FROM tailor_entries_effective e JOIN staff s ON s.id = e.tailor_id
     WHERE ($1::text IS NULL OR e.week_id = $1)
       AND ($2::uuid IS NULL OR e.tailor_id = $2)
       AND ($3::date IS NULL OR e.entry_date >= $3)
       AND ($4::date IS NULL OR e.entry_date <= $4)
     ORDER BY e.entry_date DESC LIMIT 500`,
    [weekId, tailorId, from, to]);
  res.json({ items: rows });
}));

// Weekly totals per tailor — what gets paid every week.
router.get('/weekly', asyncH(async (req, res) => {
  const weekId = str(req.query.week_id);
  if (!weekId) return res.status(400).json({ error: 'week_id requis (ex: 2026-W27).' });
  const { rows } = await db.query(
    `SELECT e.tailor_id, s.full_name AS tailor_name,
            SUM(e.pieces_count)::int AS pieces_total,
            SUM(e.amount)::int AS amount_total,
            COUNT(*)::int AS days_worked
     FROM tailor_entries_effective e JOIN staff s ON s.id = e.tailor_id
     WHERE e.week_id = $1
     GROUP BY e.tailor_id, s.full_name ORDER BY s.full_name`, [weekId]);
  res.json({ week_id: weekId, items: rows });
}));

// ---- correction log (the ONLY way to change a number) ----

router.post('/:id/corrections', asyncH(async (req, res) => {
  const newPieces = intOrNull(req.body.new_pieces);
  const reason = str(req.body.reason);
  if (newPieces == null) return res.status(400).json({ error: 'new_pieces requis (entier ≥ 0).' });
  if (!reason) {
    return res.status(400).json({ error: 'Le motif de la correction est obligatoire.' });
  }
  // Snapshot the currently-effective value as old_pieces.
  const { rows: current } = await db.query(
    'SELECT pieces_count FROM tailor_entries_effective WHERE id = $1', [req.params.id]);
  if (!current[0]) return res.status(404).json({ error: 'Saisie introuvable.' });
  const { rows } = await db.query(
    `INSERT INTO entry_corrections (entry_id, old_pieces, new_pieces, reason, corrected_by)
     VALUES ($1, $2, $3, $4, $5) RETURNING *`,
    [req.params.id, current[0].pieces_count, newPieces, reason, req.user.id]);
  res.status(201).json(rows[0]);
}));

// Full history: who changed what, when, from → to, and why.
router.get('/:id/corrections', asyncH(async (req, res) => {
  const { rows } = await db.query(
    `SELECT c.*, u.name AS corrected_by_name
     FROM entry_corrections c JOIN users u ON u.id = c.corrected_by
     WHERE c.entry_id = $1 ORDER BY c.corrected_at DESC`, [req.params.id]);
  res.json({ items: rows });
}));

module.exports = router;
