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
  // Escape hatch for environments where the embedded server cannot start
  // (containers where initdb may not write to the temp dir, CI images that
  // already ship a PostgreSQL). Point TEST_DATABASE_URL at an EMPTY database:
  // the migrations are applied to it exactly as they are to the embedded one.
  if (process.env.TEST_DATABASE_URL) {
    await migrate(process.env.TEST_DATABASE_URL);
    process.env.DATABASE_URL = process.env.TEST_DATABASE_URL;
    process.env.JWT_SECRET = 'test-secret-not-for-production';
    process.env.NODE_ENV = 'test';
    return;
  }

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
