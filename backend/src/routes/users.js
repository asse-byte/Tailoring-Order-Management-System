const express = require('express');
const bcrypt = require('bcryptjs');
const db = require('../db');
const { asyncH, str } = require('../util');

// Mounted manager-only in app.js. There is NO self-registration anywhere:
// the manager creates/updates the (only) two operating accounts here.
const router = express.Router();

router.get('/', asyncH(async (req, res) => {
  const { rows } = await db.query(
    'SELECT id, username, name, role, created_at FROM users ORDER BY role, username');
  res.json({ items: rows });
}));

router.post('/', asyncH(async (req, res) => {
  const username = str(req.body.username);
  const password = typeof req.body.password === 'string' ? req.body.password : '';
  const role = req.body.role;
  if (!username || password.length < 8 || !['MANAGER', 'SECRETARY'].includes(role)) {
    return res.status(400).json({
      error: 'username, password (≥ 8 caractères) et role (MANAGER|SECRETARY) requis.',
    });
  }
  const { rows } = await db.query(
    `INSERT INTO users (username, password_hash, name, role)
     VALUES ($1, $2, $3, $4) RETURNING id, username, name, role, created_at`,
    [username.toLowerCase(), bcrypt.hashSync(password, 10),
      str(req.body.name) || username, role]);
  res.status(201).json(rows[0]);
}));

router.put('/:id/password', asyncH(async (req, res) => {
  const password = typeof req.body.new_password === 'string' ? req.body.new_password : '';
  if (password.length < 8) {
    return res.status(400).json({ error: 'Mot de passe: 8 caractères minimum.' });
  }
  const { rowCount } = await db.query(
    'UPDATE users SET password_hash = $1 WHERE id = $2',
    [bcrypt.hashSync(password, 10), req.params.id]);
  if (!rowCount) return res.status(404).json({ error: 'Compte introuvable.' });
  res.json({ ok: true });
}));

router.delete('/:id', asyncH(async (req, res) => {
  if (req.params.id === req.user.id) {
    return res.status(400).json({ error: 'Impossible de supprimer votre propre compte.' });
  }
  const { rowCount } = await db.query('DELETE FROM users WHERE id = $1', [req.params.id]);
  if (!rowCount) return res.status(404).json({ error: 'Compte introuvable.' });
  res.status(204).end();
}));

module.exports = router;
