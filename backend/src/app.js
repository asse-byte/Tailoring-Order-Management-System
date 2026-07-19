const express = require('express');
const path = require('path');
const { authenticate, managerOnly, staffOnly } = require('./middleware/auth');

const authRouter = require('./routes/auth');
const clientsRouter = require('./routes/clients');
const productsRouter = require('./routes/products');
const salesRouter = require('./routes/sales');
const staffRouter = require('./routes/staff');
const staffPayRouter = require('./routes/staffPay');
const salaryPaymentsRouter = require('./routes/salaryPayments');
const tailorEntriesRouter = require('./routes/tailorEntries');
const expensesRouter = require('./routes/expenses');
const financeRouter = require('./routes/finance');
const reportsRouter = require('./routes/reports');
const ordersRouter = require('./routes/orders');
const appointmentsRouter = require('./routes/appointments');
const pretAPorterRouter = require('./routes/pretAPorter');
const settings = require('./routes/settings');
const usersRouter = require('./routes/users');
const uploadRouter = require('./routes/upload');

function createApp() {
  const app = express();
  app.set('trust proxy', 1); // behind nginx on the VPS
  app.disable('x-powered-by'); // don't advertise Express
  app.use(express.json({ limit: '1mb' }));

  // Baseline security headers on every response (manual, like the CORS block
  // below — the project keeps its dependency surface minimal). nosniff stops
  // MIME-sniffing; DENY blocks clickjacking; the API returns only JSON so a
  // strict CSP is safe.
  app.use((req, res, next) => {
    res.header('X-Content-Type-Options', 'nosniff');
    res.header('X-Frame-Options', 'DENY');
    res.header('Referrer-Policy', 'no-referrer');
    res.header('Content-Security-Policy', "default-src 'none'; frame-ancestors 'none'");
    return next();
  });

  // CORS: auth is a Bearer header (no cookies), so a permissive policy is
  // safe and lets Flutter Web (different dev origin) reach the API AND the
  // /uploads images below (must come before the static mount so those
  // cross-origin image requests get an Access-Control-Allow-Origin header).
  app.use((req, res, next) => {
    res.header('Access-Control-Allow-Origin', '*');
    res.header('Access-Control-Allow-Headers', 'Authorization, Content-Type');
    res.header('Access-Control-Allow-Methods', 'GET,POST,PUT,DELETE,OPTIONS');
    if (req.method === 'OPTIONS') return res.sendStatus(204);
    return next();
  });

  // Serve uploads statically. Extra hardening: even though only re-encoded
  // images and signature-checked videos are ever written here (see upload.js),
  // force nosniff + a sandbox CSP so a stored file can never be interpreted as
  // an executable document by the browser.
  app.use('/uploads', express.static(path.join(__dirname, '../uploads'), {
    setHeaders: (res) => {
      res.setHeader('X-Content-Type-Options', 'nosniff');
      res.setHeader('Content-Security-Policy', "default-src 'none'; sandbox");
    },
  }));

  // ==========================================================================
  // SECURITY MAP — deny by default.
  // Every mount below declares its access level explicitly. Anything not
  // mounted is a 404; anything past `authenticate` without a valid token is
  // a 401; every [FINANCE] mount is manager-only and returns 403 to the
  // secretary. backend/tests/security.test.js proves each line of this map.
  // ==========================================================================

  // -- public (pre-auth): login + shop identity for the login screen --------
  app.use('/api/auth', authRouter);
  app.use('/api/settings/public', settings.publicRouter);

  // -- everything below requires a valid token; role comes from the DB ------
  app.use('/api', authenticate);

  // -- daily operations: both roles ------------------------------------------
  app.use('/api/clients', staffOnly, clientsRouter);
  app.use('/api/orders', staffOnly, ordersRouter);            // DELETE: manager (in router)
  app.use('/api/appointments', staffOnly, appointmentsRouter);
  app.use('/api/products', staffOnly, productsRouter);        // CRUD both; cost_price + /stats manager-only
  app.use('/api/pret-a-porter', staffOnly, pretAPorterRouter); // CRUD both; cost_price + /stats manager-only
  app.use('/api/sales', staffOnly, salesRouter);              // GET: manager (in router)
  app.use('/api/staff', staffOnly, staffRouter);              // CRUD both (roster; pay stays manager-only)
  app.use('/api/upload', staffOnly, uploadRouter);

  // -- [FINANCE] manager-only: the secretary gets 403 on every route ---------
  app.use('/api/staff-pay', managerOnly, staffPayRouter);
  app.use('/api/salary-payments', managerOnly, salaryPaymentsRouter);
  app.use('/api/tailor-entries', managerOnly, tailorEntriesRouter);
  app.use('/api/expenses', managerOnly, expensesRouter);
  app.use('/api/finance', managerOnly, financeRouter);
  app.use('/api/reports', managerOnly, reportsRouter);
  app.use('/api/settings/private', managerOnly, settings.privateRouter);
  app.use('/api/users', managerOnly, usersRouter);

  // -- fallthrough ------------------------------------------------------------
  app.use((req, res) => res.status(404).json({ error: 'Route inconnue.' }));

  // Central error handler: map DB constraint violations to clean statuses.
  // eslint-disable-next-line no-unused-vars
  app.use((err, req, res, next) => {
    if (err.code === '23505') { // unique_violation
      return res.status(409).json({ error: 'Doublon: cet enregistrement existe déjà.' });
    }
    if (err.code === '23503') { // foreign_key_violation
      return res.status(409).json({
        error: 'Opération impossible: des données liées existent (désactivez plutôt).',
      });
    }
    if (err.code === '23514') { // check_violation
      return res.status(400).json({ error: 'Valeur invalide.' });
    }
    if (err.code === 'P0001') { // raise_exception (append-only triggers)
      return res.status(409).json({ error: err.message });
    }
    if (err.code === '22P02') { // invalid_text_representation (bad uuid, etc.)
      return res.status(400).json({ error: 'Identifiant invalide.' });
    }
    console.error(err);
    return res.status(500).json({ error: 'Erreur interne du serveur.' });
  });

  return app;
}

module.exports = { createApp };
