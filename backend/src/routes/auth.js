const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const db = require('../db');
const { authenticate } = require('../middleware/auth');
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

// Session restore for the app: token in, fresh user (with DB role) out.
router.get('/me', authenticate, (req, res) => {
  res.json({ user: req.user });
});

// Self-service password change, both roles (requires the current password).
router.post('/change-password', authenticate, asyncH(async (req, res) => {
  const current = typeof req.body.current_password === 'string'
    ? req.body.current_password : '';
  const next = typeof req.body.new_password === 'string'
    ? req.body.new_password : '';
  if (next.length < 8) {
    return res.status(400).json({ error: 'Nouveau mot de passe: 8 caractères minimum.' });
  }
  const { rows } = await db.query(
    'SELECT password_hash FROM users WHERE id = $1', [req.user.id]);
  if (!bcrypt.compareSync(current, rows[0].password_hash)) {
    return res.status(401).json({ error: 'Mot de passe actuel incorrect.' });
  }
  await db.query('UPDATE users SET password_hash = $1 WHERE id = $2',
    [bcrypt.hashSync(next, 10), req.user.id]);
  return res.json({ ok: true });
}));

module.exports = router;
