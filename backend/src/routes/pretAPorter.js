const express = require('express');
const db = require('../db');
const { managerOnly } = require('../middleware/auth');
const { asyncH, pagination, intOrNull, str } = require('../util');

const router = express.Router();

router.get('/', asyncH(async (req, res) => {
  const { limit, offset } = pagination(req);
  const { rows } = await db.query(
    `SELECT m.*,
       COALESCE(json_agg(json_build_object('id', md.id, 'url', md.url,
         'kind', md.kind, 'thumb_url', md.thumb_url))
         FILTER (WHERE md.id IS NOT NULL), '[]') AS media
     FROM pret_a_porter_models m
     LEFT JOIN model_media md ON md.model_id = m.id
     GROUP BY m.id ORDER BY m.created_at DESC LIMIT $1 OFFSET $2`,
    [limit, offset]);
  res.json({ items: rows, limit, offset });
}));

router.post('/', managerOnly, asyncH(async (req, res) => {
  const name = str(req.body.name);
  const price = intOrNull(req.body.price);
  if (!name || price == null) {
    return res.status(400).json({ error: 'Nom et prix (entier ≥ 0) requis.' });
  }
  const { rows } = await db.query(
    `INSERT INTO pret_a_porter_models (name, fabric_type, price)
     VALUES ($1, $2, $3) RETURNING *`,
    [name, str(req.body.fabric_type) || '', price]);
  res.status(201).json(rows[0]);
}));

router.put('/:id', managerOnly, asyncH(async (req, res) => {
  const name = str(req.body.name);
  const price = intOrNull(req.body.price);
  if (!name || price == null) return res.status(400).json({ error: 'Champs invalides.' });
  const { rows } = await db.query(
    `UPDATE pret_a_porter_models SET name = $1, fabric_type = $2, price = $3
     WHERE id = $4 RETURNING *`,
    [name, str(req.body.fabric_type) || '', price, req.params.id]);
  if (!rows[0]) return res.status(404).json({ error: 'Modèle introuvable.' });
  res.json(rows[0]);
}));

router.delete('/:id', managerOnly, asyncH(async (req, res) => {
  const { rowCount } = await db.query(
    'DELETE FROM pret_a_porter_models WHERE id = $1', [req.params.id]);
  if (!rowCount) return res.status(404).json({ error: 'Modèle introuvable.' });
  res.status(204).end();
}));

module.exports = router;
