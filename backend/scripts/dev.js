// Local dev server WITHOUT Docker: boots a real PostgreSQL via
// embedded-postgres (persistent data in backend/data/devdb), migrates,
// seeds the two dev accounts, then starts the API on :3000.
//
//   npm run dev
//   → gerant / Gerant#12345   (MANAGER)
//   → secretaire / Secret#12345 (SECRETARY)
const fs = require('fs');
const path = require('path');
const EP = require('embedded-postgres');
const { migrate } = require('./migrate');
const { seed } = require('./seed');

const EmbeddedPostgres = EP.default || EP;
const PG_PORT = 5642;
const DATA_DIR = path.resolve(__dirname, '../data/devdb');

async function main() {
  const fresh = !fs.existsSync(DATA_DIR);
  const pg = new EmbeddedPostgres({
    databaseDir: DATA_DIR,
    user: 'postgres',
    password: 'postgres',
    port: PG_PORT,
    persistent: true,
  });
  if (fresh) await pg.initialise();
  await pg.start();
  if (fresh) await pg.createDatabase('couture_dev');

  const url = `postgres://postgres:postgres@localhost:${PG_PORT}/couture_dev`;
  await migrate(url);
  await seed(url, [
    { username: 'gerant', password: 'Gerant#12345', name: 'Le Gérant', role: 'MANAGER' },
    { username: 'secretaire', password: 'Secret#12345', name: 'La Secrétaire', role: 'SECRETARY' },
  ]);

  process.env.DATABASE_URL = url;
  process.env.JWT_SECRET = process.env.JWT_SECRET || 'dev-secret-not-for-production';
  process.env.PORT = process.env.PORT || '3000';

  // eslint-disable-next-line global-require
  require('../src/server');

  const stop = async () => { await pg.stop(); process.exit(0); };
  process.on('SIGINT', stop);
  process.on('SIGTERM', stop);
}

main().catch((err) => { console.error(err); process.exit(1); });
