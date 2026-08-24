const express = require('express');
const db = require('../db');
const { asyncH, dateStr } = require('../util');
const { financeTotals, financeDetail, monthsTouched } = require('../finance/queries');

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

// The operations behind each KPI card, with a subtotal computed over the WHOLE
// window (not over the page the app happens to hold). The app used to fold the
// rows of paginated list endpoints itself, so a busy month printed a subtotal
// covering the first 20 orders under a card holding the true figure.
router.get('/detail', asyncH(async (req, res) => {
  const today = new Date().toISOString().slice(0, 10);
  const from = dateStr(req.query.from) || `${today.slice(0, 8)}01`;
  const to = dateStr(req.query.to) || today;

  res.json({ from, to, ...(await financeDetail(db, from, to)) });
}));

module.exports = router;
