const express = require('express');
const db = require('../db');
const { asyncH, pagination, str } = require('../util');

const router = express.Router();
const REASONS = ['mesure', 'essayage', 'livraison', 'autre'];

// The agenda merges two sources so a delivery never has to be entered twice:
//   - manual appointments (source 'manual', editable),
//   - every active order's expected delivery date (source 'order', derived,
//     read-only) — so creating an order automatically puts its delivery on
//     the calendar. Orders are the source of truth; nothing is duplicated.
// Sorted nearest-first.
router.get('/', asyncH(async (req, res) => {
  const { limit, offset } = pagination(req, 100, 300);
  const { from, to } = req.query;
  const { rows } = await db.query(
    `SELECT * FROM (
       SELECT a.id, 'manual'::text AS source, a.client_id,
              c.full_name AS client_name, c.phone AS client_phone,
              a.scheduled_at, a.reason, a.notes, NULL::uuid AS order_id
       FROM appointments a JOIN clients c ON c.id = a.client_id
       UNION ALL
       SELECT o.id, 'order'::text AS source, o.client_id,
              c.full_name AS client_name, c.phone AS client_phone,
              o.expected_date::timestamptz AS scheduled_at,
              'livraison'::text AS reason, o.notes, o.id AS order_id
       FROM orders o JOIN clients c ON c.id = o.client_id
       WHERE o.expected_date IS NOT NULL AND o.status <> 'livre'
     ) agenda
     WHERE ($1::timestamptz IS NULL OR scheduled_at >= $1)
       AND ($2::timestamptz IS NULL OR scheduled_at < $2)
     ORDER BY scheduled_at LIMIT $3 OFFSET $4`,
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
