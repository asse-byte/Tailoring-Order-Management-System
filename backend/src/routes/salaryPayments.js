const express = require('express');
const db = require('../db');
const { asyncH, intOrNull, str, dateStr } = require('../util');

// Mounted manager-only in app.js — a financial ledger, invisible to the
// secretary. Append-only + correction log (see 009_salary_payments.sql):
// there is no update/delete route; a mistake is corrected or voided.
const router = express.Router();

// List effective payments, optionally for one staff member and/or a year.
// The Flutter month grid asks for ?staff_id=…&year=YYYY to show Jan→Dec.
router.get('/', asyncH(async (req, res) => {
  const staffId = str(req.query.staff_id);
  const year = str(req.query.year);
  if (year && !/^\d{4}$/.test(year)) {
    return res.status(400).json({ error: 'year invalide (YYYY).' });
  }
  const { rows } = await db.query(
    `SELECT sp.*, s.full_name AS staff_name, s.type AS staff_type
     FROM salary_payments_effective sp
     JOIN staff s ON s.id = sp.staff_id
     WHERE ($1::uuid IS NULL OR sp.staff_id = $1)
       AND ($2::text IS NULL OR sp.period LIKE $2 || '%')
     ORDER BY sp.period DESC, s.full_name`,
    [staffId, year || null]);
  res.json({ items: rows });
}));

router.post('/', asyncH(async (req, res) => {
  const staffId = str(req.body.staff_id);
  const period = str(req.body.period);
  const kind = req.body.kind;
  const amount = intOrNull(req.body.amount);
  if (!staffId || !period || !['mensuel', 'hebdo'].includes(kind) || amount == null) {
    return res.status(400).json({
      error: 'staff_id, period, kind (mensuel|hebdo) et amount (entier ≥ 0) requis.',
    });
  }
  // period format guard: 'YYYY-MM' for monthly, 'YYYY-Www' for weekly.
  const okPeriod = kind === 'mensuel'
    ? /^\d{4}-\d{2}$/.test(period)
    : /^\d{4}-W\d{2}$/.test(period);
  if (!okPeriod) {
    return res.status(400).json({ error: 'Format de période invalide.' });
  }
  const { rows } = await db.query(
    `INSERT INTO salary_payments (staff_id, period, kind, amount, paid_at, note, created_by)
     VALUES ($1, $2, $3, $4, COALESCE($5::date, CURRENT_DATE), $6, $7) RETURNING *`,
    [staffId, period, kind, amount, dateStr(req.body.paid_at), str(req.body.note),
      req.user.id]);
  res.status(201).json(rows[0]);
}));

// ---- correction log (the ONLY way to change/void a payment) ----
router.post('/:id/corrections', asyncH(async (req, res) => {
  const reason = str(req.body.reason);
  if (!reason) {
    return res.status(400).json({ error: 'Le motif de la correction est obligatoire.' });
  }
  const { rows: cur } = await db.query(
    'SELECT amount, voided FROM salary_payments_effective WHERE id = $1', [req.params.id]);
  if (!cur[0]) return res.status(404).json({ error: 'Paiement introuvable.' });
  const newAmount = req.body.new_amount === undefined
    ? cur[0].amount : intOrNull(req.body.new_amount);
  if (newAmount == null) return res.status(400).json({ error: 'new_amount invalide.' });
  const voided = typeof req.body.voided === 'boolean' ? req.body.voided : cur[0].voided;
  const { rows } = await db.query(
    `INSERT INTO salary_payment_corrections (payment_id, new_amount, voided, reason, corrected_by)
     VALUES ($1, $2, $3, $4, $5) RETURNING *`,
    [req.params.id, newAmount, voided, reason, req.user.id]);
  res.status(201).json(rows[0]);
}));

router.get('/:id/corrections', asyncH(async (req, res) => {
  const { rows } = await db.query(
    `SELECT c.*, u.name AS corrected_by_name
     FROM salary_payment_corrections c JOIN users u ON u.id = c.corrected_by
     WHERE c.payment_id = $1 ORDER BY c.corrected_at DESC`, [req.params.id]);
  res.json({ items: rows });
}));

module.exports = router;
