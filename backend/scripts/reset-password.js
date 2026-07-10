// Account recovery for a locked-out manager/secretary.
//
// There is no self-service password reset in the app (by design), so if the
// only manager forgets their credentials this script rewrites them directly
// in the database. Run it on the machine that can reach the DB.
//
// Connection: uses DATABASE_URL if set, otherwise the local dev database
// (the one `npm run dev` boots). For local dev, keep `npm run dev` running in
// another terminal so the embedded PostgreSQL is up, then run this.
//
// Usage:
//   node scripts/reset-password.js --list
//       → list every account (username + role) so you can recover a
//         forgotten USERNAME.
//
//   node scripts/reset-password.js <username> <new_password>
//       → set a new password (min 8 chars) for that username.
//
//   node scripts/reset-password.js <username> <new_password> --rename <new_username>
//       → also change the username (if you want a fresh one).
//
// Examples:
//   node scripts/reset-password.js --list
//   node scripts/reset-password.js gerant NouveauPass#2026
require('dotenv').config({ path: require('path').resolve(__dirname, '../.env') });
const bcrypt = require('bcryptjs');
const { Pool } = require('pg');

const DEV_URL = 'postgres://postgres:postgres@localhost:5642/couture_dev';
const databaseUrl = process.env.DATABASE_URL || DEV_URL;

async function main() {
  const args = process.argv.slice(2);
  const pool = new Pool({ connectionString: databaseUrl });
  try {
    if (args.length === 0 || args[0] === '--list') {
      const { rows } = await pool.query(
        'SELECT username, name, role, created_at FROM users ORDER BY role, username');
      if (rows.length === 0) {
        console.log('Aucun compte trouvé. Lancez le seed pour créer les comptes.');
        return;
      }
      console.log('\nComptes existants :\n');
      for (const r of rows) {
        console.log(`  • ${r.role.padEnd(9)}  username: ${r.username}   (${r.name})`);
      }
      console.log('\nPour réinitialiser un mot de passe :');
      console.log('  node scripts/reset-password.js <username> <nouveau_mot_de_passe>\n');
      return;
    }

    const [username, newPassword] = args;
    if (!username || !newPassword) {
      console.error('Usage: node scripts/reset-password.js <username> <new_password>');
      process.exit(1);
    }
    if (newPassword.length < 8) {
      console.error('Le mot de passe doit contenir au moins 8 caractères.');
      process.exit(1);
    }

    // Optional --rename <new_username>
    let newUsername = null;
    const renameIdx = args.indexOf('--rename');
    if (renameIdx !== -1) newUsername = args[renameIdx + 1];

    const hash = bcrypt.hashSync(newPassword, 10);
    const { rows } = newUsername
      ? await pool.query(
          `UPDATE users SET password_hash = $1, username = $2
           WHERE lower(username) = lower($3) RETURNING username, role`,
          [hash, newUsername.toLowerCase(), username])
      : await pool.query(
          `UPDATE users SET password_hash = $1
           WHERE lower(username) = lower($2) RETURNING username, role`,
          [hash, username]);

    if (rows.length === 0) {
      console.error(`Aucun compte avec le username « ${username} ». `
        + 'Utilisez --list pour voir les comptes.');
      process.exit(1);
    }
    console.log(`✔ Mot de passe réinitialisé pour ${rows[0].role} « ${rows[0].username} ».`);
    console.log('Vous pouvez maintenant vous connecter avec ce nouveau mot de passe.');
  } finally {
    await pool.end();
  }
}

main().catch((err) => { console.error(err); process.exit(1); });
