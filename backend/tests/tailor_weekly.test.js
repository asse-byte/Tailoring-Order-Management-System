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
