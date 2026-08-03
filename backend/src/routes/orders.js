const express = require('express');
const db = require('../db');
const { managerOnly } = require('../middleware/auth');
const { asyncH, pagination, intOrNull, dateStr, str } = require('../util');
const whatsappService = require('../services/whatsapp');

const router = express.Router();
// Statuses a client may SET on an order. 'annule' is deliberately absent:
// cancelling goes through DELETE /orders/:id so it always records who/when/why.
const STATUSES = ['en_attente', 'en_cours', 'termine', 'livre'];
// Statuses a client may FILTER the list by — archived orders are reachable
// only by asking for them explicitly.
const LISTABLE_STATUSES = [...STATUSES, 'annule'];

// Every list/detail row carries its line items (effective view) and the
// derived total, so the client never computes money itself.
const ORDER_SELECT = `
  SELECT o.*,
         COALESCE(c.full_name, o.client_name_snapshot) AS client_name,
         c.phone AS client_phone, (c.id IS NULL) AS client_deleted,
         COALESCE(s.full_name, o.tailor_name_snapshot) AS tailor_name,
         COALESCE(o.model_media, '[]'::jsonb) AS model_media,
         COALESCE(it.total, 0) AS total,
         COALESCE(it.items, '[]') AS items
  FROM orders o
  LEFT JOIN clients c ON c.id = o.client_id
  LEFT JOIN staff s ON s.id = o.tailor_id
  LEFT JOIN LATERAL (
    SELECT SUM(line_total)::int AS total,
           json_agg(json_build_object(
             'id', id, 'garment_type', garment_type, 'quantity', quantity,
             'unit_price', unit_price, 'voided', voided,
             'corrected', corrected, 'line_total', line_total)
             ORDER BY created_at) AS items
    FROM order_items_effective WHERE order_id = o.id
  ) it ON true`;

/**
 * Lower the cash recorded against an order down to `target`, using correction
 * rows only — `order_payments` is append-only (migration 018), so rows are
 * never updated or deleted and negative amounts are rejected by CHECK.
 * Newest payments are corrected first; each correction carries the mandatory
 * reason, exactly like expense/sale corrections.
 */
async function correctCollectedDown(tx, orderId, target, userId, reason) {
  const { rows } = await tx.query(
    `SELECT id, amount FROM order_payments_effective
     WHERE order_id = $1 AND NOT voided
     ORDER BY paid_at DESC, created_at DESC`, [orderId]);

  let remaining = rows.reduce((sum, r) => sum + Number(r.amount), 0) - target;
  for (const row of rows) {
    if (remaining <= 0) break;
    const amount = Number(row.amount);
    const newAmount = Math.max(0, amount - remaining);
    remaining -= amount - newAmount;
    await tx.query(
      `INSERT INTO order_payment_corrections
         (payment_id, new_amount, voided, reason, corrected_by)
       VALUES ($1, $2, $3, $4, $5)`,
      [row.id, newAmount, newAmount === 0, reason, userId]);
  }
}

/** Validate an items array from the request → [{garment_type, quantity, unit_price}]. */
function parseItems(raw) {
  if (!Array.isArray(raw) || raw.length === 0) return null;
  const items = [];
  for (const it of raw) {
    const garment = str(it && it.garment_type);
    const qty = intOrNull(it && it.quantity);
    const price = intOrNull(it && it.unit_price);
    if (!garment || qty == null || qty < 1 || price == null) return null;
    items.push({ garment, qty, price });
  }
  return items;
}

// Historique is simply ?status=livre — the same row, moved by status.
// Scheduling (item 4): ?planned_from/?planned_to filter by the planned
// execution day (the programme); ?unplanned=1 returns the waiting queue
// (no planned_date, not yet delivered).
router.get('/', asyncH(async (req, res) => {
  const { limit, offset } = pagination(req);
  const status = LISTABLE_STATUSES.includes(req.query.status) ? req.query.status : null;
  const clientId = str(req.query.client_id);
  const from = dateStr(req.query.from);
  const to = dateStr(req.query.to);
  const plannedFrom = dateStr(req.query.planned_from);
  const plannedTo = dateStr(req.query.planned_to);
  const unplanned = ['1', 'true', 'yes'].includes(String(req.query.unplanned));
  const { rows } = await db.query(
    `${ORDER_SELECT}
     WHERE ($1::text IS NULL OR o.status = $1)
       -- Cancelled orders are archived: never in the active list or in
       -- Historique unless explicitly asked for with ?status=annule.
       AND ($1::text = 'annule' OR o.status <> 'annule')
       AND ($2::uuid IS NULL OR o.client_id = $2)
       AND ($3::date IS NULL OR COALESCE(o.delivered_date, o.created_at::date) >= $3)
       AND ($4::date IS NULL OR COALESCE(o.delivered_date, o.created_at::date) <= $4)
       AND ($5::date IS NULL OR o.planned_date >= $5)
       AND ($6::date IS NULL OR o.planned_date <= $6)
       AND ($7::boolean IS NOT TRUE OR (o.planned_date IS NULL AND o.status <> 'livre'))
     ORDER BY CASE WHEN o.status = 'livre' THEN o.delivered_date END DESC,
              o.planned_date ASC NULLS LAST,
              o.created_at DESC
     LIMIT $8 OFFSET $9`,
    [status, clientId, from, to, plannedFrom, plannedTo, unplanned, limit, offset]);
  res.json({ items: rows, limit, offset });
}));

router.post('/', asyncH(async (req, res) => {
  const clientId = str(req.body.client_id);
  const items = parseItems(req.body.items);
  const advance = intOrNull(req.body.advance) ?? 0;
  const tailorId = str(req.body.tailor_id);
  const status = req.body.status;
  if (!clientId || !items) {
    return res.status(400).json({
      error: 'client_id et au moins un article (garment_type, quantity ≥ 1, unit_price) requis.',
    });
  }
  if (advance === undefined) return res.status(400).json({ error: 'Avance invalide.' });
  if (status !== undefined && !STATUSES.includes(status)) {
    return res.status(400).json({ error: `status doit être: ${STATUSES.join(', ')}.` });
  }

  // Freeze the client's measurements into the order (reference at cut time).
  let snapshot = req.body.measurements_snapshot;
  if (typeof snapshot !== 'object' || snapshot === null) {
    const { rows: m } = await db.query(
      'SELECT garment_type, measures FROM client_measurements WHERE client_id = $1',
      [clientId]);
    snapshot = Object.fromEntries(m.map((r) => [r.garment_type, r.measures]));
  }

  let modelMedia = req.body.model_media;
  if (!Array.isArray(modelMedia)) modelMedia = [];

  const order = await db.withTransaction(async (tx) => {
    // Snapshot client + tailor names so a delivered order stays complete in
    // Historique even after the client or tailor is deleted (FKs are ON DELETE
    // SET NULL — see migration 012).
    const { rows } = await tx.query(
      `INSERT INTO orders (client_id, tailor_id, client_name_snapshot,
                           tailor_name_snapshot, garment_type, fabric,
                           measurements_snapshot, price, advance,
                           start_date, expected_date, status, notes, model_media)
       VALUES ($1, $2, (SELECT full_name FROM clients WHERE id = $1),
               (SELECT full_name FROM staff WHERE id = $2),
               $3, $4, $5, 0, $6,
               COALESCE($7::date, CURRENT_DATE), $8::date,
               COALESCE($9, 'en_attente'), $10, $11)
       RETURNING id`,
      [clientId, tailorId, items[0].garment, str(req.body.fabric) || '',
        JSON.stringify(snapshot), advance, dateStr(req.body.start_date),
        dateStr(req.body.expected_date), status || null, str(req.body.notes),
        JSON.stringify(modelMedia)]);
    const orderId = rows[0].id;
    for (const it of items) {
      await tx.query(
        `INSERT INTO order_items (order_id, garment_type, quantity, unit_price)
         VALUES ($1, $2, $3, $4)`,
        [orderId, it.garment, it.qty, it.price]);
    }

    if (advance > 0) {
      await tx.query(
        `INSERT INTO order_payments (order_id, amount, paid_at, note)
         VALUES ($1, $2, CURRENT_DATE, 'Acompte initial')`,
        [orderId, advance]);
    }
    return orderId;
  });

  const { rows } = await db.query(`${ORDER_SELECT} WHERE o.id = $1`, [order]);
  res.status(201).json(rows[0]);
}));

router.get('/:id', asyncH(async (req, res) => {
  const { rows } = await db.query(`${ORDER_SELECT} WHERE o.id = $1`, [req.params.id]);
  if (!rows[0]) return res.status(404).json({ error: 'Commande introuvable.' });
  res.json(rows[0]);
}));

// Header update only: status, tailor, dates, advance, fabric, notes. The
// financial line items are changed through their own append-only endpoints.
router.put('/:id', asyncH(async (req, res) => {
  const status = req.body.status;
  if (status !== undefined && !STATUSES.includes(status)) {
    return res.status(400).json({ error: `status doit être: ${STATUSES.join(', ')}.` });
  }
  const advance = req.body.advance === undefined ? null : intOrNull(req.body.advance);
  if (advance === undefined) return res.status(400).json({ error: 'Avance invalide.' });

  const orderId = req.params.id;
  let modelMedia = req.body.model_media;
  if (modelMedia !== undefined && !Array.isArray(modelMedia)) modelMedia = null;

  const full = await db.withTransaction(async (tx) => {
    const { rows: cur } = await tx.query('SELECT advance, status FROM orders WHERE id = $1', [orderId]);
    if (!cur[0]) return null;
    const oldAdvance = Number(cur[0].advance) || 0;

    const { rows: updated } = await tx.query(
      `UPDATE orders SET
         tailor_id      = COALESCE($1::uuid, tailor_id),
         tailor_name_snapshot = CASE WHEN $1::uuid IS NOT NULL
           THEN (SELECT full_name FROM staff WHERE id = $1::uuid)
           ELSE tailor_name_snapshot END,
         fabric         = COALESCE($2, fabric),
         advance        = COALESCE($3, advance),
         expected_date  = COALESCE($4::date, expected_date),
         notes          = COALESCE($5, notes),
         status         = COALESCE($6, status),
         model_media    = COALESCE($7::jsonb, model_media),
         delivered_date = CASE
           WHEN $6 = 'livre' AND status <> 'livre' THEN CURRENT_DATE
           WHEN $6 IS NOT NULL AND $6 <> 'livre' THEN NULL
           ELSE delivered_date END
       WHERE id = $8 RETURNING id`,
      [str(req.body.tailor_id), str(req.body.fabric), advance,
        dateStr(req.body.expected_date), str(req.body.notes),
        status || null, modelMedia ? JSON.stringify(modelMedia) : null, orderId]);
    if (!updated[0]) return null;

    // Cash collected is append-only (migration 018): a raised advance is a NEW
    // payment row, a lowered one is a CORRECTION of the rows already recorded —
    // never a negative counter-row, which the CHECK now rejects anyway.
    if (advance !== null && advance !== oldAdvance) {
      const diff = advance - oldAdvance;
      if (diff > 0) {
        await tx.query(
          `INSERT INTO order_payments (order_id, amount, paid_at, note)
           VALUES ($1, $2, CURRENT_DATE, 'Règlement / Acompte')`,
          [orderId, diff]);
      } else {
        await correctCollectedDown(tx, orderId, advance, req.user.id,
          'Acompte corrigé à la baisse depuis la fiche commande.');
      }
    }

    // Delivery collects the remaining balance. Without this the cash-basis
    // revenue introduced in migration 016 never saw a delivered order that was
    // paid in full at hand-over: the money was collected but no payment row
    // existed, so tailoring revenue stayed at 0 for shops that take no advance.
    if (status === 'livre' && cur[0].status !== 'livre') {
      const { rows: bal } = await tx.query(
        `SELECT COALESCE(it.total, 0)::int AS total,
                COALESCE(pay.paid, 0)::int AS paid
         FROM orders o
         LEFT JOIN LATERAL (
           SELECT SUM(line_total)::int AS total FROM order_items_effective
           WHERE order_id = o.id
         ) it ON true
         LEFT JOIN LATERAL (
           SELECT SUM(amount)::int AS paid FROM order_payments_effective
           WHERE order_id = o.id AND NOT voided
         ) pay ON true
         WHERE o.id = $1`, [orderId]);
      const reste = (bal[0]?.total || 0) - (bal[0]?.paid || 0);
      if (reste > 0) {
        await tx.query(
          `INSERT INTO order_payments (order_id, amount, paid_at, note)
           VALUES ($1, $2, CURRENT_DATE, 'Solde encaissé à la livraison')`,
          [orderId, reste]);
      }
    }

    const { rows: resRows } = await tx.query(`${ORDER_SELECT} WHERE o.id = $1`, [orderId]);
    return resRows[0];
  });

  if (!full) return res.status(404).json({ error: 'Commande introuvable.' });

  // Best-effort notification. It only actually sends when a WhatsApp provider
  // is configured (see services/whatsapp.js); otherwise it is a no-op and the
  // shop notifies the client with the wa.me button on the order screen.
  if (status === 'termine') {
    whatsappService.sendOrderReadyMessage(full).then((r) => {
      if (!r.sent && r.reason === 'provider_error') {
        console.error('[WhatsApp] envoi échoué:', r.error);
      }
    }).catch((err) => console.error('[WhatsApp] erreur inattendue:', err.message));
  }

  res.json(full);
}));

// Assign (or clear) the planned execution day — the programme. Send
// planned_date: null to move the order back to the waiting queue. Both roles
// (operational scheduling, not financial).
router.put('/:id/plan', asyncH(async (req, res) => {
  const raw = req.body.planned_date;
  let planned = null;
  if (raw !== null && raw !== undefined && raw !== '') {
    planned = dateStr(raw);
    if (!planned) {
      return res.status(400).json({ error: 'planned_date invalide (YYYY-MM-DD) ou null.' });
    }
  }
  const { rows } = await db.query(
    'UPDATE orders SET planned_date = $1::date WHERE id = $2 RETURNING id',
    [planned, req.params.id]);
  if (!rows[0]) return res.status(404).json({ error: 'Commande introuvable.' });
  const { rows: full } = await db.query(`${ORDER_SELECT} WHERE o.id = $1`, [req.params.id]);
  res.json(full[0]);
}));

// Add a new line to an existing order (append-only insert).
router.post('/:id/items', asyncH(async (req, res) => {
  const garment = str(req.body.garment_type);
  const qty = intOrNull(req.body.quantity);
  const price = intOrNull(req.body.unit_price);
  if (!garment || qty == null || qty < 1 || price == null) {
    return res.status(400).json({ error: 'garment_type, quantity (≥ 1) et unit_price requis.' });
  }
  const { rows: ord } = await db.query('SELECT id FROM orders WHERE id = $1', [req.params.id]);
  if (!ord[0]) return res.status(404).json({ error: 'Commande introuvable.' });
  await db.query(
    `INSERT INTO order_items (order_id, garment_type, quantity, unit_price)
     VALUES ($1, $2, $3, $4)`,
    [req.params.id, garment, qty, price]);
  const { rows } = await db.query(`${ORDER_SELECT} WHERE o.id = $1`, [req.params.id]);
  res.status(201).json(rows[0]);
}));

// Correct or void a line — the ONLY way to change a quantity/price after the
// fact. Mandatory reason; a new correction row, never an in-place edit.
router.post('/:id/items/:itemId/corrections', asyncH(async (req, res) => {
  const reason = str(req.body.reason);
  if (!reason) {
    return res.status(400).json({ error: 'Le motif de la correction est obligatoire.' });
  }
  const { rows: cur } = await db.query(
    `SELECT quantity, unit_price, voided FROM order_items_effective
     WHERE id = $1 AND order_id = $2`, [req.params.itemId, req.params.id]);
  if (!cur[0]) return res.status(404).json({ error: 'Article introuvable.' });

  const newQty = req.body.new_quantity === undefined
    ? cur[0].quantity : intOrNull(req.body.new_quantity);
  const newPrice = req.body.new_unit_price === undefined
    ? cur[0].unit_price : intOrNull(req.body.new_unit_price);
  if (newQty == null || newQty < 1 || newPrice == null) {
    return res.status(400).json({ error: 'new_quantity (≥ 1) et new_unit_price (≥ 0) invalides.' });
  }
  const voided = typeof req.body.voided === 'boolean' ? req.body.voided : cur[0].voided;

  await db.query(
    `INSERT INTO order_item_corrections
       (order_item_id, new_quantity, new_unit_price, voided, reason, corrected_by)
     VALUES ($1, $2, $3, $4, $5, $6)`,
    [req.params.itemId, newQty, newPrice, voided, reason, req.user.id]);
  const { rows } = await db.query(`${ORDER_SELECT} WHERE o.id = $1`, [req.params.id]);
  res.status(201).json(rows[0]);
}));

// Full history of a line: who changed what, when, and why.
router.get('/:id/items/:itemId/corrections', asyncH(async (req, res) => {
  const { rows } = await db.query(
    `SELECT c.*, u.name AS corrected_by_name
     FROM order_item_corrections c JOIN users u ON u.id = c.corrected_by
     WHERE c.order_item_id = $1 ORDER BY c.corrected_at DESC`, [req.params.itemId]);
  res.json({ items: rows });
}));

// Cancel (archive) an order — manager only. An order always carries
// append-only order_items, so it is NEVER hard-deleted: cancelling is a status
// change (migration 019), exactly like delivering moves it to Historique. The
// line items, their corrections, the cash already collected and the tailor's
// daily entries are all preserved untouched.
//
// Cash already collected stays counted as revenue on the day it came in — the
// shop really did receive it. If the client is reimbursed, the manager voids
// the payment through its correction endpoint, with a reason, like every other
// financial change in this project.
router.delete('/:id', managerOnly, asyncH(async (req, res) => {
  const orderId = req.params.id;
  const reason = str(req.body && req.body.reason) || null;

  const { rows } = await db.query(
    `UPDATE orders
        SET status = 'annule', cancelled_at = now(), cancel_reason = $2
      WHERE id = $1 AND status <> 'annule'
      RETURNING id`, [orderId, reason]);

  if (!rows[0]) {
    const { rows: exists } = await db.query('SELECT status FROM orders WHERE id = $1', [orderId]);
    if (!exists[0]) return res.status(404).json({ error: 'Commande introuvable.' });
    return res.status(409).json({ error: 'Commande déjà annulée.' });
  }
  res.status(204).end();
}));

module.exports = router;
