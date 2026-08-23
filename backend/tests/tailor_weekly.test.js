// =============================================================================
// Item 6 — itemised tailor daily entries (garment type + optional order link)
// and the per-tailor weekly detail used by the "Tailleurs" screen.
// =============================================================================

const request = require('supertest');
const { createApp } = require('../src/app');
const db = require('../src/db');
const { MANAGER, seedUsers, login } = require('./helpers');

let app;
let token;
let tailorId;
let clientId;
let orderId;
const asM = (r) => r.set('Authorization', `Bearer ${token}`);

beforeAll(async () => {
  app = createApp();
  await seedUsers();
  token = await login(app, MANAGER);
  tailorId = (await asM(request(app).post('/api/staff'))
    .send({ full_name: 'Salif Traoré', phone: '76000010', type: 'couturier' })).body.id;
  clientId = (await asM(request(app).post('/api/clients'))
    .send({ full_name: 'Awa Sow', phone: '75000010' })).body.id;
  orderId = (await asM(request(app).post('/api/orders')).send({
    client_id: clientId,
    tailor_id: tailorId,
    items: [{ garment_type: 'Grand Boubou', quantity: 1, unit_price: 20000 }],
  })).body.id;
});

afterAll(async () => { await db.closePool(); });

test('multiple itemised entries on the same day, linked to a client order', async () => {
  // Two garment lines on the SAME day for the same tailor (old one-per-day
  // rule is gone). One is linked to an order → client name derived.
  const e1 = await asM(request(app).post('/api/tailor-entries')).send({
    tailor_id: tailorId, entry_date: '2026-07-06', pieces_count: 3,
    piece_rate: 5000, garment_type: 'Grand Boubou', order_id: orderId,
  });
  expect(e1.status).toBe(201);
  const e2 = await asM(request(app).post('/api/tailor-entries')).send({
    tailor_id: tailorId, entry_date: '2026-07-06', pieces_count: 2,
    piece_rate: 4000, garment_type: 'Chemise',
  });
  expect(e2.status).toBe(201);
  const weekId = e1.body.week_id; // derived by the server from the date

  // Weekly detail groups them; total = 3×5000 + 2×4000 = 23,000.
  const detail = await asM(request(app)
    .get(`/api/tailor-entries/weekly-detail?week_id=${weekId}&tailor_id=${tailorId}`));
  expect(detail.status).toBe(200);
  expect(detail.body.total).toBe(23000);
  expect(detail.body.items).toHaveLength(2);

  const boubou = detail.body.items.find((i) => i.garment_type === 'Grand Boubou');
  expect(boubou.client_name).toBe('Awa Sow'); // derived from the linked order
  expect(boubou.pieces_count).toBe(3);
  const chemise = detail.body.items.find((i) => i.garment_type === 'Chemise');
  expect(chemise.client_name).toBeNull(); // no order linked
});

test('weekly-detail requires week_id and tailor_id', async () => {
  expect((await asM(request(app).get('/api/tailor-entries/weekly-detail'))).status)
    .toBe(400);
});

test('monthly ranking totals per tailor, highest-first', async () => {
  // A second tailor with a smaller July total, so ordering is observable.
  const t2 = (await asM(request(app).post('/api/staff'))
    .send({ full_name: 'Bakary Coulibaly', phone: '76000011', type: 'couturier' })).body.id;
  await asM(request(app).post('/api/tailor-entries')).send({
    tailor_id: t2, entry_date: '2026-07-08', pieces_count: 1,
    piece_rate: 3000, garment_type: 'Chemise',
  });

  const bad = await asM(request(app).get('/api/tailor-entries/monthly'));
  expect(bad.status).toBe(400); // month is required

  const res = await asM(request(app)
    .get('/api/tailor-entries/monthly?month=2026-07'));
  expect(res.status).toBe(200);
  expect(res.body.month).toBe('2026-07');

  const salif = res.body.items.find((r) => r.tailor_id === tailorId);
  const bakary = res.body.items.find((r) => r.tailor_id === t2);
  // Salif: 3×5000 + 2×4000 = 23,000 (July) ; Bakary: 1×3000 = 3,000.
  expect(salif.amount_total).toBe(23000);
  expect(salif.days_worked).toBe(1);
  expect(bakary.amount_total).toBe(3000);
  // Ranked highest-first → Salif appears before Bakary.
  const iSalif = res.body.items.findIndex((r) => r.tailor_id === tailorId);
  const iBakary = res.body.items.findIndex((r) => r.tailor_id === t2);
  expect(iSalif).toBeLessThan(iBakary);
});

// ---------------------------------------------------------------------------
// The shop-wide default piece rate is gone (migration 027, owner decision
// 2026-08-23). The rate chain is now two links, and a tailor with no rate is
// an explicit error rather than a silent fallback to a forgotten number.
// ---------------------------------------------------------------------------
test('a tailor with no piece rate is refused, not silently defaulted', async () => {
  const staffId = (await asM(request(app).post('/api/staff'))
    .send({ full_name: 'Couturier Sans Tarif', phone: '76555001', type: 'couturier' })).body.id;

  const res = await asM(request(app).post('/api/tailor-entries'))
    .send({ tailor_id: staffId, entry_date: '2026-06-01', pieces_count: 3 });
  expect(res.status).toBe(400);
  expect(res.body.error).toMatch(/prix par pièce/i);

  // The setting itself no longer exists anywhere.
  const { rows } = await db.query(
    "SELECT 1 FROM settings WHERE key = 'default_piece_rate'");
  expect(rows).toHaveLength(0);
});

test('the rate typed on the entry still wins over the tailor’s own rate', async () => {
  const staffId = (await asM(request(app).post('/api/staff'))
    .send({ full_name: 'Couturier Deux Tarifs', phone: '76555002', type: 'couturier' })).body.id;
  await asM(request(app).put(`/api/staff-pay/${staffId}`)).send({ piece_rate: 2000 });

  // No rate given → the tailor's own 2 000 applies.
  const a = await asM(request(app).post('/api/tailor-entries'))
    .send({ tailor_id: staffId, entry_date: '2026-06-02', pieces_count: 2 });
  expect(a.status).toBe(201);
  expect(a.body.piece_rate).toBe(2000);

  // A rate typed for this garment overrides it.
  const b = await asM(request(app).post('/api/tailor-entries'))
    .send({ tailor_id: staffId, entry_date: '2026-06-02', pieces_count: 1, piece_rate: 7500 });
  expect(b.status).toBe(201);
  expect(b.body.piece_rate).toBe(7500);
});
