const express = require('express');
const db = require('../db');
const { asyncH, intOrNull } = require('../util');

// Mounted manager-only in app.js — the secretary never reaches this file.
const router = express.Router();

router.get('/', asyncH(async (req, res) => {
  const { rows } = await db.query(
    `SELECT s.id AS staff_id, s.full_name, s.type, s.active,
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
  const { rows } = await db.query(
    `INSERT INTO staff_pay (staff_id, piece_rate, monthly_salary, salary_due_day)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT (staff_id) DO UPDATE SET
       piece_rate = EXCLUDED.piece_rate,
       monthly_salary = EXCLUDED.monthly_salary,
       salary_due_day = EXCLUDED.salary_due_day
     RETURNING *`,
    [req.params.staffId, pieceRate, monthlySalary, salaryDueDay]);
  res.json(rows[0]);
}));

module.exports = router;
