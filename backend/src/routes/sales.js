const express = require('express');
const db = require('../db');
const { managerOnly } = require('../middleware/auth');
const { asyncH, pagination, intOrNull } = require('../util');

const router = express.Router();

/**
 * Register a sale — allowed for BOTH roles (the secretary sells at the
 * counter), but the server prices everything itself:
 *   - unit_price is read from the DB row (any price/total in the request
 *     body is ignored outright);
 *   - for products, stock is decremented in the SAME transaction with a
 *     `quantity >= qty` guard → stock and revenue can never disagree.
 */
router.post('/', asyncH(async (req, res) => {
  const { kind, item_id: itemId } = req.body;
  const qty = intOrNull(req.body.qty);
  if (!['produit', 'pret_a_porter'].includes(kind) || !itemId || !qty || qty < 1) {
    return res.status(400).json({ error: 'kind, item_id et qty (≥1) requis.' });
  }

  const sale = await db.withTransaction(async (tx) => {
      let name; let price;
      if (kind === 'produit') {
        const { rows } = await tx.query(
          'SELECT name, price, quantity FROM products WHERE id = $1 FOR UPDATE', [itemId]);
        if (!rows[0]) return { status: 404, error: 'Produit introuvable.' };
        if (rows[0].quantity < qty) {
          return { status: 409, error: `Stock insuffisant (${rows[0].quantity} restant).` };
        }
        await tx.query(
          'UPDATE products SET quantity = quantity - $1 WHERE id = $2', [qty, itemId]);
        ({ name, price } = rows[0]);
      } else {
        const { rows } = await tx.query(
          'SELECT name, price FROM pret_a_porter_models WHERE id = $1', [itemId]);
        if (!rows[0]) return { status: 404, error: 'Modèle introuvable.' };
        ({ name, price } = rows[0]);
      }
      const { rows: inserted } = await tx.query(
        `INSERT INTO sales (kind, item_id, item_name, qty, unit_price, total, created_by)
         VALUES ($1, $2, $3, $4::int, $5::int, $4::int * $5::int, $6) RETURNING *`,
        [kind, itemId, name, qty, price, req.user.id]);
      return { status: 201, sale: inserted[0] };
    });

  if (sale.error) return res.status(sale.status).json({ error: sale.error });
  // The secretary gets a bare confirmation — no totals echo needed; the
  // manager sees full rows via GET.
  if (req.user.role !== 'MANAGER') {
    return res.status(201).json({ ok: true, id: sale.sale.id });
  }
  return res.status(201).json(sale.sale);
}));

// Revenue history is MANAGER-ONLY (write-only pattern for the secretary).
router.get('/', managerOnly, asyncH(async (req, res) => {
  const { limit, offset } = pagination(req, 50, 200);
  const { from, to, kind } = req.query;
  const { rows } = await db.query(
    `SELECT s.*, u.name AS seller_name FROM sales s
     JOIN users u ON u.id = s.created_by
     WHERE ($1::date IS NULL OR s.sold_at >= $1)
       AND ($2::date IS NULL OR s.sold_at < $2::date + 1)
       AND ($3::text IS NULL OR s.kind = $3)
     ORDER BY s.sold_at DESC LIMIT $4 OFFSET $5`,
    [from || null, to || null,
      ['produit', 'pret_a_porter'].includes(kind) ? kind : null, limit, offset]);
  res.json({ items: rows, limit, offset });
}));

module.exports = router;
