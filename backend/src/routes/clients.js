const express = require('express');
const db = require('../db');
const { asyncH, pagination, str } = require('../util');

const router = express.Router();

// Instant search: name prefix (uses the lower(full_name) index) or phone.
router.get('/', asyncH(async (req, res) => {
  const { limit, offset } = pagination(req);
  const search = str(req.query.search);
  let rows;
  if (search) {
    ({ rows } = await db.query(
      `SELECT * FROM clients
       WHERE lower(full_name) LIKE lower($1) || '%' OR phone LIKE '%' || $1 || '%'
       ORDER BY full_name LIMIT $2 OFFSET $3`,
      [search, limit, offset]));
  } else {
    ({ rows } = await db.query(
      'SELECT * FROM clients ORDER BY created_at DESC LIMIT $1 OFFSET $2',
      [limit, offset]));
  }
  res.json({ items: rows, limit, offset });
}));

router.post('/', asyncH(async (req, res) => {
  const fullName = str(req.body.full_name);
  if (!fullName) return res.status(400).json({ error: 'Nom complet requis.' });
  const gender = str(req.body.gender) || 'homme';
  if (!['homme', 'femme'].includes(gender)) return res.status(400).json({ error: 'Genre invalide.' });
  const { rows } = await db.query(
    `INSERT INTO clients (full_name, phone, address, gender) VALUES ($1, $2, $3, $4) RETURNING *`,
    [fullName, str(req.body.phone) || '', str(req.body.address), gender]);
  res.status(201).json(rows[0]);
}));

router.get('/:id', asyncH(async (req, res) => {
  const { rows } = await db.query('SELECT * FROM clients WHERE id = $1', [req.params.id]);
  if (!rows[0]) return res.status(404).json({ error: 'Client introuvable.' });
  res.json(rows[0]);
}));

router.put('/:id', asyncH(async (req, res) => {
  const fullName = str(req.body.full_name);
  if (!fullName) return res.status(400).json({ error: 'Nom complet requis.' });
  const gender = str(req.body.gender) || 'homme';
  if (!['homme', 'femme'].includes(gender)) return res.status(400).json({ error: 'Genre invalide.' });
  const { rows } = await db.query(
    `UPDATE clients SET full_name = $1, phone = $2, address = $3, gender = $4
     WHERE id = $5 RETURNING *`,
    [fullName, str(req.body.phone) || '', str(req.body.address), gender, req.params.id]);
  if (!rows[0]) return res.status(404).json({ error: 'Client introuvable.' });
  res.json(rows[0]);
}));

router.delete('/:id', asyncH(async (req, res) => {
  const { rowCount } = await db.query('DELETE FROM clients WHERE id = $1', [req.params.id]);
  if (!rowCount) return res.status(404).json({ error: 'Client introuvable.' });
  res.status(204).end();
}));

// ---- measurements (flexible key-value per garment type) ----

router.get('/:id/measurements', asyncH(async (req, res) => {
  const { rows } = await db.query(
    'SELECT * FROM client_measurements WHERE client_id = $1 ORDER BY garment_type',
    [req.params.id]);
  res.json({ items: rows });
}));

router.put('/:id/measurements/:garmentType', asyncH(async (req, res) => {
  const measures = req.body.measures;
  if (typeof measures !== 'object' || measures === null || Array.isArray(measures)) {
    return res.status(400).json({ error: 'measures doit être un objet clé→valeur.' });
  }
  const { rows } = await db.query(
    `INSERT INTO client_measurements (client_id, garment_type, measures)
     VALUES ($1, $2, $3)
     ON CONFLICT (client_id, garment_type)
     DO UPDATE SET measures = EXCLUDED.measures, updated_at = now()
     RETURNING *`,
    [req.params.id, req.params.garmentType, JSON.stringify(measures)]);
  res.json(rows[0]);
}));

router.delete('/:id/measurements/:garmentType', asyncH(async (req, res) => {
  await db.query(
    'DELETE FROM client_measurements WHERE client_id = $1 AND garment_type = $2',
    [req.params.id, req.params.garmentType]);
  res.status(204).end();
}));

// ---- per-client order history (feeds the client detail screen) ----

router.get('/:id/orders', asyncH(async (req, res) => {
  const { limit, offset } = pagination(req);
  // Total is derived from the (append-only) effective line items.
  const { rows } = await db.query(
    `SELECT o.*,
       COALESCE((SELECT SUM(line_total)::int FROM order_items_effective
                 WHERE order_id = o.id), 0) AS total
     FROM orders o WHERE o.client_id = $1
     ORDER BY o.created_at DESC LIMIT $2 OFFSET $3`,
    [req.params.id, limit, offset]);
  res.json({ items: rows, limit, offset });
}));

// ---- custom garments settings (shared by both roles) ----

router.get('/settings/custom-garments', asyncH(async (req, res) => {
  const { rows } = await db.query("SELECT value FROM settings WHERE key = 'custom_garments'");
  res.json(rows[0] ? rows[0].value : { homme: {}, femme: {} });
}));

router.put('/settings/custom-garments', asyncH(async (req, res) => {
  const custom = req.body;
  if (typeof custom !== 'object' || custom === null) {
    return res.status(400).json({ error: 'custom_garments doit être un objet.' });
  }
  await db.query(
    "UPDATE settings SET value = $1 WHERE key = 'custom_garments'",
    [JSON.stringify(custom)]
  );
  res.json({ ok: true });
}));

module.exports = router;
