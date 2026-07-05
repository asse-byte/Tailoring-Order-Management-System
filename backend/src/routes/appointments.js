const express = require('express');
const db = require('../db');
const { asyncH, pagination, str } = require('../util');

const router = express.Router();
const REASONS = ['mesure', 'essayage', 'livraison', 'autre'];

router.get('/', asyncH(async (req, res) => {
  const { limit, offset } = pagination(req, 50, 200);
  const { from, to } = req.query;
  const { rows } = await db.query(
    `SELECT a.*, c.full_name AS client_name, c.phone AS client_phone
     FROM appointments a JOIN clients c ON c.id = a.client_id
     WHERE ($1::timestamptz IS NULL OR a.scheduled_at >= $1)
       AND ($2::timestamptz IS NULL OR a.scheduled_at < $2)
     ORDER BY a.scheduled_at LIMIT $3 OFFSET $4`,
    [from || null, to || null, limit, offset]);
  res.json({ items: rows, limit, offset });
}));

router.post('/', asyncH(async (req, res) => {
  const clientId = str(req.body.client_id);
  const scheduledAt = str(req.body.scheduled_at);
  if (!clientId || !scheduledAt) {
    return res.status(400).json({ error: 'client_id et scheduled_at requis.' });
  }
  const { rows } = await db.query(
    `INSERT INTO appointments (client_id, scheduled_at, reason, notes)
     VALUES ($1, $2, $3, $4) RETURNING *`,
    [clientId, scheduledAt,
      REASONS.includes(req.body.reason) ? req.body.reason : 'autre',
      str(req.body.notes)]);
  res.status(201).json(rows[0]);
}));

router.put('/:id', asyncH(async (req, res) => {
  const { rows } = await db.query(
    `UPDATE appointments SET
       scheduled_at = COALESCE($1::timestamptz, scheduled_at),
       reason = COALESCE($2, reason),
       notes = COALESCE($3, notes)
     WHERE id = $4 RETURNING *`,
    [str(req.body.scheduled_at),
      REASONS.includes(req.body.reason) ? req.body.reason : null,
      str(req.body.notes), req.params.id]);
  if (!rows[0]) return res.status(404).json({ error: 'Rendez-vous introuvable.' });
  res.json(rows[0]);
}));

router.delete('/:id', asyncH(async (req, res) => {
  const { rowCount } = await db.query(
    'DELETE FROM appointments WHERE id = $1', [req.params.id]);
  if (!rowCount) return res.status(404).json({ error: 'Rendez-vous introuvable.' });
  res.status(204).end();
}));

module.exports = router;
