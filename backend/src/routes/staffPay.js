const express = require('express');
const db = require('../db');
const { asyncH, intOrNull } = require('../util');

// Mounted manager-only in app.js — the secretary never reaches this file.
// staff_pay holds the CURRENT rates; every change is journaled into the
// append-only staff_pay_history in the same transaction (project principle:
// every financial change leaves a permanent trace).
const router = express.Router();

router.get('/', asyncH(async (req, res) => {
  const { rows } = await db.query(
    `SELECT s.id AS staff_id, s.full_name, s.phone, s.type, s.active,
            p.piece_rate, p.monthly_salary, p.salary_due_day
     FROM staff s LEFT JOIN staff_pay p ON p.staff_id = s.id
     ORDER BY s.active DESC, s.full_name`);
  res.json({ items: rows });
}));

router.put('/:staffId', asyncH(async (req, res) => {
  const pieceRate = intOrNull(req.body.piece_rate);
  const monthlySalary = intOrNull(req.body.monthly_salary);
  const salaryDueDay = intOrNull(req.body.salary_due_day);
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
           (staff_id, old_piece_rate, new_piece_rate,
            old_monthly_salary, new_monthly_salary, changed_by)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [req.params.staffId, oldPieceRate, pieceRate, oldSalary, monthlySalary,
          req.user.id]);
    }
    return rows[0];
  });
  res.json(updated);
}));

// Who changed which rate, when, from → to.
router.get('/:staffId/history', asyncH(async (req, res) => {
  const { rows } = await db.query(
    `SELECT h.*, u.name AS changed_by_name
     FROM staff_pay_history h JOIN users u ON u.id = h.changed_by
     WHERE h.staff_id = $1 ORDER BY h.changed_at DESC`, [req.params.staffId]);
  res.json({ items: rows });
}));

module.exports = router;
