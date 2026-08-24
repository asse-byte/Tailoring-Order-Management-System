const express = require('express');
const db = require('../db');
const { managerOnly } = require('../middleware/auth');
const { asyncH, pagination, intOrNull, dateStr, str } = require('../util');

const router = express.Router();
const STATUSES = ['en_cours', 'livre'];

// Mounted manager-only in app.js: wholesale carries totals, amounts paid and
// outstanding balances, so it is a money module like every other one and the
// secretary gets 403 on every route here (owner decision 2026-08-03).
router.get('/orders', asyncH(async (req, res) => {
  const { limit, offset } = pagination(req);
  const status = STATUSES.includes(req.query.status) ? req.query.status : null;
  const merchantName = str(req.query.merchant);
  const from = dateStr(req.query.from);
  const to = dateStr(req.query.to);
  const { rows } = await db.query(
    `SELECT wo.*
     FROM wholesale_orders_effective wo
     WHERE ($1::text IS NULL OR wo.status = $1)
       AND ($2::text IS NULL OR lower(wo.merchant_name) LIKE lower($2) || '%')
       AND ($3::date IS NULL OR wo.order_date >= $3)
       AND ($4::date IS NULL OR wo.order_date <= $4)
     ORDER BY wo.order_date DESC, wo.created_at DESC
     LIMIT $5 OFFSET $6`,
    [status, merchantName, from, to, limit, offset]);
  res.json({ items: rows, limit, offset });
}));

router.post('/orders', asyncH(async (req, res) => {
  const merchantName = str(req.body.merchant_name);
  const totalAmount = intOrNull(req.body.total_amount);
  const advanceAmount = intOrNull(req.body.advance_amount) ?? 0;
  const items = req.body.items || [];
  if (!merchantName || totalAmount == null || totalAmount < 0) {
    return res.status(400).json({ error: 'Nom du commerçant et total_amount (≥ 0) requis.' });
  }

  // The advance is REAL CASH: it gets a dated payment row like every other
  // settlement (migration 024). Before that it lived only in the
  // `advance_amount` column, so it had no date and could never be attributed
  // to a period — the shop's wholesale revenue was invisible to Finances.
  const created = await db.withTransaction(async (tx) => {
    const { rows } = await tx.query(
      `INSERT INTO wholesale_orders
         (merchant_name, merchant_phone, items, total_amount, advance_amount, status, order_date, notes, created_by)
       VALUES ($1, $2, $3, $4, $5, 'en_cours', COALESCE($6::date, CURRENT_DATE), $7, $8) RETURNING *`,
      [merchantName, str(req.body.merchant_phone) || '', JSON.stringify(items),
        totalAmount, advanceAmount, dateStr(req.body.order_date), str(req.body.notes), req.user.id]);
    if (advanceAmount > 0) {
      await tx.query(
        `INSERT INTO wholesale_payments (order_id, amount, paid_at, note, created_by)
         VALUES ($1, $2, $3::date, 'Acompte initial', $4)`,
        [rows[0].id, advanceAmount, rows[0].order_date, req.user.id]);
    }
    return rows[0];
  });
  res.status(201).json(created);
}));

router.get('/orders/:id', asyncH(async (req, res) => {
  const { rows } = await db.query(
    'SELECT * FROM wholesale_orders_effective WHERE id = $1', [req.params.id]);
  if (!rows[0]) return res.status(404).json({ error: 'Commande en gros introuvable.' });
  res.json(rows[0]);
}));

router.put('/orders/:id', asyncH(async (req, res) => {
  const status = req.body.status;
  if (status !== undefined && !STATUSES.includes(status)) {
    return res.status(400).json({ error: 'status invalide (en_cours|livre).' });
  }
  const totalAmount = req.body.total_amount === undefined ? null : intOrNull(req.body.total_amount);
  const items = req.body.items ? JSON.stringify(req.body.items) : null;
  // `advance_amount` is deliberately NOT editable here: since migration 024 the
  // advance is an ordinary dated payment row, and cash rows are append-only.
  // Changing what the merchant paid goes through the payment correction
  // endpoint, with its mandatory reason and audit trail.

  const { rows } = await db.query(
    `UPDATE wholesale_orders SET
       merchant_name  = COALESCE($1, merchant_name),
       merchant_phone = COALESCE($2, merchant_phone),
       notes          = COALESCE($3, notes),
       status         = COALESCE($4, status),
       items          = COALESCE($5::jsonb, items),
       total_amount   = COALESCE($6, total_amount),
       order_date     = COALESCE($7::date, order_date),
       delivered_date = CASE
         WHEN $4 = 'livre' AND status <> 'livre' THEN CURRENT_DATE
         WHEN $4 IS NOT NULL AND $4 <> 'livre' THEN NULL
         ELSE delivered_date END
     WHERE id = $8 RETURNING *`,
    [str(req.body.merchant_name), str(req.body.merchant_phone), str(req.body.notes),
     status || null, items, totalAmount, dateStr(req.body.order_date), req.params.id]);
  if (!rows[0]) return res.status(404).json({ error: 'Commande introuvable.' });
  res.json(rows[0]);
}));

router.delete('/orders/:id', managerOnly, asyncH(async (req, res) => {
  const { rows: pay } = await db.query(
    'SELECT 1 FROM wholesale_payments_effective WHERE order_id = $1 AND NOT voided LIMIT 1',
    [req.params.id]
  );
  if (pay[0]) {
    return res.status(409).json({
      error: 'Impossible de supprimer une commande ayant des règlements (historique financier append-only).',
    });
  }
  const { rowCount } = await db.query('DELETE FROM wholesale_orders WHERE id = $1', [req.params.id]);
  if (!rowCount) return res.status(404).json({ error: 'Commande introuvable.' });
  res.status(204).end();
}));

// Wholesale Payments (Append-Only)
router.get('/orders/:id/payments', asyncH(async (req, res) => {
  const { rows } = await db.query(
    `SELECT p.*, u.name AS created_by_name
     FROM wholesale_payments_effective p
     JOIN users u ON u.id = p.created_by
     WHERE p.order_id = $1 AND NOT p.voided
     ORDER BY p.paid_at DESC, p.created_at DESC`, [req.params.id]);
  res.json({ items: rows });
}));

router.post('/orders/:id/payments', asyncH(async (req, res) => {
  const amount = intOrNull(req.body.amount);
  if (amount == null || amount <= 0) {
    return res.status(400).json({ error: 'Montant du règlement (entier > 0) requis.' });
  }
  const { rows: ord } = await db.query('SELECT id FROM wholesale_orders WHERE id = $1', [req.params.id]);
  if (!ord[0]) return res.status(404).json({ error: 'Commande en gros introuvable.' });

  const { rows } = await db.query(
    `INSERT INTO wholesale_payments (order_id, amount, paid_at, note, created_by)
     VALUES ($1, $2, COALESCE($3::date, CURRENT_DATE), $4, $5) RETURNING *`,
    [req.params.id, amount, dateStr(req.body.paid_at), str(req.body.note), req.user.id]);
  res.status(201).json(rows[0]);
}));

router.post('/payments/:paymentId/corrections', managerOnly, asyncH(async (req, res) => {
  const reason = str(req.body.reason);
  if (!reason) {
    return res.status(400).json({ error: 'Le motif de la correction est obligatoire.' });
  }
  const { rows: cur } = await db.query(
    'SELECT amount, voided FROM wholesale_payments_effective WHERE id = $1', [req.params.paymentId]);
  if (!cur[0]) return res.status(404).json({ error: 'Règlement introuvable.' });

  const newAmount = req.body.new_amount === undefined ? cur[0].amount : intOrNull(req.body.new_amount);
  if (newAmount == null) return res.status(400).json({ error: 'new_amount invalide.' });
  const voided = typeof req.body.voided === 'boolean' ? req.body.voided : cur[0].voided;

  const { rows } = await db.query(
    `INSERT INTO wholesale_payment_corrections (payment_id, new_amount, voided, reason, corrected_by)
     VALUES ($1, $2, $3, $4, $5) RETURNING *`,
    [req.params.paymentId, newAmount, voided, reason, req.user.id]);
  res.status(201).json(rows[0]);
}));

module.exports = router;
