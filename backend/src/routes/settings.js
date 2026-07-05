const express = require('express');
const db = require('../db');
const { asyncH, intOrNull, str } = require('../util');

// GET /public has NO auth (mounted before authenticate in app.js): the
// login screen shows the shop name + logo before anyone signs in.
const publicRouter = express.Router();

publicRouter.get('/', asyncH(async (req, res) => {
  const { rows } = await db.query(
    'SELECT key, value FROM settings WHERE is_public = true');
  res.json(Object.fromEntries(rows.map((r) => [r.key, r.value])));
}));

// Manager-only (mounted behind managerOnly in app.js).
const privateRouter = express.Router();

privateRouter.get('/', asyncH(async (req, res) => {
  const { rows } = await db.query('SELECT key, value, is_public FROM settings');
  res.json(Object.fromEntries(rows.map((r) => [r.key, r.value])));
}));

privateRouter.put('/', asyncH(async (req, res) => {
  const updates = [];
  const shopName = str(req.body.shop_name);
  if (shopName) updates.push(['shop_name', JSON.stringify(shopName)]);
  if (req.body.logo_url !== undefined) {
    updates.push(['logo_url', JSON.stringify(str(req.body.logo_url))]);
  }
  if (req.body.default_piece_rate !== undefined) {
    const rate = intOrNull(req.body.default_piece_rate);
    if (rate == null) return res.status(400).json({ error: 'default_piece_rate invalide.' });
    updates.push(['default_piece_rate', JSON.stringify(rate)]);
  }
  if (!updates.length) return res.status(400).json({ error: 'Rien à mettre à jour.' });
  for (const [key, value] of updates) {
    await db.query('UPDATE settings SET value = $1 WHERE key = $2', [value, key]);
  }
  const { rows } = await db.query('SELECT key, value FROM settings');
  res.json(Object.fromEntries(rows.map((r) => [r.key, r.value])));
}));

module.exports = { publicRouter, privateRouter };
