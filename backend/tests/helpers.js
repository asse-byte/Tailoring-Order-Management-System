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

/**
 * Tables that must survive a reset: the migration ledger, the shop identity,
 * and the product types every product row has a foreign key to. Everything
 * else is fixture data.
 */
const KEEP_TABLES = new Set(['schema_migrations', 'migrations', 'settings',
  'product_categories']);

/**
 * Give the calling suite an EMPTY database, then re-seed the two accounts.
 *
 * Almost every suite here works in baseline→delta, because they all share one
 * PostgreSQL and Jest runs them `--runInBand` one after another. A suite that
 * asserts an ABSOLUTE total — "the whole day came to 167 000 exactly" — cannot
 * do that: whatever the previous suite left behind lands in the same sum. This
 * wipes the slate so those absolute numbers mean what they say.
 *
 * TRUNCATE is what makes it possible at all. The financial tables are
 * append-only through row-level BEFORE UPDATE OR DELETE triggers, and row-level
 * triggers do not fire on TRUNCATE — so this resets the fixtures without
 * disabling a single protection, which is the one thing the delete path must
 * never do (see the Antigravity review in CLAUDE.md).
 *
 * Suites that run afterwards are unaffected: each builds its own fixtures in
 * its own `beforeAll`, and an empty database is the cleanest start they can get.
 *
 * Call it at the top of a `describe`. Returns nothing; it registers its own
 * `beforeAll`.
 */
function withFreshDb() {
  beforeAll(async () => {
    const { rows } = await db.query(
      `SELECT tablename FROM pg_tables WHERE schemaname = 'public'`);
    const targets = rows
      .map((r) => r.tablename)
      .filter((t) => !KEEP_TABLES.has(t));

    if (targets.length) {
      // One statement: the tables reference each other, so they have to be
      // emptied together. CASCADE covers anything not named explicitly.
      await db.query(
        `TRUNCATE TABLE ${targets.map((t) => `"${t}"`).join(', ')} `
        + 'RESTART IDENTITY CASCADE');
    }
    await seedUsers();
  });
}

module.exports = { MANAGER, SECRETARY, seedUsers, login, withFreshDb };
