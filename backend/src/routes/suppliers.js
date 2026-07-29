const express = require('express');
const db = require('../db');
const { managerOnly } = require('../middleware/auth');
const { asyncH, pagination, intOrNull, dateStr, str } = require('../util');

// Mounted manager-only in app.js (financial debt & supplier purchases).
const router = express.Router();

// ---- Suppliers directory ----
router.get('/', asyncH(async (req, res) => {
  const { limit, offset } = pagination(req);
  const search = str(req.query.search);
  let rows;
  if (search) {
    ({ rows } = await db.query(
      `SELECT s.*,
              COALESCE(SUM(spe.reste), 0)::int AS total_debt
       FROM suppliers s
       LEFT JOIN supplier_purchases_effective spe ON spe.supplier_id = s.id
       WHERE lower(s.name) LIKE lower($1) || '%' OR s.phone LIKE '%' || $1 || '%'
       GROUP BY s.id ORDER BY s.name LIMIT $2 OFFSET $3`,
      [search, limit, offset]));
  } else {
    ({ rows } = await db.query(
      `SELECT s.*,
              COALESCE(SUM(spe.reste), 0)::int AS total_debt
       FROM suppliers s
       LEFT JOIN supplier_purchases_effective spe ON spe.supplier_id = s.id
       GROUP BY s.id ORDER BY s.name LIMIT $1 OFFSET $2`,
      [limit, offset]));
  }
  res.json({ items: rows, limit, offset });
}));

router.post('/', asyncH(async (req, res) => {
  const name = str(req.body.name);
  if (!name) return res.status(400).json({ error: 'Nom du fournisseur requis.' });
  const { rows } = await db.query(
    `INSERT INTO suppliers (name, phone, address, notes)
     VALUES ($1, $2, $3, $4) RETURNING *`,
    [name, str(req.body.phone) || '', str(req.body.address) || '', str(req.body.notes) || '']);
  res.status(201).json(rows[0]);
}));

router.put('/:id', asyncH(async (req, res) => {
  const name = str(req.body.name);
  if (!name) return res.status(400).json({ error: 'Nom du fournisseur requis.' });
  const { rows } = await db.query(
    `UPDATE suppliers SET name = $1, phone = $2, address = $3, notes = $4
     WHERE id = $5 RETURNING *`,
    [name, str(req.body.phone) || '', str(req.body.address) || '', str(req.body.notes) || '', req.params.id]);
  if (!rows[0]) return res.status(404).json({ error: 'Fournisseur introuvable.' });
  res.json(rows[0]);
}));

router.delete('/:id', asyncH(async (req, res) => {
  const { rowCount } = await db.query('DELETE FROM suppliers WHERE id = $1', [req.params.id]);
  if (!rowCount) return res.status(404).json({ error: 'Fournisseur introuvable.' });
  res.status(204).end();
}));

// ---- Supplier Purchases on Credit ----
router.get('/purchases', asyncH(async (req, res) => {
  const { limit, offset } = pagination(req);
  const supplierId = str(req.query.supplier_id);
  const from = dateStr(req.query.from);
  const to = dateStr(req.query.to);
  const { rows } = await db.query(
    `SELECT spe.*
     FROM supplier_purchases_effective spe
     WHERE ($1::uuid IS NULL OR spe.supplier_id = $1)
       AND ($2::date IS NULL OR spe.purchase_date >= $2)
       AND ($3::date IS NULL OR spe.purchase_date <= $3)
     ORDER BY spe.purchase_date DESC, spe.created_at DESC
     LIMIT $4 OFFSET $5`,
    [supplierId, from, to, limit, offset]);
  res.json({ items: rows, limit, offset });
}));

router.post('/purchases', asyncH(async (req, res) => {
  const supplierId = str(req.body.supplier_id);
  const description = str(req.body.description);
  const totalAmount = intOrNull(req.body.total_amount);
  const advanceAmount = intOrNull(req.body.advance_amount) ?? 0;
  if (!description || totalAmount == null || totalAmount < 0) {
    return res.status(400).json({ error: 'Description et total_amount (≥ 0) requis.' });
  }

  let supplierName = str(req.body.supplier_name);
  if (supplierId) {
    const { rows: supp } = await db.query('SELECT name FROM suppliers WHERE id = $1', [supplierId]);
    if (supp[0]) supplierName = supp[0].name;
  }
  if (!supplierName) supplierName = 'Fournisseur Inconnu';

  const { rows } = await db.query(
    `INSERT INTO supplier_purchases
       (supplier_id, supplier_name_snapshot, description, total_amount, advance_amount, purchase_date, created_by)
     VALUES ($1, $2, $3, $4, $5, COALESCE($6::date, CURRENT_DATE), $7) RETURNING *`,
    [supplierId, supplierName, description, totalAmount, advanceAmount, dateStr(req.body.purchase_date), req.user.id]);
  res.status(201).json(rows[0]);
}));

router.get('/purchases/:id', asyncH(async (req, res) => {
  const { rows } = await db.query(
    'SELECT * FROM supplier_purchases_effective WHERE id = $1', [req.params.id]);
  if (!rows[0]) return res.status(404).json({ error: 'Achat introuvable.' });
  res.json(rows[0]);
}));

// ---- Supplier Payments (Append-Only) ----
router.get('/purchases/:id/payments', asyncH(async (req, res) => {
  const { rows } = await db.query(
    `SELECT p.*, u.name AS created_by_name
     FROM supplier_payments_effective p
     JOIN users u ON u.id = p.created_by
     WHERE p.purchase_id = $1 AND NOT p.voided
     ORDER BY p.paid_at DESC, p.created_at DESC`, [req.params.id]);
  res.json({ items: rows });
}));

router.post('/purchases/:id/payments', asyncH(async (req, res) => {
  const amount = intOrNull(req.body.amount);
  if (amount == null || amount <= 0) {
    return res.status(400).json({ error: 'Montant du règlement (entier > 0) requis.' });
  }
  const { rows: pur } = await db.query('SELECT id FROM supplier_purchases WHERE id = $1', [req.params.id]);
  if (!pur[0]) return res.status(404).json({ error: 'Achat introuvable.' });

  const { rows } = await db.query(
    `INSERT INTO supplier_payments (purchase_id, amount, paid_at, note, created_by)
     VALUES ($1, $2, COALESCE($3::date, CURRENT_DATE), $4, $5) RETURNING *`,
    [req.params.id, amount, dateStr(req.body.paid_at), str(req.body.note), req.user.id]);
  res.status(201).json(rows[0]);
}));

router.post('/payments/:paymentId/corrections', asyncH(async (req, res) => {
  const reason = str(req.body.reason);
  if (!reason) {
    return res.status(400).json({ error: 'Le motif de la correction est obligatoire.' });
  }
  const { rows: cur } = await db.query(
    'SELECT amount, voided FROM supplier_payments_effective WHERE id = $1', [req.params.paymentId]);
  if (!cur[0]) return res.status(404).json({ error: 'Règlement introuvable.' });

  const newAmount = req.body.new_amount === undefined ? cur[0].amount : intOrNull(req.body.new_amount);
  if (newAmount == null) return res.status(400).json({ error: 'new_amount invalide.' });
  const voided = typeof req.body.voided === 'boolean' ? req.body.voided : cur[0].voided;

  const { rows } = await db.query(
    `INSERT INTO supplier_payment_corrections (payment_id, new_amount, voided, reason, corrected_by)
     VALUES ($1, $2, $3, $4, $5) RETURNING *`,
    [req.params.paymentId, newAmount, voided, reason, req.user.id]);
  res.status(201).json(rows[0]);
}));

module.exports = router;
