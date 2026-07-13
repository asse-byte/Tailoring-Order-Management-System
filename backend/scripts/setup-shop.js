// One-command onboarding for a BRAND-NEW tailoring shop (isolated instance).
//
// Each shop runs its own deployment + database. This script provisions that
// empty database end-to-end so the shop starts fully branded as its own:
//   1. runs all migrations,
//   2. seeds the two operating accounts (Gérant + Secrétaire),
//   3. writes the shop identity (name, default piece-rate, promo link) so the
//      login screen and invoices carry the shop's own name from day one.
//
// The logo is uploaded afterwards by the manager from Paramètres (or drop a
// file at tailoring_app/assets/logo.jpeg before building that shop's app).
//
// Safe to re-run: migrations are idempotent, account seeding refuses to touch
// an already-seeded database, and settings are upserted.
//
// Usage: fill backend/.env for the new shop, then:  npm run setup-shop
const path = require('path');
const { Pool } = require('pg');
const { migrate } = require('./migrate');
const { seed } = require('./seed');

async function applyShopIdentity(databaseUrl, identity) {
  const pool = new Pool({ connectionString: databaseUrl });
  try {
    const rows = [
      ['shop_name', JSON.stringify(identity.shopName), true],
      ['default_piece_rate', JSON.stringify(identity.defaultPieceRate), false],
      ['promo_group_link', JSON.stringify(identity.promoGroupLink), true],
    ];
    for (const [key, value, isPublic] of rows) {
      await pool.query(
        `INSERT INTO settings (key, value, is_public)
         VALUES ($1, $2::jsonb, $3)
         ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value`,
        [key, value, isPublic],
      );
    }
    console.log(`shop identity set: "${identity.shopName}"`);
  } finally {
    await pool.end();
  }
}

async function setupShop(env) {
  const required = ['DATABASE_URL', 'SEED_MANAGER_USERNAME', 'SEED_MANAGER_PASSWORD',
    'SEED_SECRETARY_USERNAME', 'SEED_SECRETARY_PASSWORD', 'SHOP_NAME'];
  const missing = required.filter((k) => !env[k]);
  if (missing.length) {
    throw new Error(`missing env vars: ${missing.join(', ')}`);
  }

  console.log('1/3 running migrations…');
  await migrate(env.DATABASE_URL);

  console.log('2/3 seeding accounts…');
  await seed(env.DATABASE_URL, [
    { username: env.SEED_MANAGER_USERNAME, password: env.SEED_MANAGER_PASSWORD,
      name: env.SEED_MANAGER_NAME || 'Le Gérant', role: 'MANAGER' },
    { username: env.SEED_SECRETARY_USERNAME, password: env.SEED_SECRETARY_PASSWORD,
      name: env.SEED_SECRETARY_NAME || 'La Secrétaire', role: 'SECRETARY' },
  ]);

  console.log('3/3 writing shop identity…');
  await applyShopIdentity(env.DATABASE_URL, {
    shopName: env.SHOP_NAME,
    defaultPieceRate: Number(env.DEFAULT_PIECE_RATE || 0),
    promoGroupLink: env.PROMO_GROUP_LINK || '',
  });

  console.log(`\n✅ Shop "${env.SHOP_NAME}" is ready.`);
  console.log(`   Manager login:   ${env.SEED_MANAGER_USERNAME}`);
  console.log(`   Secretary login: ${env.SEED_SECRETARY_USERNAME}`);
  console.log('   Upload the shop logo from Paramètres after first login.');
}

if (require.main === module) {
  require('dotenv').config({ path: path.resolve(__dirname, '../.env') });
  setupShop(process.env).catch((err) => { console.error(err); process.exit(1); });
}

module.exports = { setupShop, applyShopIdentity };
