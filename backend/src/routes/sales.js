const express = require('express');
const db = require('../db');
const { asyncH, pagination, intOrNull, str, dateStr, likeEscape } = require('../util');

const router = express.Router();

/**
 * Price one line and take it off the shelf, inside an open transaction.
 *
 * Shared by the single-item POST /api/sales and the multi-line receipt, so a
 * cart sells on exactly the same rules as a counter sale: the server reads the
 * price and the cost from the DB, stock is decremented under `FOR UPDATE` with
 * a `quantity >= qty` guard, and the purchase cost is frozen onto the row
 * (migration 024) so re-pricing an item later never rewrites past profit.
 *
 * `unit_price` from the caller is honoured (VIP discounts, owner decision
 * 2026-08-03) but the total is always computed here.
 *
 * @returns {{error?: string, status?: number, sale?: object}}
 */
async function sellOneLine(tx, { kind, itemId, qty, customPrice, userId, receiptId }) {
  if (!['produit', 'pret_a_porter'].includes(kind) || !itemId || !qty || qty < 1) {
    return { status: 400, error: 'kind, item_id et qty (≥ 1) requis.' };
  }

  let name; let price; let cost;
  if (kind === 'produit') {
    const { rows } = await tx.query(
      'SELECT name, price, cost_price, quantity FROM products WHERE id = $1 FOR UPDATE',
      [itemId]);
    if (!rows[0]) return { status: 404, error: 'Produit introuvable.' };
    if (rows[0].quantity < qty) {
      return {
        status: 409,
        error: `Stock insuffisant pour « ${rows[0].name} » (${rows[0].quantity} restant).`,
      };
    }
    await tx.query(
      'UPDATE products SET quantity = quantity - $1 WHERE id = $2', [qty, itemId]);
    ({ name, price, cost_price: cost } = rows[0]);
  } else {
    const { rows } = await tx.query(
      'SELECT name, price, cost_price FROM pret_a_porter_models WHERE id = $1', [itemId]);
    if (!rows[0]) return { status: 404, error: 'Modèle introuvable.' };
    ({ name, price, cost_price: cost } = rows[0]);
  }

  const finalPrice = (customPrice !== null && customPrice !== undefined && customPrice >= 0)
    ? customPrice : price;

  const { rows: inserted } = await tx.query(
    `INSERT INTO sales (kind, item_id, item_name, qty, unit_price, unit_cost, total,
                        created_by, receipt_id)
     VALUES ($1, $2, $3, $4::int, $5::int, $6::int, $4::int * $5::int, $7, $8)
     RETURNING *`,
    [kind, itemId, name, qty, finalPrice, cost ?? 0, userId, receiptId ?? null]);
  return { status: 201, sale: inserted[0] };
}

/**
 * Strip the purchase cost (and the margin it reveals) from sale rows.
 *
 * The secretary reads the sales history since the owner's decision of
 * 2026-08-23, but `cost_price` and everything derived from it stays
 * manager-only under rule 1 — that part of the rule was never relaxed.
 */
function withoutCost(rows) {
  return rows.map((row) => {
    const { unit_cost: _c, cost_total: _t, ...rest } = row;
    return rest;
  });
}

/**
 * Register a sale — allowed for BOTH roles (the secretary sells at the
 * counter), but the server prices everything itself:
 *   - unit_price is read from the DB row (any price/total in the request
 *     body is ignored outright);
 *   - for products, stock is decremented in the SAME transaction with a
 *     `quantity >= qty` guard → stock and revenue can never disagree.
 */
router.post('/', asyncH(async (req, res) => {
  const sale = await db.withTransaction((tx) => sellOneLine(tx, {
    kind: req.body.kind,
    itemId: req.body.item_id,
    qty: intOrNull(req.body.qty),
    customPrice: intOrNull(req.body.unit_price),
    userId: req.user.id,
  }));

  if (sale.error) return res.status(sale.status).json({ error: sale.error });
  // The secretary gets a bare confirmation from this legacy single-item route;
  // the till uses POST /receipts, which hands her the full basket back.
  if (req.user.role !== 'MANAGER') {
    return res.status(201).json({ ok: true, id: sale.sale.id });
  }
  return res.status(201).json(sale.sale);
}));

// ---------------------------------------------------------------------------
// Receipts — one trip to the till, one document (migration 026).
// ---------------------------------------------------------------------------
// A customer buying two ready-to-wear pieces, a cap, shoes, a perfume and a
// watch used to produce six unrelated sale rows, attached to nobody, with no
// way to print a single invoice. A receipt is that trip: the client (optional —
// a walk-in who gives no name still gets one) plus every line, sold in ONE
// transaction so the whole basket succeeds or none of it does.
//
// Both roles create AND read receipts (owner decision 2026-08-23): the
// secretary is the one at the counter, so she needs to find a sale she made and
// fix it. The purchase cost is stripped from everything she is sent — that half
// of rule 1 was never relaxed.

router.post('/receipts', asyncH(async (req, res) => {
  const rawLines = req.body.lines;
  if (!Array.isArray(rawLines) || rawLines.length === 0) {
    return res.status(400).json({ error: 'Ajoutez au moins un article.' });
  }
  if (rawLines.length > 100) {
    return res.status(400).json({ error: 'Trop d’articles dans une seule vente (100 max).' });
  }

  const clientId = str(req.body.client_id) || null;

  // db.withTransaction only rolls back on a THROWN error — returning an error
  // object commits whatever was written first. A basket writes as it goes
  // (stock leaves the shelf line by line), so a bad line must throw or the
  // earlier lines would be sold for real while the customer is told the sale
  // failed. This carries the HTTP status back out.
  class LineRejected extends Error {
    constructor(status, message) { super(message); this.status = status; }
  }

  let result;
  try {
    result = await db.withTransaction(async (tx) => {
      // Snapshot the client's name and phone so the receipt stays printable
      // after the client record is deleted (as orders do, migration 012).
      let snapName = str(req.body.client_name) || null;
      let snapPhone = str(req.body.client_phone) || null;
      if (clientId) {
        const { rows } = await tx.query(
          'SELECT full_name, phone FROM clients WHERE id = $1', [clientId]);
        if (!rows[0]) throw new LineRejected(404, 'Client introuvable.');
        snapName = rows[0].full_name;
        snapPhone = rows[0].phone;
      }

      // `sold_at` is the server's clock, never the caller's. Letting the
      // client name the date would let anyone at the counter move takings into
      // another period — the exact class of problem the 2026-08-23 audit was
      // about — and `sales.sold_at` already defaults to now() for the same
      // reason. A sale recorded late is corrected, not backdated.
      const { rows: head } = await tx.query(
        `INSERT INTO sale_receipts
           (client_id, client_name_snapshot, client_phone_snapshot, note, created_by)
         VALUES ($1, $2, $3, $4, $5) RETURNING *`,
        [clientId, snapName, snapPhone, str(req.body.note) || null, req.user.id]);
      const receipt = head[0];

      const lines = [];
      for (const line of rawLines) {
        const one = await sellOneLine(tx, {
          kind: line && line.kind,
          itemId: line && line.item_id,
          qty: intOrNull(line && line.qty),
          customPrice: intOrNull(line && line.unit_price),
          userId: req.user.id,
          receiptId: receipt.id,
        });
        // Any bad line aborts the WHOLE basket: the earlier lines have already
        // taken stock off the shelf, so committing here would sell goods the
        // customer was told they had not bought.
        if (one.error) throw new LineRejected(one.status, one.error);
        lines.push(one.sale);
      }
      return { receipt, lines };
    });
  } catch (err) {
    if (err instanceof LineRejected) {
      return res.status(err.status).json({ error: err.message });
    }
    throw err;
  }

  // Both roles get the finished receipt back: the secretary needs the lines and
  // the total to hand the client their invoice. That is the price the client
  // just paid in front of her, not the shop's takings.
  const total = result.lines.reduce((sum, l) => sum + Number(l.total), 0);
  res.status(201).json({
    ...result.receipt,
    total,
    items_count: result.lines.reduce((sum, l) => sum + Number(l.qty), 0),
    lines: withoutCost(result.lines),
  });
}));

router.get('/receipts', asyncH(async (req, res) => {
  const { limit, offset } = pagination(req, 50, 200);
  const from = dateStr(req.query.from);
  const to = dateStr(req.query.to);
  const clientId = str(req.query.client_id);
  const search = str(req.query.search);

  const { rows } = await db.query(
    `SELECT * FROM sale_receipts_effective
      WHERE ($1::date IS NULL OR sold_at >= $1::date)
        AND ($2::date IS NULL OR sold_at < $2::date + 1)
        AND ($3::uuid IS NULL OR client_id = $3)
        AND ($4::text IS NULL OR lower(COALESCE(client_name, '')) LIKE lower($4) || '%')
      ORDER BY sold_at DESC, created_at DESC
      LIMIT $5 OFFSET $6`,
    [from, to, clientId, likeEscape(search), limit, offset]);

  const { rows: sum } = await db.query(
    `SELECT COALESCE(SUM(total), 0)::bigint AS v, COUNT(*)::int AS n
       FROM sale_receipts_effective
      WHERE ($1::date IS NULL OR sold_at >= $1::date)
        AND ($2::date IS NULL OR sold_at < $2::date + 1)
        AND ($3::uuid IS NULL OR client_id = $3)
        AND ($4::text IS NULL OR lower(COALESCE(client_name, '')) LIKE lower($4) || '%')`,
    [from, to, clientId, likeEscape(search)]);

  res.json({
    items: rows,
    total_amount: Number(sum[0].v),
    total_count: sum[0].n,
    limit,
    offset,
  });
}));

router.get('/receipts/:id', asyncH(async (req, res) => {
  const { rows } = await db.query(
    'SELECT * FROM sale_receipts_effective WHERE id = $1', [req.params.id]);
  if (!rows[0]) return res.status(404).json({ error: 'Vente introuvable.' });

  const { rows: lines } = await db.query(
    `SELECT s.*, u.name AS seller_name
       FROM sales_effective s JOIN users u ON u.id = s.created_by
      WHERE s.receipt_id = $1 ORDER BY s.sold_at`, [req.params.id]);
  res.json({ ...rows[0], lines: withoutCost(lines) });
}));

// The flat sale list, behind the receipts view. Open to both roles since the
// owner's decision of 2026-08-23: keeping it closed while /receipts is open
// would protect nothing — it is the same rows in a different shape — and an
// inconsistent boundary is the kind a future session "fixes" in the wrong
// direction. What stays closed is the purchase cost, stripped below.
// Reads the EFFECTIVE view: latest correction wins, voided sales flagged.
router.get('/', asyncH(async (req, res) => {
  const { limit, offset } = pagination(req, 50, 200);
  const { from, to, kind } = req.query;
  const { rows } = await db.query(
    `SELECT s.*, u.name AS seller_name FROM sales_effective s
     JOIN users u ON u.id = s.created_by
     WHERE ($1::date IS NULL OR s.sold_at >= $1)
       AND ($2::date IS NULL OR s.sold_at < $2::date + 1)
       AND ($3::text IS NULL OR s.kind = $3)
     ORDER BY s.sold_at DESC LIMIT $4 OFFSET $5`,
    [from || null, to || null,
      ['produit', 'pret_a_porter'].includes(kind) ? kind : null, limit, offset]);
  res.json({ items: withoutCost(rows), limit, offset });
}));

// ---- correction log — the ONLY way to change a sale ----
// Correcting the qty or voiding a product sale puts the stock difference
// back on the shelf (or takes it) in the same transaction.
// Both roles: the secretary sells at the counter, so fixing her own mistake
// is hers too (owner decision 2026-08-23). Every correction still carries a
// mandatory reason and records `corrected_by`, so who changed what is always
// answerable — that audit trail is what the exception rests on.

router.post('/:id/corrections', asyncH(async (req, res) => {
  const reason = str(req.body.reason);
  if (!reason) {
    return res.status(400).json({ error: 'Le motif de la correction est obligatoire.' });
  }
  const result = await db.withTransaction(async (tx) => {
    const { rows: cur } = await tx.query(
      'SELECT kind, item_id, qty, voided FROM sales_effective WHERE id = $1',
      [req.params.id]);
    if (!cur[0]) return { status: 404, error: 'Vente introuvable.' };

    const newQty = req.body.new_qty === undefined
      ? cur[0].qty : intOrNull(req.body.new_qty);
    if (newQty == null || newQty < 1) {
      return { status: 400, error: 'new_qty invalide (entier ≥ 1); pour annuler, utilisez voided.' };
    }
    const voided = typeof req.body.voided === 'boolean' ? req.body.voided : cur[0].voided;

    // Units that actually left the shop, before vs after this correction.
    const outBefore = cur[0].voided ? 0 : cur[0].qty;
    const outAfter = voided ? 0 : newQty;
    const delta = outAfter - outBefore;
    if (cur[0].kind === 'produit' && delta !== 0) {
      // quantity CHECK (>= 0) turns an impossible re-out into a 400/409.
      await tx.query(
        'UPDATE products SET quantity = quantity - $1 WHERE id = $2',
        [delta, cur[0].item_id]);
    }
    const { rows } = await tx.query(
      `INSERT INTO sale_corrections (sale_id, old_qty, new_qty, voided, reason, corrected_by)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
      [req.params.id, cur[0].qty, newQty, voided, reason, req.user.id]);
    return { status: 201, body: rows[0] };
  });
  if (result.error) return res.status(result.status).json({ error: result.error });
  return res.status(result.status).json(result.body);
}));

router.get('/:id/corrections', asyncH(async (req, res) => {
  const { rows } = await db.query(
    `SELECT c.*, u.name AS corrected_by_name
     FROM sale_corrections c JOIN users u ON u.id = c.corrected_by
     WHERE c.sale_id = $1 ORDER BY c.corrected_at DESC`, [req.params.id]);
  res.json({ items: rows });
}));

module.exports = router;
