// One-time bootstrap of the two operating accounts (Gérant + Secrétaire).
// Refuses to run if any user already exists — accounts are managed through
// the manager-only /api/users endpoints afterwards.
const path = require('path');
const bcrypt = require('bcryptjs');
const { Pool } = require('pg');

async function seed(databaseUrl, accounts) {
  const pool = new Pool({ connectionString: databaseUrl });
  try {
    const { rows } = await pool.query('SELECT count(*)::int AS n FROM users');
    if (rows[0].n > 0) {
      console.log('users already exist — seed skipped');
      return false;
    }
    for (const a of accounts) {
      await pool.query(
        `INSERT INTO users (username, password_hash, name, role)
         VALUES ($1, $2, $3, $4)`,
        [a.username, bcrypt.hashSync(a.password, 10), a.name, a.role],
      );
      console.log(`created ${a.role}: ${a.username}`);
    }
    return true;
  } finally {
    await pool.end();
  }
}

if (require.main === module) {
  require('dotenv').config({ path: path.resolve(__dirname, '../.env') });
  const env = process.env;
  const required = ['SEED_MANAGER_USERNAME', 'SEED_MANAGER_PASSWORD',
    'SEED_SECRETARY_USERNAME', 'SEED_SECRETARY_PASSWORD'];
  const missing = required.filter((k) => !env[k]);
  if (missing.length) {
    console.error(`missing env vars: ${missing.join(', ')}`);
    process.exit(1);
  }
  seed(env.DATABASE_URL, [
    { username: env.SEED_MANAGER_USERNAME, password: env.SEED_MANAGER_PASSWORD,
      name: env.SEED_MANAGER_NAME || 'Le Gérant', role: 'MANAGER' },
    { username: env.SEED_SECRETARY_USERNAME, password: env.SEED_SECRETARY_PASSWORD,
      name: env.SEED_SECRETARY_NAME || 'La Secrétaire', role: 'SECRETARY' },
  ]).catch((err) => { console.error(err); process.exit(1); });
}

module.exports = { seed };
