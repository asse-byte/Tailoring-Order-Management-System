// =============================================================================
// Item 2 — Commandes with multiple line items + append-only corrections.
// Proves totals are derived from the effective items, corrections/voids move
// the total, the order links to a tailor, and delivered revenue reads the
// items total.
// =============================================================================

const request = require('supertest');
const { createApp } = require('../src/app');
const db = require('../src/db');
const { MANAGER, seedUsers, login } = require('./helpers');

let app;
let token;
let clientId;
let tailorId;
const asM = (r) => r.set('Authorization', `Bearer ${token}`);

beforeAll(async () => {
  app = createApp();
  await seedUsers();
  token = await login(app, MANAGER);
  clientId = (await asM(request(app).post('/api/clients'))
    .send({ full_name: 'Fatou Diarra', phone: '75000001' })).body.id;
  tailorId = (await asM(request(app).post('/api/staff'))
    .send({ full_name: 'Ibrahim Coulibaly', phone: '76000001', type: 'couturier' })).body.id;
});

afterAll(async () => { await db.closePool(); });

async function summary() {
  return (await asM(request(app).get('/api/finance/summary'))).body;
}

test('order total is the sum of its line items, with a tailor link', async () => {
  const res = await asM(request(app).post('/api/orders')).send({
    client_id: clientId,
    tailor_id: tailorId,
    items: [
      { garment_type: 'Grand Boubou', quantity: 2, unit_price: 15000 },
      { garment_type: 'Chemise', quantity: 1, unit_price: 8000 },
    ],
  });
  expect(res.status).toBe(201);
  expect(res.body.total).toBe(2 * 15000 + 8000); // 38,000
  expect(res.body.items).toHaveLength(2);
  expect(res.body.tailor_name).toBe('Ibrahim Coulibaly');
  expect(res.body.status).toBe('en_attente');
});

test('adding a line, correcting one, and voiding another moves the total', async () => {
  const order = (await asM(request(app).post('/api/orders')).send({
    client_id: clientId,
    items: [{ garment_type: 'Veste', quantity: 1, unit_price: 20000 }],
  })).body;
  expect(order.total).toBe(20000);
  const firstItem = order.items[0].id;

  // Add a second line.
  let updated = (await asM(request(app).post(`/api/orders/${order.id}/items`))
    .send({ garment_type: 'Pantalon-less test', quantity: 3, unit_price: 5000 })).body;
  expect(updated.total).toBe(20000 + 15000); // 35,000
  const secondItem = updated.items.find((i) => i.id !== firstItem).id;

  // Correction requires a reason.
  expect((await asM(request(app).post(`/api/orders/${order.id}/items/${firstItem}/corrections`))
    .send({ new_unit_price: 25000 })).status).toBe(400);

  // Correct the first line's price 20000 → 25000.
  updated = (await asM(request(app).post(`/api/orders/${order.id}/items/${firstItem}/corrections`))
    .send({ new_unit_price: 25000, reason: 'Tissu plus cher' })).body;
  expect(updated.total).toBe(25000 + 15000); // 40,000

  // Void the second line.
  updated = (await asM(request(app).post(`/api/orders/${order.id}/items/${secondItem}/corrections`))
    .send({ voided: true, reason: 'Article retiré' })).body;
  expect(updated.total).toBe(25000); // only the first line remains
  const voided = updated.items.find((i) => i.id === secondItem);
  expect(voided.voided).toBe(true);

  // The correction history is queryable.
  const hist = await asM(request(app).get(`/api/orders/${order.id}/items/${firstItem}/corrections`));
  expect(hist.body.items).toHaveLength(1);
  expect(hist.body.items[0].reason).toBe('Tissu plus cher');
});

test('delivered order revenue equals its items total; same-day orders allowed', async () => {
  const before = await summary();

  // Two orders for the same client on the same day (no unique constraint).
  const o1 = (await asM(request(app).post('/api/orders')).send({
    client_id: clientId,
    items: [{ garment_type: 'Grand Boubou', quantity: 1, unit_price: 30000 }],
  })).body;
  const o2 = (await asM(request(app).post('/api/orders')).send({
    client_id: clientId,
    items: [{ garment_type: 'Création', quantity: 1, unit_price: 12000 }],
  })).body;
  expect(o1.id).not.toBe(o2.id);

  // Deliver both.
  for (const o of [o1, o2]) {
    const put = await asM(request(app).put(`/api/orders/${o.id}`)).send({ status: 'livre' });
    expect(put.status).toBe(200);
    expect(put.body.delivered_date).not.toBeNull();
  }

  const after = await summary();
  expect(after.revenue.orders - before.revenue.orders).toBe(30000 + 12000);
});
