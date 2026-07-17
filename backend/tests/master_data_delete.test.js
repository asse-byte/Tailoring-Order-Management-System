// =============================================================================
// Type-A master data (staff, clients, products) is FULLY deletable by the
// manager, while Type-B financial history stays intact via name snapshots.
//
// The critical invariant: deleting a tailor who has past wage entries must NOT
// change any historical financial total by a single franc — the money lives in
// the append-only entries (snapshotted name, no FK), not in the staff row.
//
// Also covers the standalone security fix: DELETE /api/clients must be
// manager-only (it was unprotected before this batch).
// =============================================================================

const request = require('supertest');
const { createApp } = require('../src/app');
const db = require('../src/db');
const { MANAGER, SECRETARY, seedUsers, login } = require('./helpers');

let app;
let managerToken;
let secToken;
const asM = (r) => r.set('Authorization', `Bearer ${managerToken}`);
const asSec = (r) => r.set('Authorization', `Bearer ${secToken}`);

beforeAll(async () => {
  app = createApp();
  await seedUsers();
  managerToken = await login(app, MANAGER);
  secToken = await login(app, SECRETARY);
});

afterAll(async () => { await db.closePool(); });

test('deleting a tailor with past wages leaves the weekly total unchanged', async () => {
  const tailorId = (await asM(request(app).post('/api/staff'))
    .send({ full_name: 'Ibrahim Diarra', phone: '76001000', type: 'couturier' })).body.id;
  // Two entries in the same ISO week: 3×5000 + 2×4000 = 23,000.
  const e1 = await asM(request(app).post('/api/tailor-entries')).send({
    tailor_id: tailorId, entry_date: '2026-07-06', pieces_count: 3,
    piece_rate: 5000, garment_type: 'Grand Boubou',
  });
  await asM(request(app).post('/api/tailor-entries')).send({
    tailor_id: tailorId, entry_date: '2026-07-07', pieces_count: 2,
    piece_rate: 4000, garment_type: 'Chemise',
  });
  const weekId = e1.body.week_id;

  const before = await asM(request(app)
    .get(`/api/tailor-entries/weekly?week_id=${weekId}`));
  const rowBefore = before.body.items.find((r) => r.tailor_id === tailorId);
  expect(rowBefore.amount_total).toBe(23000);
  expect(rowBefore.tailor_name).toBe('Ibrahim Diarra');

  // Hard-delete the tailor.
  const del = await asM(request(app).delete(`/api/staff/${tailorId}`));
  expect(del.status).toBe(204);

  // Gone from the active staff list…
  const staff = await asM(request(app).get('/api/staff'));
  expect(staff.body.items.find((s) => s.id === tailorId)).toBeUndefined();

  // …but the weekly financial total is byte-for-byte identical, now shown by
  // the snapshotted name and flagged as a former employee.
  const after = await asM(request(app)
    .get(`/api/tailor-entries/weekly?week_id=${weekId}`));
  const rowAfter = after.body.items.find((r) => r.tailor_id === tailorId);
  expect(rowAfter.amount_total).toBe(23000);
  expect(rowAfter.tailor_name).toBe('Ibrahim Diarra');
  expect(rowAfter.tailor_deleted).toBe(true);

  // And the finance wage total for that period is unchanged too.
  const fin = await asM(request(app)
    .get('/api/finance/summary?from=2026-07-06&to=2026-07-12'));
  expect(fin.body.costs.tailor_wages).toBe(23000);
});

test('deleting a client keeps their delivered order in Historique by snapshot', async () => {
  const clientId = (await asM(request(app).post('/api/clients'))
    .send({ full_name: 'Fatoumata Ba', phone: '75002000' })).body.id;
  const orderId = (await asM(request(app).post('/api/orders')).send({
    client_id: clientId,
    items: [{ garment_type: 'Grand Boubou', quantity: 1, unit_price: 30000 }],
  })).body.id;
  // Deliver it (moves to Historique).
  await asM(request(app).put(`/api/orders/${orderId}`)).send({ status: 'livre' });

  const del = await asM(request(app).delete(`/api/clients/${clientId}`));
  expect(del.status).toBe(204);

  const order = await asM(request(app).get(`/api/orders/${orderId}`));
  expect(order.status).toBe(200);
  expect(order.body.client_name).toBe('Fatoumata Ba'); // snapshot survives
  expect(order.body.client_deleted).toBe(true);
  expect(order.body.total).toBe(30000);              // total unchanged
});

test('deleting a product keeps its past sales intact (name + total)', async () => {
  const productId = (await asM(request(app).post('/api/products'))
    .send({ category: 'tissu', name: 'Bazin getzner', price: 12000, quantity: 5 })).body.id;
  await asM(request(app).post('/api/sales'))
    .send({ kind: 'produit', item_id: productId, qty: 2 });

  const del = await asM(request(app).delete(`/api/products/${productId}`));
  expect(del.status).toBe(204);

  const sales = await asM(request(app).get('/api/sales'));
  const row = sales.body.items.find((s) => s.item_name === 'Bazin getzner');
  expect(row).toBeDefined();
  expect(row.total).toBe(24000); // 2 × 12,000, unchanged after product delete
});

// ---- Security: every Type-A delete is manager-only (403 for the secretary) ---

describe('secretary is forbidden (403) from deleting any master data', () => {
  let clientId; let staffId; let productId; let modelId;
  beforeAll(async () => {
    clientId = (await asM(request(app).post('/api/clients'))
      .send({ full_name: 'Sékou Camara', phone: '75003000' })).body.id;
    staffId = (await asM(request(app).post('/api/staff'))
      .send({ full_name: 'Oumar Sidibé', phone: '76003000', type: 'autre' })).body.id;
    productId = (await asM(request(app).post('/api/products'))
      .send({ category: 'parfum', name: 'Oud', price: 8000, quantity: 3 })).body.id;
    modelId = (await asM(request(app).post('/api/pret-a-porter'))
      .send({ name: 'Kaftan', fabric_type: 'soie', price: 40000 })).body.id;
  });

  // SECURITY FIX (separate from the feature): DELETE /clients was unprotected.
  test('DELETE /api/clients with a secretary token → 403', async () => {
    const res = await asSec(request(app).delete(`/api/clients/${clientId}`));
    expect(res.status).toBe(403);
    // Still there when the manager looks.
    expect((await asM(request(app).get(`/api/clients/${clientId}`))).status).toBe(200);
  });

  test('DELETE /api/staff with a secretary token → 403', async () => {
    expect((await asSec(request(app).delete(`/api/staff/${staffId}`))).status).toBe(403);
  });
  test('DELETE /api/products with a secretary token → 403', async () => {
    expect((await asSec(request(app).delete(`/api/products/${productId}`))).status).toBe(403);
  });
  test('DELETE /api/pret-a-porter with a secretary token → 403', async () => {
    expect((await asSec(request(app).delete(`/api/pret-a-porter/${modelId}`))).status).toBe(403);
  });
});
