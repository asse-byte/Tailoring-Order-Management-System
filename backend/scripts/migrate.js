// Minimal, transparent migration runner: applies backend/migrations/*.sql
// in filename order, each inside a transaction, tracked in schema_migrations.
const fs = require('fs');
const path = require('path');
const { Pool } = require('pg');

async function migrate(databaseUrl) {
  const pool = new Pool({ connectionString: databaseUrl });
  try {
    await pool.query(`CREATE TABLE IF NOT EXISTS schema_migrations (
      name text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now()
    )`);
    const dir = path.resolve(__dirname, '../migrations');
    const files = fs.readdirSync(dir).filter((f) => f.endsWith('.sql')).sort();
    for (const file of files) {
      const { rows } = await pool.query(
        'SELECT 1 FROM schema_migrations WHERE name = $1', [file]);
      if (rows.length) continue;
      const sql = fs.readFileSync(path.join(dir, file), 'utf8');
      const client = await pool.connect();
      try {
        await client.query('BEGIN');
        await client.query(sql);
        await client.query('INSERT INTO schema_migrations (name) VALUES ($1)', [file]);
        await client.query('COMMIT');
        console.log(`applied ${file}`);
      } catch (err) {
        await client.query('ROLLBACK');
        throw err;
      } finally {
        client.release();
      }
    }
  } finally {
    await pool.end();
  }
}

if (require.main === module) {
  require('dotenv').config({ path: path.resolve(__dirname, '../.env') });
  migrate(process.env.DATABASE_URL)
    .then(() => console.log('migrations up to date'))
    .catch((err) => { console.error(err); process.exit(1); });
}

module.exports = { migrate };
