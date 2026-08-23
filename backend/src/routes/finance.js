const express = require('express');
const db = require('../db');
const { asyncH, dateStr } = require('../util');
const { financeTotals, monthsTouched } = require('../finance/queries');

// Mounted manager-only in app.js — THE financial screen's data source.
// Every figure comes from src/finance/queries.js, shared with /api/reports so
// the two screens can never disagree about the same franc.
const router = express.Router();

router.get('/summary', asyncH(async (req, res) => {
  const today = new Date().toISOString().slice(0, 10);
  const from = dateStr(req.query.from) || `${today.slice(0, 8)}01`;
  const to = dateStr(req.query.to) || today;

  const totals = await financeTotals(db, from, to);

  res.json({
    from,
    to,
    months_counted: monthsTouched(from, to),
    ...totals,
  });
}));

module.exports = router;
