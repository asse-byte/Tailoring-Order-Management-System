const bcrypt = require('bcryptjs');
const request = require('supertest');
const db = require('../src/db');

const MANAGER = { username: 'gerant', password: 'Gerant#12345', role: 'MANAGER' };
const SECRETARY = { username: 'secretaire', password: 'Secret#12345', role: 'SECRETARY' };

/** Insert the two operating accounts directly (bcrypt cost 4 for speed). */
async function seedUsers() {
  const ids = {};
  for (const u of [MANAGER, SECRETARY]) {
    const { rows } = await db.query(
      `INSERT INTO users (username, password_hash, name, role)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (username) DO UPDATE SET role = EXCLUDED.role
       RETURNING id`,
      [u.username, bcrypt.hashSync(u.password, 4), u.username, u.role]);
    ids[u.role] = rows[0].id;
  }
  return ids;
}

/** Real login through the API — tokens are produced the same way prod does. */
async function login(app, { username, password }) {
  const res = await request(app).post('/api/auth/login').send({ username, password });
  if (res.status !== 200) throw new Error(`login failed for ${username}: ${res.status}`);
  return res.body.token;
}

module.exports = { MANAGER, SECRETARY, seedUsers, login };
