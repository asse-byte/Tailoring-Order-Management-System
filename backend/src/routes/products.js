const express = require('express');
const db = require('../db');
const { managerOnly } = require('../middleware/auth');
const { asyncH, pagination, intOrNull, str } = require('../util');

const router = express.Router();
const CATEGORIES = ['parfum', 'chaussure', 'tissu'];

// Both roles read the catalog (the secretary sells at the counter).
router.get('/', asyncH(async (req, res) => {
  const { limit, offset } = pagination(req);
  const category = CATEGORIES.includes(req.query.category) ? req.query.category : null;
  
  // Aggregate images from product_images table into a JSON array 'images'
  const { rows } = await db.query(
    `SELECT p.*, (p.quantity <= p.low_stock_threshold) AS low_stock,
            COALESCE(json_agg(json_build_object('id', pi.id, 'url', pi.url, 'thumb_url', pi.thumb_url))
            FILTER (WHERE pi.id IS NOT NULL), '[]') AS images
     FROM products p
     LEFT JOIN product_images pi ON pi.product_id = p.id
     WHERE ($1::text IS NULL OR p.category = $1)
     GROUP BY p.id
     ORDER BY p.name LIMIT $2 OFFSET $3`,
    [category, limit, offset]);

  // Financial isolation: cost_price (and the profit it reveals) is manager-only.
  // The secretary reads this catalog to sell — she must never receive it.
  if (req.user.role !== 'MANAGER') {
    for (const row of rows) delete row.cost_price;
  }

  res.json({ items: rows, limit, offset });
}));

// Catalog writes are manager-only. Stock is never edited directly by the
// secretary — it only moves inside the sale transaction (see sales.js).
// Catalog management is open to both roles, BUT cost_price (which reveals the
// profit margin) stays manager-only: the secretary can never set or read it.
router.post('/', asyncH(async (req, res) => {
  const isManager = req.user.role === 'MANAGER';
  const name = str(req.body.name);
  const price = intOrNull(req.body.price);
  const costPrice = isManager ? (intOrNull(req.body.cost_price) ?? 0) : 0;
  const quantity = intOrNull(req.body.quantity) ?? 0;
  if (!name || !CATEGORIES.includes(req.body.category) || price == null || quantity === undefined) {
    return res.status(400).json({ error: 'Nom, catégorie et prix valides requis.' });
  }

  const product = await db.withTransaction(async (tx) => {
    const { rows } = await tx.query(
      `INSERT INTO products (category, name, price, cost_price, quantity, low_stock_threshold)
       VALUES ($1, $2, $3, $4, $5, COALESCE($6, 3)) RETURNING *`,
      [req.body.category, name, price, costPrice, quantity, intOrNull(req.body.low_stock_threshold)]);
    
    const prod = rows[0];
    prod.images = [];
    
    const images = req.body.images;
    if (Array.isArray(images) && images.length > 0) {
      for (const img of images) {
        const url = typeof img === 'string' ? img : str(img.url);
        const thumbUrl = typeof img === 'string' ? null : str(img.thumb_url);
        if (url) {
          const { rows: imgRows } = await tx.query(
            `INSERT INTO product_images (product_id, url, thumb_url)
             VALUES ($1, $2, $3) RETURNING *`,
            [prod.id, url, thumbUrl]);
          prod.images.push(imgRows[0]);
        }
      }
    }
    return prod;
  });

  if (!isManager) delete product.cost_price; // financial isolation
  res.status(201).json(product);
}));

router.put('/:id', asyncH(async (req, res) => {
  const isManager = req.user.role === 'MANAGER';
  const name = str(req.body.name);
  const price = intOrNull(req.body.price);
  // Secretary writes never touch cost_price → null keeps the existing value.
  const costPrice = isManager && req.body.cost_price !== undefined
    ? intOrNull(req.body.cost_price) : null;
  const quantity = intOrNull(req.body.quantity);
  if (!name || !CATEGORIES.includes(req.body.category) || price == null || quantity == null) {
    return res.status(400).json({ error: 'Champs invalides.' });
  }

  const product = await db.withTransaction(async (tx) => {
    const { rows } = await tx.query(
      `UPDATE products SET category = $1, name = $2, price = $3,
         cost_price = COALESCE($4, cost_price), quantity = $5,
         low_stock_threshold = COALESCE($6, low_stock_threshold)
       WHERE id = $7 RETURNING *`,
      [req.body.category, name, price, costPrice, quantity,
        intOrNull(req.body.low_stock_threshold), req.params.id]);

    if (!rows[0]) return null;
    const prod = rows[0];
    prod.images = [];

    // Delete old images
    await tx.query('DELETE FROM product_images WHERE product_id = $1', [req.params.id]);

    // Insert new images
    const images = req.body.images;
    if (Array.isArray(images) && images.length > 0) {
      for (const img of images) {
        const url = typeof img === 'string' ? img : str(img.url);
        const thumbUrl = typeof img === 'string' ? null : str(img.thumb_url);
        if (url) {
          const { rows: imgRows } = await tx.query(
            `INSERT INTO product_images (product_id, url, thumb_url)
             VALUES ($1, $2, $3) RETURNING *`,
            [prod.id, url, thumbUrl]);
          prod.images.push(imgRows[0]);
        }
      }
    }
    return prod;
  });

  if (!product) return res.status(404).json({ error: 'Produit introuvable.' });
  if (!isManager) delete product.cost_price; // financial isolation
  res.json(product);
}));

router.delete('/:id', asyncH(async (req, res) => {
  const { rowCount } = await db.query('DELETE FROM products WHERE id = $1', [req.params.id]);
  if (!rowCount) return res.status(404).json({ error: 'Produit introuvable.' });
  res.status(204).end();
}));

router.get('/:id/stats', managerOnly, asyncH(async (req, res) => {
  const { rows: stats } = await db.query(
    `SELECT COALESCE(SUM(qty), 0)::int AS total_sold,
            COALESCE(SUM(total), 0)::int AS total_revenue
     FROM sales_effective
     WHERE item_id = $1 AND kind = 'produit' AND voided = false`,
    [req.params.id]
  );
  const { rows: prod } = await db.query('SELECT cost_price FROM products WHERE id = $1', [req.params.id]);
  if (!prod[0]) return res.status(404).json({ error: 'Produit introuvable.' });

  const totalSold = stats[0].total_sold;
  const totalRevenue = stats[0].total_revenue;
  const costPrice = prod[0].cost_price || 0;
  const totalCost = totalSold * costPrice;
  const totalProfit = totalRevenue - totalCost;

  res.json({
    total_sold: totalSold,
    total_revenue: totalRevenue,
    total_profit: totalProfit
  });
}));

module.exports = router;
