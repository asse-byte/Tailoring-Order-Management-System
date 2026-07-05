const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const db = require('../db');
const { asyncH, str } = require('../util');

const router = express.Router();

// Tiny in-memory login rate limit (per IP): enough for a two-user shop app.
const attempts = new Map();
const WINDOW_MS = 15 * 60 * 1000;
const MAX_ATTEMPTS = 25;

function rateLimit(req, res, next) {
  if (process.env.NODE_ENV === 'test') return next();
  const now = Date.now();
  const rec = attempts.get(req.ip) || { count: 0, start: now };
  if (now - rec.start > WINDOW_MS) { rec.count = 0; rec.start = now; }
  rec.count += 1;
  attempts.set(req.ip, rec);
  if (rec.count > MAX_ATTEMPTS) {
    return res.status(429).json({ error: 'Trop de tentatives. Réessayez plus tard.' });
  }
  return next();
}

router.post('/login', rateLimit, asyncH(async (req, res) => {
  const username = str(req.body.username);
  const password = typeof req.body.password === 'string' ? req.body.password : '';
  if (!username || !password) {
    return res.status(400).json({ error: 'Nom d’utilisateur et mot de passe requis.' });
  }
  const { rows } = await db.query(
    'SELECT id, username, password_hash, name, role FROM users WHERE username = $1',
    [username.toLowerCase()]);
  const user = rows[0];
  if (!user || !bcrypt.compareSync(password, user.password_hash)) {
    return res.status(401).json({ error: 'Identifiants incorrects.' });
  }
  // Only the user id goes in the token; the role is re-read from the DB on
  // every request (see middleware/auth.js).
  const token = jwt.sign({ sub: user.id }, process.env.JWT_SECRET, { expiresIn: '12h' });
  return res.json({
    token,
    user: { id: user.id, username: user.username, name: user.name, role: user.role },
  });
}));

module.exports = router;
