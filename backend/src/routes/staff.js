const express = require('express');
const db = require('../db');
const { asyncH, str } = require('../util');

const router = express.Router();

// The staff roster (name, phone, type, active) carries NO financial data — pay
// lives behind /api/staff-pay and wages behind /api/tailor-entries, both
// manager-only. So both roles may fully manage the roster (create/edit/delete);
// the secretary still never reaches any rate/wage/salary. See CLAUDE.md rule 1.
router.get('/', asyncH(async (req, res) => {
  const { rows } = await db.query(
    `SELECT id, full_name, phone, type, joined_at, active
     FROM staff ORDER BY active DESC, full_name`);
  res.json({ items: rows });
}));

router.post('/', asyncH(async (req, res) => {
  const fullName = str(req.body.full_name);
  if (!fullName || !['couturier', 'autre'].includes(req.body.type)) {
    return res.status(400).json({ error: 'Nom et type (couturier|autre) requis.' });
  }
  const { rows } = await db.query(
    `INSERT INTO staff (full_name, phone, type, joined_at)
     VALUES ($1, $2, $3, COALESCE($4::date, CURRENT_DATE)) RETURNING *`,
    [fullName, str(req.body.phone) || '', req.body.type, req.body.joined_at || null]);
  res.status(201).json(rows[0]);
}));

router.put('/:id', asyncH(async (req, res) => {
  const fullName = str(req.body.full_name);
  if (!fullName || !['couturier', 'autre'].includes(req.body.type)) {
    return res.status(400).json({ error: 'Champs invalides.' });
  }
  const { rows } = await db.query(
    `UPDATE staff SET full_name = $1, phone = $2, type = $3,
       active = COALESCE($4, active)
     WHERE id = $5 RETURNING *`,
    [fullName, str(req.body.phone) || '', req.body.type,
      typeof req.body.active === 'boolean' ? req.body.active : null, req.params.id]);
  if (!rows[0]) return res.status(404).json({ error: 'Employé introuvable.' });
  res.json(rows[0]);
}));

// Full hard-delete (both roles — roster management, no financial data). Since
// migration 012 the financial history (tailor_daily_entries, staff_pay_history,
// salary_payments) keeps a name snapshot and no FK to staff, so wage totals are
// unaffected; staff_pay cascades away and orders.tailor_id is set null (the
// order keeps its tailor name snapshot). Deactivating (active=false) via PUT
// remains available too.
router.delete('/:id', asyncH(async (req, res) => {
  const { rowCount } = await db.query('DELETE FROM staff WHERE id = $1', [req.params.id]);
  if (!rowCount) return res.status(404).json({ error: 'Employé introuvable.' });
  res.status(204).end();
}));

// ---------------------------------------------------------------------------
// All-time performance + settlement sheet for ONE staff member.
//
// Financial isolation (CLAUDE.md rules 1 & 2), mirroring staffPay.js exactly:
//   - MANAGER: everything, including salary payments and the net balance.
//   - SECRETARY: couturiers ONLY, and only the piece-work side (pieces, amounts,
//     per-garment breakdown) — which the owner deliberately opened to her on
//     2026-07-20. Salary payments stay manager-only, so they are stripped from
//     her response, and any non-couturier returns 403.
//
// Every figure reads the append-only *_effective views, so corrected and voided
// rows are respected (a voided entry contributes 0 pieces and 0 francs).
// ---------------------------------------------------------------------------
router.get('/:id/all-time-summary', asyncH(async (req, res) => {
  const staffId = req.params.id;
  const { rows: staffRows } = await db.query(
    'SELECT id, full_name, phone, type, active, joined_at FROM staff WHERE id = $1',
    [staffId]);
  if (!staffRows[0]) return res.status(404).json({ error: 'Employé introuvable.' });
  const staff = staffRows[0];

  const isManager = req.user.role === 'MANAGER';
  if (!isManager && staff.type !== 'couturier') {
    // Monthly employees are a salary surface — manager only.
    return res.status(403).json({ error: 'Accès refusé.' });
  }

  const [totals, byGarment, paid] = await Promise.all([
    db.query(
      `SELECT COALESCE(SUM(pieces_count), 0)::int      AS pieces_total,
              COALESCE(SUM(amount), 0)::bigint         AS earned_total,
              COUNT(DISTINCT entry_date)::int          AS days_worked,
              MIN(entry_date)                          AS first_entry_date,
              MAX(entry_date)                          AS last_entry_date
       FROM tailor_entries_effective WHERE tailor_id = $1`, [staffId]),
    db.query(
      `SELECT COALESCE(NULLIF(garment_type, ''), 'Non précisé') AS garment_type,
              COALESCE(SUM(pieces_count), 0)::int  AS pieces,
              COALESCE(SUM(amount), 0)::bigint     AS amount
       FROM tailor_entries_effective
       WHERE tailor_id = $1
       GROUP BY 1
       HAVING SUM(pieces_count) > 0
       ORDER BY amount DESC, 1`, [staffId]),
    db.query(
      `SELECT COALESCE(SUM(amount), 0)::bigint AS v, COUNT(*)::int AS n
       FROM salary_payments_effective
       WHERE staff_id = $1 AND NOT voided`, [staffId]),
  ]);

  const earnedTotal = Number(totals.rows[0].earned_total);
  const body = {
    staff: {
      id: staff.id,
      full_name: staff.full_name,
      phone: staff.phone,
      type: staff.type,
      active: staff.active,
      joined_at: staff.joined_at,
    },
    pieces_total: totals.rows[0].pieces_total,
    earned_total: earnedTotal,
    days_worked: totals.rows[0].days_worked,
    first_entry_date: totals.rows[0].first_entry_date,
    last_entry_date: totals.rows[0].last_entry_date,
    by_garment: byGarment.rows.map((r) => ({
      garment_type: r.garment_type,
      pieces: r.pieces,
      amount: Number(r.amount),
    })),
  };

  if (isManager) {
    const paidTotal = Number(paid.rows[0].v);
    body.salary_paid_total = paidTotal;
    body.salary_payments_count = paid.rows[0].n;
    // Only meaningful for piece-rate tailors: what the shop still owes (positive)
    // or has paid ahead (negative). A monthly employee earns no piece-work, so
    // the difference would be a meaningless negative — return null instead of a
    // number the manager might act on.
    body.net_balance = staff.type === 'couturier' ? earnedTotal - paidTotal : null;
  }

  return res.json(body);
}));

module.exports = router;
