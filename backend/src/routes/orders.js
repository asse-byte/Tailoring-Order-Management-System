const express = require('express');
const db = require('../db');
const { managerOnly } = require('../middleware/auth');
const { asyncH, pagination, intOrNull, dateStr, str } = require('../util');

const router = express.Router();
const STATUSES = ['en_cours', 'pret', 'livre'];

// Historique is simply ?status=livre — the same row, moved by status.
// from/to filter on the delivery date for delivered rows (Historique spec:
// search by client or date), on the creation date for active ones.
router.get('/', asyncH(async (req, res) => {
  const { limit, offset } = pagination(req);
  const status = STATUSES.includes(req.query.status) ? req.query.status : null;
  const clientId = str(req.query.client_id);
  const from = dateStr(req.query.from);
  const to = dateStr(req.query.to);
  const { rows } = await db.query(
    `SELECT o.*, c.full_name AS client_name, c.phone AS client_phone
     FROM orders o JOIN clients c ON c.id = o.client_id
     WHERE ($1::text IS NULL OR o.status = $1)
       AND ($2::uuid IS NULL OR o.client_id = $2)
       AND ($3::date IS NULL OR COALESCE(o.delivered_date, o.created_at::date) >= $3)
       AND ($4::date IS NULL OR COALESCE(o.delivered_date, o.created_at::date) <= $4)
     ORDER BY CASE WHEN o.status = 'livre' THEN o.delivered_date END DESC,
              o.created_at DESC
     LIMIT $5 OFFSET $6`,
    [status, clientId, from, to, limit, offset]);
  res.json({ items: rows, limit, offset });
}));

router.post('/', asyncH(async (req, res) => {
  const clientId = str(req.body.client_id);
  const garmentType = str(req.body.garment_type);
  // intOrNull → null (missing/empty → default 0), a number (valid), or
  // undefined (present but invalid, e.g. negative/non-integer) → reject.
  const price = intOrNull(req.body.price);
  const advance = intOrNull(req.body.advance);
  if (!clientId || !garmentType) {
    return res.status(400).json({ error: 'client_id et garment_type requis.' });
  }
  if (price === undefined || advance === undefined) {
    return res.status(400).json({ error: 'Montants invalides (entiers ≥ 0).' });
  }
  // Freeze the client's measurements into the order (reference at cut time).
  let snapshot = req.body.measurements_snapshot;
  if (typeof snapshot !== 'object' || snapshot === null) {
    const { rows: m } = await db.query(
      'SELECT garment_type, measures FROM client_measurements WHERE client_id = $1',
      [clientId]);
    snapshot = Object.fromEntries(m.map((r) => [r.garment_type, r.measures]));
  }
  const { rows } = await db.query(
    `INSERT INTO orders (client_id, garment_type, fabric, measurements_snapshot,
                         price, advance, start_date, expected_date, notes)
     VALUES ($1, $2, $3, $4, $5, $6,
             COALESCE($7::date, CURRENT_DATE), $8::date, $9)
     RETURNING *`,
    [clientId, garmentType, str(req.body.fabric) || '', JSON.stringify(snapshot),
      price ?? 0, advance ?? 0, dateStr(req.body.start_date),
      dateStr(req.body.expected_date), str(req.body.notes)]);
  res.status(201).json(rows[0]);
}));

router.get('/:id', asyncH(async (req, res) => {
  const { rows } = await db.query(
    `SELECT o.*, c.full_name AS client_name, c.phone AS client_phone
     FROM orders o JOIN clients c ON c.id = o.client_id WHERE o.id = $1`,
    [req.params.id]);
  if (!rows[0]) return res.status(404).json({ error: 'Commande introuvable.' });
  res.json(rows[0]);
}));

router.put('/:id', asyncH(async (req, res) => {
  const status = req.body.status;
  if (status !== undefined && !STATUSES.includes(status)) {
    return res.status(400).json({ error: `status doit être: ${STATUSES.join(', ')}.` });
  }
  const price = req.body.price === undefined ? null : intOrNull(req.body.price);
  const advance = req.body.advance === undefined ? null : intOrNull(req.body.advance);
  if (price === undefined || advance === undefined) {
    return res.status(400).json({ error: 'Montants invalides.' });
  }
  const { rows } = await db.query(
    `UPDATE orders SET
       garment_type   = COALESCE($1, garment_type),
       fabric         = COALESCE($2, fabric),
       price          = COALESCE($3, price),
       advance        = COALESCE($4, advance),
       expected_date  = COALESCE($5::date, expected_date),
       notes          = COALESCE($6, notes),
       status         = COALESCE($7, status),
       delivered_date = CASE
         WHEN $7 = 'livre' AND status <> 'livre' THEN CURRENT_DATE
         WHEN $7 IS NOT NULL AND $7 <> 'livre' THEN NULL
         ELSE delivered_date END
     WHERE id = $8 RETURNING *`,
    [str(req.body.garment_type), str(req.body.fabric), price, advance,
      dateStr(req.body.expected_date), str(req.body.notes),
      status || null, req.params.id]);
  if (!rows[0]) return res.status(404).json({ error: 'Commande introuvable.' });
  res.json(rows[0]);
}));

router.delete('/:id', managerOnly, asyncH(async (req, res) => {
  const { rowCount } = await db.query('DELETE FROM orders WHERE id = $1', [req.params.id]);
  if (!rowCount) return res.status(404).json({ error: 'Commande introuvable.' });
  res.status(204).end();
}));

module.exports = router;
