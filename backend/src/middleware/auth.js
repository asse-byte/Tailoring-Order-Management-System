const jwt = require('jsonwebtoken');
const db = require('../db');

/**
 * Verifies the Bearer token, then loads the user fresh from the database.
 * The role in the token payload is IGNORED — the users table is the only
 * source of truth, so a tampered or stale token can never elevate access.
 */
async function authenticate(req, res, next) {
  try {
    const header = req.headers.authorization || '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : null;
    if (!token) {
      return res.status(401).json({ error: 'Authentification requise.' });
    }
    let payload;
    try {
      payload = jwt.verify(token, process.env.JWT_SECRET);
    } catch {
      return res.status(401).json({ error: 'Session invalide ou expirée.' });
    }
    const { rows } = await db.query(
      'SELECT id, username, name, role FROM users WHERE id = $1', [payload.sub]);
    if (!rows[0]) {
      return res.status(401).json({ error: 'Compte introuvable.' });
    }
    req.user = rows[0];
    return next();
  } catch (err) {
    return next(err);
  }
}

/** 403 unless the authenticated user's DB role is in the allowed list. */
function requireRole(...roles) {
  return (req, res, next) => {
    if (!req.user) return res.status(401).json({ error: 'Authentification requise.' });
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({ error: 'Accès refusé.' });
    }
    return next();
  };
}

const managerOnly = requireRole('MANAGER');
const staffOnly = requireRole('MANAGER', 'SECRETARY');

module.exports = { authenticate, requireRole, managerOnly, staffOnly };
