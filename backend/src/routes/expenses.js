const express = require('express');
const db = require('../db');
const { asyncH, pagination, intOrNull, dateStr, str } = require('../util');

// Mounted manager-only in app.js. Same append-only + correction-log pattern
// as tailor entries: a wrong expense is corrected or voided with a reason,
// never edited in place, never deleted.
const router = express.Router();

router.post('/', asyncH(async (req, res) => {
  const reason = str(req.body.reason);
  const amount = intOrNull(req.body.amount);
  if (!reason || amount == null) {
    return res.status(400).json({ error: 'Motif et montant (entier ≥ 0) requis.' });
  }
  const { rows } = await db.query(
    `INSERT INTO expenses (reason, amount, spent_at, created_by)
     VALUES ($1, $2, COALESCE($3::date, CURRENT_DATE), $4) RETURNING *`,
    [reason, amount, dateStr(req.body.spent_at), req.user.id]);
  res.status(201).json(rows[0]);
}));

router.get('/', asyncH(async (req, res) => {
  const { limit, offset } = pagination(req, 50, 200);
  const from = dateStr(req.query.from);
  const to = dateStr(req.query.to);
  const { rows } = await db.query(
    `SELECT * FROM expenses_effective
     WHERE ($1::date IS NULL OR spent_at >= $1)
       AND ($2::date IS NULL OR spent_at <= $2)
     ORDER BY spent_at DESC, created_at DESC LIMIT $3 OFFSET $4`,
    [from, to, limit, offset]);
  res.json({ items: rows, limit, offset });
}));

router.post('/:id/corrections', asyncH(async (req, res) => {
  const reason = str(req.body.reason);
  if (!reason) {
    return res.status(400).json({ error: 'Le motif de la correction est obligatoire.' });
  }
  // Corrections carry the full new state; anything omitted keeps the
  // currently-effective value (so the "latest wins" view stays simple).
  const { rows: current } = await db.query(
    'SELECT reason, amount, voided FROM expenses_effective WHERE id = $1', [req.params.id]);
  if (!current[0]) return res.status(404).json({ error: 'Dépense introuvable.' });
  const newAmount = req.body.new_amount === undefined
    ? current[0].amount : intOrNull(req.body.new_amount);
  if (newAmount == null) return res.status(400).json({ error: 'new_amount invalide.' });
  const newReason = req.body.new_reason === undefined
    ? current[0].reason : str(req.body.new_reason);
  if (!newReason) return res.status(400).json({ error: 'new_reason invalide.' });
  const voided = typeof req.body.voided === 'boolean' ? req.body.voided : current[0].voided;

  const { rows } = await db.query(
    `INSERT INTO expense_corrections
       (expense_id, new_amount, new_reason, voided, reason, corrected_by)
     VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
    [req.params.id, newAmount, newReason, voided, reason, req.user.id]);
  res.status(201).json(rows[0]);
}));

router.get('/:id/corrections', asyncH(async (req, res) => {
  const { rows } = await db.query(
    `SELECT c.*, u.name AS corrected_by_name
     FROM expense_corrections c JOIN users u ON u.id = c.corrected_by
     WHERE c.expense_id = $1 ORDER BY c.corrected_at DESC`, [req.params.id]);
  res.json({ items: rows });
}));

module.exports = router;
