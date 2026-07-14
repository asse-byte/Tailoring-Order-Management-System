// =============================================================================
// Item 4 — production scheduling: planned_date (programme) + waiting queue.
// =============================================================================

const request = require('supertest');
const { createApp } = require('../src/app');
const db = require('../src/db');
const { MANAGER, SECRETARY, seedUsers, login } = require('./helpers');

let app;
let mToken;
let sToken;
let clientId;
let orderId;
const asM = (r) => r.set('Authorization', `Bearer ${mToken}`);
const asS = (r) => r.set('Authorization', `Bearer ${sToken}`);

beforeAll(async () => {
  app = createApp();
  await seedUsers();
  mToken = await login(app, MANAGER);
  sToken = await login(app, SECRETARY);
  clientId = (await asM(request(app).post('/api/clients'))
    .send({ full_name: 'Programme Client', phone: '75000500' })).body.id;
  orderId = (await asM(request(app).post('/api/orders')).send({
    client_id: clientId,
    items: [{ garment_type: 'Chemise', quantity: 1, unit_price: 15000 }],
  })).body.id;
});

afterAll(async () => { await db.closePool(); });

test('a new order starts in the waiting queue (unplanned)', async () => {
  const res = await asM(request(app).get('/api/orders?unplanned=1'));
  expect(res.status).toBe(200);
  expect(res.body.items.some((o) => o.id === orderId)).toBe(true);
  const mine = res.body.items.find((o) => o.id === orderId);
  expect(mine.planned_date).toBeNull();
});

test('planning an order puts it on that day and out of the queue', async () => {
  const plan = await asS(request(app).put(`/api/orders/${orderId}/plan`))
    .send({ planned_date: '2026-07-20' }); // secretary can schedule (operational)
  expect(plan.status).toBe(200);
  // pg returns `date` columns as an ISO datetime string (like every other
  // order date); the Flutter side parses it fine. Assert the date part.
  expect(plan.body.planned_date.startsWith('2026-07-20')).toBe(true);

  const day = await asM(request(app)
    .get('/api/orders?planned_from=2026-07-20&planned_to=2026-07-20'));
  expect(day.body.items.some((o) => o.id === orderId)).toBe(true);

  const queue = await asM(request(app).get('/api/orders?unplanned=1'));
  expect(queue.body.items.some((o) => o.id === orderId)).toBe(false);

  // Outside the planned range → not returned.
  const other = await asM(request(app)
    .get('/api/orders?planned_from=2026-07-21&planned_to=2026-07-25'));
  expect(other.body.items.some((o) => o.id === orderId)).toBe(false);
});

test('clearing the plan returns the order to the queue', async () => {
  const clear = await asM(request(app).put(`/api/orders/${orderId}/plan`))
    .send({ planned_date: null });
  expect(clear.status).toBe(200);
  expect(clear.body.planned_date).toBeNull();

  const queue = await asM(request(app).get('/api/orders?unplanned=1'));
  expect(queue.body.items.some((o) => o.id === orderId)).toBe(true);
});

test('an invalid planned_date is rejected', async () => {
  const res = await asM(request(app).put(`/api/orders/${orderId}/plan`))
    .send({ planned_date: '20-07-2026' });
  expect(res.status).toBe(400);
});
