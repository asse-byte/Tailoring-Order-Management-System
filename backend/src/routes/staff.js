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

module.exports = router;
