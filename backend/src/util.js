/** Wrap an async route handler so rejections reach the error middleware. */
const asyncH = (fn) => (req, res, next) => fn(req, res, next).catch(next);

/** Parse limit/offset with sane bounds (speed rule: never unbounded lists). */
function pagination(req, defLimit = 20, maxLimit = 100) {
  const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || defLimit, 1), maxLimit);
  const offset = Math.max(parseInt(req.query.offset, 10) || 0, 0);
  return { limit, offset };
}

/** Non-negative integer or null (money fields — FCFA has no decimals). */
function intOrNull(v) {
  if (v === undefined || v === null || v === '') return null;
  const n = Number(v);
  return Number.isInteger(n) && n >= 0 ? n : undefined; // undefined = invalid
}

/** Required non-empty trimmed string, else null. */
function str(v) {
  if (typeof v !== 'string') return null;
  const s = v.trim();
  return s.length ? s : null;
}

/** ISO week id (e.g. 2026-W27) for a YYYY-MM-DD date string. */
function isoWeekId(dateStr) {
  const d = new Date(`${dateStr}T00:00:00Z`);
  const day = (d.getUTCDay() + 6) % 7; // Mon=0
  d.setUTCDate(d.getUTCDate() - day + 3); // Thursday of this week
  const isoYear = d.getUTCFullYear();
  const jan4 = new Date(Date.UTC(isoYear, 0, 4));
  const week = 1 + Math.round(((d - jan4) / 86400000 - 3 + ((jan4.getUTCDay() + 6) % 7)) / 7);
  return `${isoYear}-W${String(week).padStart(2, '0')}`;
}

/** YYYY-MM-DD validation. */
function dateStr(v) {
  return typeof v === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(v) ? v : null;
}

module.exports = { asyncH, pagination, intOrNull, str, isoWeekId, dateStr };
