const express = require('express');
const db = require('../db');
const { asyncH, intOrNull } = require('../util');

// Mounted for BOTH roles in app.js, but the secretary is confined to TAILORS
// and to piece_rate: monthly salaries (type 'autre') remain manager-only, so
// rule 1 still holds for them. staff_pay holds the CURRENT rates; every change
// is journaled into the append-only staff_pay_history in the same transaction
// (project principle: every financial change leaves a permanent trace).
const router = express.Router();

/** 404 for the secretary on anything that is not a couturier. */
async function assertSecretaryMayTouch(req, staffId) {
  if (req.user.role === 'MANAGER') return null;
  const { rows } = await db.query('SELECT type FROM staff WHERE id = $1', [staffId]);
  if (!rows[0]) return { status: 404, error: 'Employé introuvable.' };
  if (rows[0].type !== 'couturier') {
    return { status: 403, error: 'Accès refusé.' }; // monthly salary = manager only
  }
  return null;
}

router.get('/', asyncH(async (req, res) => {
  const isManager = req.user.role === 'MANAGER';
  // The secretary only ever receives couturiers, and without any salary field.
  const { rows } = await db.query(
    `SELECT s.id AS staff_id, s.full_name, s.phone, s.type, s.active,
            p.piece_rate, p.monthly_salary, p.salary_due_day
     FROM staff s LEFT JOIN staff_pay p ON p.staff_id = s.id
     WHERE ($1::boolean OR s.type = 'couturier')
     ORDER BY s.active DESC, s.full_name`, [isManager]);
  if (!isManager) {
    for (const row of rows) {
      delete row.monthly_salary;
      delete row.salary_due_day;
    }
  }
  res.json({ items: rows });
}));

router.put('/:staffId', asyncH(async (req, res) => {
  const denied = await assertSecretaryMayTouch(req, req.params.staffId);
  if (denied) return res.status(denied.status).json({ error: denied.error });
  const isManager = req.user.role === 'MANAGER';

  const pieceRate = intOrNull(req.body.piece_rate);
  // The secretary can never write salary fields — force them to "unchanged".
  const monthlySalary = isManager ? intOrNull(req.body.monthly_salary) : null;
  const salaryDueDay = isManager ? intOrNull(req.body.salary_due_day) : null;
  if (pieceRate === undefined || monthlySalary === undefined || salaryDueDay === undefined) {
    return res.status(400).json({ error: 'Montants invalides (entiers ≥ 0).' });
  }
  const updated = await db.withTransaction(async (tx) => {
    const { rows: old } = await tx.query(
      'SELECT piece_rate, monthly_salary FROM staff_pay WHERE staff_id = $1 FOR UPDATE',
      [req.params.staffId]);
    const oldPieceRate = old[0]?.piece_rate ?? null;
    const oldSalary = old[0]?.monthly_salary ?? null;

    const { rows } = await tx.query(
      `INSERT INTO staff_pay (staff_id, piece_rate, monthly_salary, salary_due_day)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (staff_id) DO UPDATE SET
         piece_rate = EXCLUDED.piece_rate,
         monthly_salary = EXCLUDED.monthly_salary,
         salary_due_day = EXCLUDED.salary_due_day
       RETURNING *`,
      [req.params.staffId, pieceRate, monthlySalary, salaryDueDay]);

    if (oldPieceRate !== pieceRate || oldSalary !== monthlySalary) {
      await tx.query(
        `INSERT INTO staff_pay_history
           (staff_id, staff_name_snapshot, old_piece_rate, new_piece_rate,
            old_monthly_salary, new_monthly_salary, changed_by)
         VALUES ($1, (SELECT full_name FROM staff WHERE id = $1),
                 $2, $3, $4, $5, $6)`,
        [req.params.staffId, oldPieceRate, pieceRate, oldSalary, monthlySalary,
          req.user.id]);
    }
    return rows[0];
  });
  if (!isManager) {
    delete updated.monthly_salary;
    delete updated.salary_due_day;
  }
  res.json(updated);
}));

// Who changed which rate, when, from → to.
router.get('/:staffId/history', asyncH(async (req, res) => {
  const denied = await assertSecretaryMayTouch(req, req.params.staffId);
  if (denied) return res.status(denied.status).json({ error: denied.error });
  const { rows } = await db.query(
    `SELECT h.*, u.name AS changed_by_name
     FROM staff_pay_history h JOIN users u ON u.id = h.changed_by
     WHERE h.staff_id = $1 ORDER BY h.changed_at DESC`, [req.params.staffId]);
  res.json({ items: rows });
}));

module.exports = router;
