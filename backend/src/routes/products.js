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
    
  res.json({ items: rows, limit, offset });
}));

// Catalog writes are manager-only. Stock is never edited directly by the
// secretary — it only moves inside the sale transaction (see sales.js).
router.post('/', managerOnly, asyncH(async (req, res) => {
  const name = str(req.body.name);
  const price = intOrNull(req.body.price);
  const quantity = intOrNull(req.body.quantity) ?? 0;
  if (!name || !CATEGORIES.includes(req.body.category) || price == null || quantity === undefined) {
    return res.status(400).json({ error: 'Nom, catégorie et prix valides requis.' });
  }

  const product = await db.withTransaction(async (tx) => {
    const { rows } = await tx.query(
      `INSERT INTO products (category, name, price, quantity, low_stock_threshold)
       VALUES ($1, $2, $3, $4, COALESCE($5, 3)) RETURNING *`,
      [req.body.category, name, price, quantity, intOrNull(req.body.low_stock_threshold)]);
    
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

  res.status(201).json(product);
}));

router.put('/:id', managerOnly, asyncH(async (req, res) => {
  const name = str(req.body.name);
  const price = intOrNull(req.body.price);
  const quantity = intOrNull(req.body.quantity);
  if (!name || !CATEGORIES.includes(req.body.category) || price == null || quantity == null) {
    return res.status(400).json({ error: 'Champs invalides.' });
  }

  const product = await db.withTransaction(async (tx) => {
    const { rows } = await tx.query(
      `UPDATE products SET category = $1, name = $2, price = $3, quantity = $4,
         low_stock_threshold = COALESCE($5, low_stock_threshold)
       WHERE id = $6 RETURNING *`,
      [req.body.category, name, price, quantity,
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
  res.json(product);
}));

router.delete('/:id', managerOnly, asyncH(async (req, res) => {
  const { rowCount } = await db.query('DELETE FROM products WHERE id = $1', [req.params.id]);
  if (!rowCount) return res.status(404).json({ error: 'Produit introuvable.' });
  res.status(204).end();
}));

module.exports = router;
