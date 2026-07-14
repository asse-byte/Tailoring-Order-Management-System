// =============================================================================
// Item 8 — business report: revenue/costs + activity stats (manager-only).
// =============================================================================
// Uses baseline→after DELTAS (tests run --runInBand, so nothing else mutates
// the DB between the two reads) and keeps tailor entries in October so it never
// disturbs the exact July finance assertions in security.test.js.
// =============================================================================

const request = require('supertest');
const { createApp } = require('../src/app');
const db = require('../src/db');
const { MANAGER, SECRETARY, seedUsers, login } = require('./helpers');

let app;
let mToken;
let sToken;
const asM = (r) => r.set('Authorization', `Bearer ${mToken}`);
const asS = (r) => r.set('Authorization', `Bearer ${sToken}`);

beforeAll(async () => {
  app = createApp();
  await seedUsers();
  mToken = await login(app, MANAGER);
  sToken = await login(app, SECRETARY);
});

afterAll(async () => { await db.closePool(); });

test('secretary is blocked from the report (403)', async () => {
  expect((await asS(request(app).get('/api/reports/summary'))).status).toBe(403);
});

test('activity stats: a new client + a delivered order move the counters by 1', async () => {
  const today = new Date().toISOString().slice(0, 10);
  const url = `/api/reports/summary?from=${today}&to=${today}`;

  const before = (await asM(request(app).get(url))).body;

  const clientId = (await asM(request(app).post('/api/clients')).send({
    full_name: 'Rapport Client', phone: '75009000',
  })).body.id;
  const orderId = (await asM(request(app).post('/api/orders')).send({
    client_id: clientId,
    items: [{ garment_type: 'Chemise', quantity: 1, unit_price: 30000 }],
  })).body.id;
  await asM(request(app).put(`/api/orders/${orderId}`)).send({ status: 'livre' });

  const after = (await asM(request(app).get(url))).body;

  expect(after.clients.new - before.clients.new).toBe(1);
  expect(after.clients.served - before.clients.served).toBe(1);
  expect(after.orders.delivered - before.orders.delivered).toBe(1);
  expect(after.revenue.orders - before.revenue.orders).toBe(30000);
  expect(after.net_profit).toBe(after.revenue.total - after.costs.total);
});

test('top tailors ranking reflects the window wages', async () => {
  const from = '2026-10-01';
  const to = '2026-10-31';
  const tailorId = (await asM(request(app).post('/api/staff')).send({
    full_name: 'Rapport Tailleur', phone: '76009000', type: 'couturier',
  })).body.id;
  await asM(request(app).put(`/api/staff-pay/${tailorId}`)).send({ piece_rate: 5000 });
  await asM(request(app).post('/api/tailor-entries')).send({
    tailor_id: tailorId, entry_date: '2026-10-15', pieces_count: 4,
    piece_rate: 5000, garment_type: 'Chemise',
  });

  const b = (await asM(request(app).get(`/api/reports/summary?from=${from}&to=${to}`))).body;
  expect(b.costs.tailor_wages).toBeGreaterThanOrEqual(4 * 5000);
  const mine = b.top_tailors.find((t) => t.tailor_id === tailorId);
  expect(mine).toBeTruthy();
  expect(mine.amount_total).toBe(4 * 5000);
  expect(b.net_profit).toBe(b.revenue.total - b.costs.total);
});
