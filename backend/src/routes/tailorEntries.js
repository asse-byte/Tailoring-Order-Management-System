const express = require('express');
const db = require('../db');
const { asyncH, intOrNull, dateStr, isoWeekId, str } = require('../util');

// Mounted for BOTH roles in app.js (owner decision 2026-07-20: piece prices
// vary per garment, so the secretary sets them while assigning the work).
// The tables behind this router are
// APPEND-ONLY at the database level: there is no update/delete route here,
// and even direct SQL raises an exception (trigger). Mistakes are fixed by
// POSTing a correction with a mandatory reason — the audit trail is total.
const router = express.Router();

router.post('/', asyncH(async (req, res) => {
  const piecesCount = intOrNull(req.body.pieces_count);
  const entryDate = dateStr(req.body.entry_date);
  const tailorId = req.body.tailor_id;
  // Optional per-entry rate: a tailor may sew different garment types at
  // different prices, so the manager can type the rate for THIS entry.
  const bodyRate = intOrNull(req.body.piece_rate);
  if (bodyRate === undefined) {
    return res.status(400).json({ error: 'piece_rate invalide (entier ≥ 0).' });
  }
  if (!tailorId || piecesCount == null || !entryDate) {
    return res.status(400).json({ error: 'tailor_id, entry_date et pieces_count requis.' });
  }
  // Rate priority: explicit per-entry rate → the tailor's own rate.
  // The shop-wide default was removed on the owner's instruction (migration
  // 027): it was seeded at 0 and a rate of 0 is rejected below, so it never
  // actually fired, and a wage silently falling back to a number nobody
  // remembers setting is worse than being told to set one.
  // The chosen rate is snapshotted on the row, so later rate changes never
  // rewrite past wages.
  let rate = bodyRate;
  if (rate == null) {
    const { rows: rateRows } = await db.query(
      'SELECT piece_rate AS rate FROM staff_pay WHERE staff_id = $1', [tailorId]);
    rate = rateRows[0] ? rateRows[0].rate : null;
  }
  if (rate == null || rate <= 0) {
    return res.status(400).json({
      error: 'Ce couturier n’a pas de prix par pièce. Indiquez-le d’abord.',
    });
  }
  // Optional descriptive fields (item 6). When an order is linked the client
  // name is derived from it at read time — never re-typed here.
  const garmentType = str(req.body.garment_type);
  const orderId = str(req.body.order_id);
  const customClientName = str(req.body.custom_client_name);
  // Snapshot the tailor's name onto the row so the wage history survives even
  // if the tailor is later deleted (there is no FK any more — see migration 012).
  const { rows } = await db.query(
    `INSERT INTO tailor_daily_entries
       (tailor_id, tailor_name_snapshot, entry_date, pieces_count, piece_rate,
        week_id, created_by, garment_type, order_id, custom_client_name)
     VALUES ($1, (SELECT full_name FROM staff WHERE id = $1),
             $2, $3, $4, $5, $6, $7, $8::uuid, $9) RETURNING *`,
    [tailorId, entryDate, piecesCount, rate, isoWeekId(entryDate), req.user.id,
      garmentType, orderId, customClientName]);
  res.status(201).json(rows[0]);
}));

// Effective values (latest correction wins) — used by every list & total.
router.get('/', asyncH(async (req, res) => {
  const weekId = str(req.query.week_id);
  const tailorId = str(req.query.tailor_id);
  const from = dateStr(req.query.from);
  const to = dateStr(req.query.to);
  const { rows } = await db.query(
    `SELECT e.*, COALESCE(s.full_name, e.tailor_name_snapshot) AS tailor_name,
            (s.id IS NULL) AS tailor_deleted,
            COALESCE(c.full_name, o.client_name_snapshot) AS client_name
     FROM tailor_entries_effective e
     LEFT JOIN staff s ON s.id = e.tailor_id
     LEFT JOIN orders o ON o.id = e.order_id
     LEFT JOIN clients c ON c.id = o.client_id
     WHERE ($1::text IS NULL OR e.week_id = $1)
       AND ($2::uuid IS NULL OR e.tailor_id = $2)
       AND ($3::date IS NULL OR e.entry_date >= $3)
       AND ($4::date IS NULL OR e.entry_date <= $4)
     ORDER BY e.entry_date DESC, e.created_at DESC LIMIT 500`,
    [weekId, tailorId, from, to]);
  res.json({ items: rows });
}));

// Detailed week for ONE tailor: every entry (garment type, pieces, client,
// amount) so the UI can group Monday→Sunday. Both roles (manager + secretary).
router.get('/weekly-detail', asyncH(async (req, res) => {
  const weekId = str(req.query.week_id);
  const tailorId = str(req.query.tailor_id);
  if (!weekId || !tailorId) {
    return res.status(400).json({ error: 'week_id et tailor_id requis.' });
  }
  const { rows } = await db.query(
    `SELECT e.id, e.entry_date, e.garment_type, e.pieces_count, e.piece_rate,
            e.amount, e.order_id, e.corrected, e.voided, e.client_name,
            e.corrected_by, e.corrected_by_name, e.corrected_at, e.correction_reason
     FROM tailor_entries_effective e
     WHERE e.week_id = $1 AND e.tailor_id = $2
     ORDER BY e.entry_date, e.created_at`, [weekId, tailorId]);
  const total = rows.reduce((s, r) => s + Number(r.amount), 0);
  res.json({ week_id: weekId, tailor_id: tailorId, items: rows, total });
}));

// Monthly totals per tailor, ranked highest-first — so the manager can see at
// a glance who sewed the most this month (e.g. to reward the top worker).
router.get('/monthly', asyncH(async (req, res) => {
  const month = str(req.query.month);
  if (!month || !/^\d{4}-\d{2}$/.test(month)) {
    return res.status(400).json({ error: 'month requis au format YYYY-MM.' });
  }
  const firstDay = `${month}-01`;
  const { rows } = await db.query(
    `SELECT e.tailor_id,
            COALESCE(s.full_name, MAX(e.tailor_name_snapshot)) AS tailor_name,
            COALESCE(s.active, false) AS active, (s.id IS NULL) AS tailor_deleted,
            SUM(e.pieces_count)::int AS pieces_total,
            SUM(e.amount)::int       AS amount_total,
            COUNT(DISTINCT e.entry_date)::int AS days_worked
     FROM tailor_entries_effective e LEFT JOIN staff s ON s.id = e.tailor_id
     WHERE e.entry_date >= $1::date
       AND e.entry_date <  ($1::date + INTERVAL '1 month')
     GROUP BY e.tailor_id, s.full_name, s.active, s.id
     ORDER BY amount_total DESC, tailor_name`, [firstDay]);
  res.json({ month, items: rows });
}));

// Weekly totals per tailor — what gets paid every week.
router.get('/weekly', asyncH(async (req, res) => {
  const weekId = str(req.query.week_id);
  if (!weekId) return res.status(400).json({ error: 'week_id requis (ex: 2026-W27).' });
  const { rows } = await db.query(
    `SELECT e.tailor_id,
            COALESCE(s.full_name, MAX(e.tailor_name_snapshot)) AS tailor_name,
            (s.id IS NULL) AS tailor_deleted,
            SUM(e.pieces_count)::int AS pieces_total,
            SUM(e.amount)::int AS amount_total,
            COUNT(*)::int AS days_worked
     FROM tailor_entries_effective e LEFT JOIN staff s ON s.id = e.tailor_id
     WHERE e.week_id = $1
     GROUP BY e.tailor_id, s.full_name, s.id ORDER BY tailor_name`, [weekId]);
  res.json({ week_id: weekId, items: rows });
}));

// ---- correction log (the ONLY way to change a number) ----

// A correction may change the quantity, the garment type (model) and/or the
// price-per-piece (which drives the montant), or VOID the entry (counts 0).
// Any omitted field keeps its current effective value. Mandatory reason; a new
// append-only row — never an in-place edit. Amount stays pieces × rate.
router.post('/:id/corrections', asyncH(async (req, res) => {
  const reason = str(req.body.reason);
  if (!reason) {
    return res.status(400).json({ error: 'Le motif de la correction est obligatoire.' });
  }
  // Snapshot the currently-effective values as the correction baseline.
  const { rows: current } = await db.query(
    `SELECT pieces_count, piece_rate, garment_type, client_name, order_id
     FROM tailor_entries_effective WHERE id = $1`, [req.params.id]);
  if (!current[0]) return res.status(404).json({ error: 'Saisie introuvable.' });

  const voided = typeof req.body.voided === 'boolean' ? req.body.voided : false;
  const newPieces = req.body.new_pieces === undefined
    ? current[0].pieces_count : intOrNull(req.body.new_pieces);
  const newRate = req.body.new_piece_rate === undefined
    ? current[0].piece_rate : intOrNull(req.body.new_piece_rate);
  const newGarment = req.body.new_garment_type === undefined
    ? current[0].garment_type : str(req.body.new_garment_type);
  const newClientName = req.body.new_custom_client_name === undefined
    ? current[0].client_name : str(req.body.new_custom_client_name);
  const newOrderId = req.body.new_order_id === undefined
    ? current[0].order_id : (req.body.new_order_id ? str(req.body.new_order_id) : null);
  if (newPieces == null || newPieces === undefined) {
    return res.status(400).json({ error: 'new_pieces invalide (entier ≥ 0).' });
  }
  if (newRate == null || newRate === undefined) {
    return res.status(400).json({ error: 'new_piece_rate invalide (entier ≥ 0).' });
  }
  const { rows } = await db.query(
    `INSERT INTO entry_corrections
       (entry_id, old_pieces, new_pieces, new_piece_rate, new_garment_type,
        new_custom_client_name, new_order_id, voided, reason, corrected_by)
     VALUES ($1, $2, $3, $4, $5, $6, $7::uuid, $8, $9, $10) RETURNING *`,
    [req.params.id, current[0].pieces_count, newPieces, newRate, newGarment,
      newClientName, newOrderId, voided, reason, req.user.id]);
  res.status(201).json(rows[0]);
}));

// Full history: who changed what, when, from → to, and why.
//
// This is the shop owner's evidence when a tailor disputes their pay, so each
// row carries the PREVIOUS value of every field, not just the pieces count.
// `entry_corrections` only stores the new values (plus the legacy old_pieces),
// so the "from" side of a change is the previous correction in the chain — or
// the original entry, for the first one. Walk the chain oldest-first to
// resolve it, then hand it back newest-first for display.
router.get('/:id/corrections', asyncH(async (req, res) => {
  const { rows: origin } = await db.query(
    `SELECT pieces_count, piece_rate, garment_type
     FROM tailor_daily_entries WHERE id = $1`, [req.params.id]);
  if (!origin[0]) return res.status(404).json({ error: 'Saisie introuvable.' });

  const { rows } = await db.query(
    `SELECT c.*, u.name AS corrected_by_name, u.username AS corrected_by_username
     FROM entry_corrections c JOIN users u ON u.id = c.corrected_by
     WHERE c.entry_id = $1
     ORDER BY c.corrected_at ASC, c.id ASC`, [req.params.id]);

  let prev = {
    pieces_count: origin[0].pieces_count,
    piece_rate: origin[0].piece_rate,
    garment_type: origin[0].garment_type,
    voided: false,
  };
  const items = rows.map((c) => {
    // A correction only carries the fields it changed; everything else keeps
    // the value it had, which is what makes "from → to" readable at all.
    const next = {
      pieces_count: c.new_pieces,
      piece_rate: c.new_piece_rate ?? prev.piece_rate,
      garment_type: c.new_garment_type ?? prev.garment_type,
      voided: c.voided,
    };
    const item = {
      ...c,
      old_pieces: prev.pieces_count,
      old_piece_rate: prev.piece_rate,
      old_garment_type: prev.garment_type,
      new_piece_rate: next.piece_rate,
      new_garment_type: next.garment_type,
      old_amount: prev.voided ? 0 : prev.pieces_count * prev.piece_rate,
      new_amount: next.voided ? 0 : next.pieces_count * next.piece_rate,
    };
    prev = next;
    return item;
  });

  res.json({ items: items.reverse() });
}));

module.exports = router;
