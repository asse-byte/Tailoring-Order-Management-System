const express = require('express');
const db = require('../db');
const { managerOnly } = require('../middleware/auth');
const { asyncH, str } = require('../util');

const router = express.Router();

// Contact info only — safe for the secretary (she coordinates with staff
// daily). Pay data lives behind /api/staff-pay, manager-only.
router.get('/', asyncH(async (req, res) => {
  const { rows } = await db.query(
    `SELECT id, full_name, phone, type, joined_at, active
     FROM staff ORDER BY active DESC, full_name`);
  res.json({ items: rows });
}));

router.post('/', managerOnly, asyncH(async (req, res) => {
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

router.put('/:id', managerOnly, asyncH(async (req, res) => {
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

// Staff with wage history cannot be hard-deleted (FK RESTRICT on
// tailor_daily_entries) — deactivate instead; the error handler maps the
// FK violation to a 409 with that hint.
router.delete('/:id', managerOnly, asyncH(async (req, res) => {
  const { rowCount } = await db.query('DELETE FROM staff WHERE id = $1', [req.params.id]);
  if (!rowCount) return res.status(404).json({ error: 'Employé introuvable.' });
  res.status(204).end();
}));

module.exports = router;
