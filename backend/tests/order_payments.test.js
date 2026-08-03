// =============================================================================
// Order cash payments — append-only guarantees + cash-basis revenue.
// =============================================================================
// Migration 016 made tailoring revenue cash-basis (sum of order_payments) but
// only ever wrote a payment row when an advance was set. A shop that takes no
// advance and is paid in full at hand-over therefore saw ZERO tailoring
// revenue, no matter how many orders it delivered — the bug reported for
// 72 Couture and equally present for Rayan Couture.
//
// These tests pin both halves of the fix (migration 018):
//   * delivery captures the outstanding balance as collected cash;
//   * order_payments is append-only like every other financial table.
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

const today = new Date().toISOString().slice(0, 10);

beforeAll(async () => {
  app = createApp();
  await seedUsers();
  managerToken = await login(app, MANAGER);
  secToken = await login(app, SECRETARY);
});

afterAll(async () => {
  await db.closePool();
});

/** Tailoring-order revenue for today, from the manager's finance summary. */
async function orderRevenue() {
  const res = await asM(request(app).get(`/api/finance/summary?from=${today}&to=${today}`));
  return res.body.revenue.orders;
}

async function newClient(name) {
  const res = await asM(request(app).post('/api/clients'))
    .send({ full_name: name, phone: '70000000' });
  return res.body.id;
}

async function newOrder(clientId, price, advance) {
  const res = await asM(request(app).post('/api/orders')).send({
    client_id: clientId,
    items: [{ garment_type: 'Grand Boubou', quantity: 1, unit_price: price }],
    advance,
    expected_date: today,
  });
  expect(res.status).toBe(201);
  return res.body.id;
}

describe('Cash-basis tailoring revenue', () => {
  test('an order paid entirely at delivery IS counted (the 72 Couture bug)', async () => {
    const clientId = await newClient('Client sans acompte');
    const before = await orderRevenue();

    // No advance at all — nothing is collected yet, so nothing is counted.
    const orderId = await newOrder(clientId, 50000, 0);
    expect(await orderRevenue()).toBe(before);

    // Hand-over: the client pays the full 50 000 and it must land in revenue.
    const upd = await asM(request(app).put(`/api/orders/${orderId}`)).send({ status: 'livre' });
    expect(upd.status).toBe(200);
    expect(await orderRevenue()).toBe(before + 50000);
  });

  test('an advance is counted once, and delivery only adds the remaining balance', async () => {
    const clientId = await newClient('Client avec acompte');
    const before = await orderRevenue();

    const orderId = await newOrder(clientId, 80000, 30000);
    expect(await orderRevenue()).toBe(before + 30000);

    await asM(request(app).put(`/api/orders/${orderId}`)).send({ status: 'livre' });
    // 30 000 already in + 50 000 balance = the order's full price, never double.
    expect(await orderRevenue()).toBe(before + 80000);
  });

  test('delivering an already fully-paid order adds nothing', async () => {
    const clientId = await newClient('Client payé davance');
    const orderId = await newOrder(clientId, 40000, 40000);
    const afterAdvance = await orderRevenue();

    await asM(request(app).put(`/api/orders/${orderId}`)).send({ status: 'livre' });
    expect(await orderRevenue()).toBe(afterAdvance);
  });

  test('lowering an advance corrects the cash down without a negative row', async () => {
    const clientId = await newClient('Client acompte corrigé');
    const before = await orderRevenue();
    const orderId = await newOrder(clientId, 60000, 25000);
    expect(await orderRevenue()).toBe(before + 25000);

    // Typing mistake: it was really 10 000.
    const upd = await asM(request(app).put(`/api/orders/${orderId}`)).send({ advance: 10000 });
    expect(upd.status).toBe(200);
    expect(await orderRevenue()).toBe(before + 10000);

    // The correction is a correction row — no negative payment was ever stored.
    const { rows } = await db.query(
      'SELECT amount FROM order_payments WHERE order_id = $1 ORDER BY created_at', [orderId]);
    expect(rows.every((r) => Number(r.amount) > 0)).toBe(true);
  });
});

describe('order_payments is append-only (PROJECT PRINCIPLE)', () => {
  let orderId;

  beforeAll(async () => {
    const clientId = await newClient('Client append-only');
    orderId = await newOrder(clientId, 20000, 20000);
  });

  test('UPDATE on a payment row is refused by the database', async () => {
    await expect(
      db.query('UPDATE order_payments SET amount = 1 WHERE order_id = $1', [orderId])
    ).rejects.toThrow(/append-only/i);
  });

  test('DELETE on a payment row is refused by the database', async () => {
    await expect(
      db.query('DELETE FROM order_payments WHERE order_id = $1', [orderId])
    ).rejects.toThrow(/append-only/i);
  });

  test('a negative payment amount is refused by the CHECK constraint', async () => {
    await expect(
      db.query(
        `INSERT INTO order_payments (order_id, amount, paid_at) VALUES ($1, -500, CURRENT_DATE)`,
        [orderId])
    ).rejects.toThrow();
  });

  test('deleting the order can never erase the cash it collected', async () => {
    // The FK is ON DELETE RESTRICT now, so even a raw delete cannot cascade
    // the payment history away.
    await expect(
      db.query('DELETE FROM orders WHERE id = $1', [orderId])
    ).rejects.toThrow();
  });
});

describe('Cancelling an order (archive, never a hard delete)', () => {
  test('cancel keeps line items, collected cash and history intact', async () => {
    const clientId = await newClient('Client commande annulée');
    const before = await orderRevenue();
    const orderId = await newOrder(clientId, 45000, 15000);
    expect(await orderRevenue()).toBe(before + 15000);

    const del = await asM(request(app).delete(`/api/orders/${orderId}`))
      .send({ reason: 'Client a changé davis' });
    expect(del.status).toBe(204);

    // Gone from the active list…
    const list = await asM(request(app).get('/api/orders'));
    expect(list.body.items.find((o) => o.id === orderId)).toBeUndefined();

    // …but the row, its items and its cash are all still there.
    const still = await asM(request(app).get(`/api/orders/${orderId}`));
    expect(still.status).toBe(200);
    expect(still.body.status).toBe('annule');
    expect(still.body.items.length).toBe(1);
    expect(await orderRevenue()).toBe(before + 15000);

    const { rows } = await db.query(
      'SELECT COUNT(*)::int AS n FROM order_items WHERE order_id = $1', [orderId]);
    expect(rows[0].n).toBe(1);
  });

  test('the secretary cannot cancel an order', async () => {
    const clientId = await newClient('Client secrétaire');
    const orderId = await newOrder(clientId, 10000, 0);
    expect((await asSec(request(app).delete(`/api/orders/${orderId}`))).status).toBe(403);
  });

  test('append-only protection is still active after a cancel', async () => {
    // Regression guard: the old delete route ran ALTER TABLE ... DISABLE
    // TRIGGER, which switched protection off table-wide for every connection
    // and could leave it off if the re-enable failed.
    const clientId = await newClient('Client trigger vivant');
    const orderId = await newOrder(clientId, 12000, 0);
    await asM(request(app).delete(`/api/orders/${orderId}`));

    const { rows } = await db.query(
      'SELECT id FROM order_items WHERE order_id = $1', [orderId]);
    await expect(
      db.query('DELETE FROM order_items WHERE id = $1', [rows[0].id])
    ).rejects.toThrow(/append-only/i);
  });
});
