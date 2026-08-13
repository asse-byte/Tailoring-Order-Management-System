// =============================================================================
// Regression tests for the 2026-08-13 security audit fixes.
// =============================================================================
// Both surfaces below had ZERO test coverage before this file, which is why
// they are pinned here: the rest of the suite passing said nothing about them.
//
//  1. Client / supplier search: the search term is bound as a parameter (so it
//     was never injectable) but it was still interpreted as a LIKE PATTERN, so
//     "%" matched every row and defeated the lower(full_name) prefix index.
//  2. GET /api/whatsapp/status returns a send log containing CLIENT PHONE
//     NUMBERS and is open to both roles — the log is now manager-only.
// =============================================================================

const request = require('supertest');
const { createApp } = require('../src/app');
const db = require('../src/db');
const { MANAGER, SECRETARY, seedUsers, login } = require('./helpers');

let app;
let managerToken;
let secToken;

const asManager = (r) => r.set('Authorization', `Bearer ${managerToken}`);
const asSec = (r) => r.set('Authorization', `Bearer ${secToken}`);

beforeAll(async () => {
  app = createApp();
  await seedUsers();
  managerToken = await login(app, MANAGER);
  secToken = await login(app, SECRETARY);

  // Fixtures are deliberately unmistakable. The whole suite shares ONE
  // database and Jest may run this file before or after the others, so any
  // name or phone that another suite might also use would make these
  // assertions order-dependent. Hence the ZQX marker and the 9876 phone run,
  // which appear nowhere else in backend/tests.
  for (const [name, phone] of [
    ['ZQXsearch Alpha', '98761001'],
    ['100%ZQX Coton', '98761002'],
    ['ZQXsearch Beta', '98761003'],
  ]) {
    await request(app).post('/api/clients').use(asManager)
      .send({ full_name: name, phone });
  }
});

afterAll(async () => {
  await db.closePool();
});

describe('search terms are not treated as LIKE patterns', () => {
  test('"%" does not match every client', async () => {
    const res = await request(app).get('/api/clients').query({ search: '%' }).use(asManager);
    expect(res.status).toBe(200);
    // Before the fix this returned the whole table.
    expect(res.body.items).toHaveLength(0);
  });

  test('"_" does not act as a single-character wildcard', async () => {
    // Matches "ZQXsearch" only if _ is treated as a wildcard.
    const res = await request(app).get('/api/clients').query({ search: '_QXsearch' }).use(asManager);
    expect(res.status).toBe(200);
    expect(res.body.items).toHaveLength(0);
  });

  test('a literal % in the search term still finds the client named with one', async () => {
    const res = await request(app).get('/api/clients').query({ search: '100%ZQX' }).use(asManager);
    expect(res.status).toBe(200);
    expect(res.body.items.map((c) => c.full_name)).toEqual(['100%ZQX Coton']);
  });

  test('ordinary prefix search is unchanged', async () => {
    const res = await request(app).get('/api/clients').query({ search: 'ZQXsearch' }).use(asManager);
    expect(res.status).toBe(200);
    expect(res.body.items.map((c) => c.full_name))
      .toEqual(['ZQXsearch Alpha', 'ZQXsearch Beta']);
  });

  test('phone substring search still matches', async () => {
    // All three seeded phones share this run; no other suite uses 9876.
    const res = await request(app).get('/api/clients').query({ search: '98761' }).use(asManager);
    expect(res.status).toBe(200);
    expect(res.body.items).toHaveLength(3);
  });

  test('supplier search (manager-only) also ignores wildcards', async () => {
    await request(app).post('/api/suppliers').use(asManager).send({ name: 'ZQXfournisseur' });
    const all = await request(app).get('/api/suppliers').query({ search: '%' }).use(asManager);
    expect(all.status).toBe(200);
    expect(all.body.items).toHaveLength(0);

    const hit = await request(app).get('/api/suppliers').query({ search: 'ZQXfourn' }).use(asManager);
    expect(hit.body.items.map((s) => s.name)).toEqual(['ZQXfournisseur']);
  });
});

describe('WhatsApp gateway status does not leak client phone numbers', () => {
  // The log only fills up when a provider is configured and a message is
  // really dispatched, which never happens in tests. Seed the singleton
  // directly — otherwise both assertions below would pass against an empty
  // array whether or not the fix is present.
  const whatsappService = require('../src/services/whatsapp');

  beforeAll(() => {
    whatsappService.logs.unshift({
      order_id: null,
      phone: '+22370000001',
      sent_at: new Date().toISOString(),
      status: 'SENT',
    });
  });

  afterAll(() => {
    whatsappService.logs.length = 0;
  });

  test('the secretary sees gateway health but never the send log', async () => {
    const res = await request(app).get('/api/whatsapp/status').use(asSec);
    expect(res.status).toBe(200);
    // She still gets what she needs to do her job.
    expect(res.body).toHaveProperty('configured');
    expect(res.body.total_sent).toBe(1);
    // …but not who was contacted.
    expect(res.body.recent_logs).toEqual([]);
    expect(JSON.stringify(res.body)).not.toContain('22370000001');
  });

  test('the manager still receives the full send log', async () => {
    const res = await request(app).get('/api/whatsapp/status').use(asManager);
    expect(res.status).toBe(200);
    expect(res.body.recent_logs).toHaveLength(1);
    expect(res.body.recent_logs[0].phone).toBe('+22370000001');
  });
});
