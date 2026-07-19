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

  // Financial isolation: cost_price (and the profit it reveals) is manager-only.
  // The secretary reads these models to sell — she must never receive it.
  if (req.user.role !== 'MANAGER') {
    for (const row of rows) delete row.cost_price;
  }

  res.json({ items: rows, limit, offset });
}));

/** Insert the request's media list (images + optional video) for a model. */
async function insertMedia(tx, modelId, media) {
  const inserted = [];
  if (!Array.isArray(media)) return inserted;
  for (const item of media) {
    const url = str(item && item.url);
    if (!url) continue;
    const kind = item.kind === 'video' ? 'video' : 'image';
    const { rows } = await tx.query(
      `INSERT INTO model_media (model_id, url, kind, thumb_url)
       VALUES ($1, $2, $3, $4) RETURNING *`,
      [modelId, url, kind, str(item.thumb_url)]);
    inserted.push(rows[0]);
  }
  return inserted;
}

// Catalog management is open to both roles, BUT cost_price (profit margin)
// stays manager-only: the secretary can never set or read it.
router.post('/', asyncH(async (req, res) => {
  const isManager = req.user.role === 'MANAGER';
  const name = str(req.body.name);
  const price = intOrNull(req.body.price);
  const costPrice = isManager ? (intOrNull(req.body.cost_price) ?? 0) : 0;
  if (!name || price == null) {
    return res.status(400).json({ error: 'Nom et prix (entier ≥ 0) requis.' });
  }
  const model = await db.withTransaction(async (tx) => {
    const { rows } = await tx.query(
      `INSERT INTO pret_a_porter_models (name, fabric_type, price, cost_price, description)
       VALUES ($1, $2, $3, $4, $5) RETURNING *`,
      [name, str(req.body.fabric_type) || '', price, costPrice, str(req.body.description) || '']);
    rows[0].media = await insertMedia(tx, rows[0].id, req.body.media);
    return rows[0];
  });
  if (!isManager) delete model.cost_price; // financial isolation
  res.status(201).json(model);
}));

router.put('/:id', asyncH(async (req, res) => {
  const isManager = req.user.role === 'MANAGER';
  const name = str(req.body.name);
  const price = intOrNull(req.body.price);
  // Secretary writes never touch cost_price → null keeps the existing value.
  const costPrice = isManager && req.body.cost_price !== undefined
    ? intOrNull(req.body.cost_price) : null;
  if (!name || price == null) return res.status(400).json({ error: 'Champs invalides.' });
  const model = await db.withTransaction(async (tx) => {
    const { rows } = await tx.query(
      `UPDATE pret_a_porter_models
       SET name = $1, fabric_type = $2, price = $3, cost_price = COALESCE($4, cost_price), description = $5
       WHERE id = $6 RETURNING *`,
      [name, str(req.body.fabric_type) || '', price, costPrice,
        str(req.body.description) || '', req.params.id]);
    if (!rows[0]) return null;
    // The media list is authoritative: same replace pattern as products.
    await tx.query('DELETE FROM model_media WHERE model_id = $1', [req.params.id]);
    rows[0].media = await insertMedia(tx, rows[0].id, req.body.media);
    return rows[0];
  });
  if (!model) return res.status(404).json({ error: 'Modèle introuvable.' });
  if (!isManager) delete model.cost_price; // financial isolation
  res.json(model);
}));

router.delete('/:id', asyncH(async (req, res) => {
  const { rowCount } = await db.query(
    'DELETE FROM pret_a_porter_models WHERE id = $1', [req.params.id]);
  if (!rowCount) return res.status(404).json({ error: 'Modèle introuvable.' });
  res.status(204).end();
}));

router.get('/:id/stats', managerOnly, asyncH(async (req, res) => {
  const { rows: stats } = await db.query(
    `SELECT COALESCE(SUM(qty), 0)::int AS total_sold,
            COALESCE(SUM(total), 0)::int AS total_revenue
     FROM sales_effective
     WHERE item_id = $1 AND kind = 'pret_a_porter' AND voided = false`,
    [req.params.id]
  );
  const { rows: model } = await db.query('SELECT cost_price FROM pret_a_porter_models WHERE id = $1', [req.params.id]);
  if (!model[0]) return res.status(404).json({ error: 'Modèle introuvable.' });

  const totalSold = stats[0].total_sold;
  const totalRevenue = stats[0].total_revenue;
  const costPrice = model[0].cost_price || 0;
  const totalCost = totalSold * costPrice;
  const totalProfit = totalRevenue - totalCost;

  res.json({
    total_sold: totalSold,
    total_revenue: totalRevenue,
    total_profit: totalProfit
  });
}));

module.exports = router;
