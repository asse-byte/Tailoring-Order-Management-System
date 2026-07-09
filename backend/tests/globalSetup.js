// Boots a REAL PostgreSQL (embedded-postgres downloads the binaries as an
// npm dev dependency — no Docker needed on the dev machine), runs the
// migrations, and exposes DATABASE_URL to the test process.
const path = require('path');
const os = require('os');
const fs = require('fs');
const EP = require('embedded-postgres');
const { migrate } = require('../scripts/migrate');

const EmbeddedPostgres = EP.default || EP;
const PORT = 5691;

module.exports = async () => {
  const dataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'couture-pg-'));
  const pg = new EmbeddedPostgres({
    databaseDir: dataDir,
    user: 'postgres',
    password: 'postgres',
    port: PORT,
    persistent: false,
    initdbFlags: ['--encoding=UTF8', '--locale=C'],
  });
  await pg.initialise();
  await pg.start();
  await pg.createDatabase('couture_test');

  const url = `postgres://postgres:postgres@localhost:${PORT}/couture_test`;
  await migrate(url);

  process.env.DATABASE_URL = url;
  process.env.JWT_SECRET = 'test-secret-not-for-production';
  process.env.NODE_ENV = 'test';

  globalThis.__EPG__ = pg;
  globalThis.__EPG_DIR__ = dataDir;
};
