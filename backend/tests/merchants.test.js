// =============================================================================
// Integration tests for Weekly Staff Salaries, Supplier Credit & Wholesale Orders
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

afterAll(async () => {
  await db.closePool();
});

describe('Weekly Staff Pay & Frequency', () => {
  test('Manager can set weekly_salary and pay_frequency on staff_pay', async () => {
    const staffId = (await asM(request(app).post('/api/staff'))
      .send({ full_name: 'Agent de Securite', type: 'autre' })).body.id;

    const setPay = await asM(request(app).put(`/api/staff-pay/${staffId}`))
      .send({ piece_rate: 0, monthly_salary: 0, salary_due_day: 1, weekly_salary: 15000, pay_frequency: 'hebdo' });
    expect(setPay.status).toBe(200);
    expect(setPay.body.weekly_salary).toBe(15000);
    expect(setPay.body.pay_frequency).toBe('hebdo');

    // Pay weekly salary
    const payRes = await asM(request(app).post('/api/salary-payments'))
      .send({ staff_id: staffId, period: '2026-W30', kind: 'hebdo', amount: 15000 });
    expect(payRes.status).toBe(201);
    expect(payRes.body.kind).toBe('hebdo');
    expect(payRes.body.period).toBe('2026-W30');

    // Secretary is blocked from suppliers (403)
    expect((await asSec(request(app).get('/api/suppliers'))).status).toBe(403);
  });
});

describe('Supplier Credit & Purchases', () => {
  test('Manager can manage suppliers, credit purchases, and append-only payments', async () => {
    // Create supplier
    const supp = await asM(request(app).post('/api/suppliers'))
      .send({ name: 'Grand Commerçant Bazin', phone: '70001122' });
    expect(supp.status).toBe(201);
    const suppId = supp.body.id;

    // Create credit purchase: total 100,000 FCFA, advance 30,000 FCFA -> reste 70,000
    const pur = await asM(request(app).post('/api/suppliers/purchases'))
      .send({ supplier_id: suppId, description: '10 Rouleaux Bazin Getzner', total_amount: 100000, advance_amount: 30000 });
    expect(pur.status).toBe(201);
    const purId = pur.body.id;

    // Verify derived reste
    const purGet = await asM(request(app).get(`/api/suppliers/purchases/${purId}`));
    expect(purGet.body.reste).toBe(70000);

    // Make an installment payment of 40,000 FCFA -> reste becomes 30,000 FCFA
    const pay = await asM(request(app).post(`/api/suppliers/purchases/${purId}/payments`))
      .send({ amount: 40000, note: 'Acompte 2' });
    expect(pay.status).toBe(201);

    const purGetAfter = await asM(request(app).get(`/api/suppliers/purchases/${purId}`));
    expect(purGetAfter.body.paid_total).toBe(40000);
    expect(purGetAfter.body.reste).toBe(30000);
  });
});

describe('Wholesale Orders to Merchants', () => {
  test('Wholesale orders allow installment payments and status tracking', async () => {
    const order = await asM(request(app).post('/api/wholesale/orders'))
      .send({
        merchant_name: 'Boutique Sylla & Frères',
        merchant_phone: '76112233',
        items: [{ model: 'Kaftan Homme', qty: 5, unit_price: 20000 }],
        total_amount: 100000,
        advance_amount: 50000,
      });
    expect(order.status).toBe(201);
    const orderId = order.body.id;

    // Pay remaining installment of 50,000 FCFA
    const pay = await asM(request(app).post(`/api/wholesale/orders/${orderId}/payments`))
      .send({ amount: 50000, note: 'Règlement solde' });
    expect(pay.status).toBe(201);

    const ordGet = await asM(request(app).get(`/api/wholesale/orders/${orderId}`));
    expect(ordGet.body.reste).toBe(0);

    // Deleting wholesale order with existing payments -> 409 (append-only payment records protected)
    expect((await asM(request(app).delete(`/api/wholesale/orders/${orderId}`))).status).toBe(409);

    // Create empty order and delete as manager -> 204
    const emptyOrder = await asM(request(app).post('/api/wholesale/orders'))
      .send({ merchant_name: 'Test Temp', total_amount: 10000 });
    expect((await asM(request(app).delete(`/api/wholesale/orders/${emptyOrder.body.id}`))).status).toBe(204);
  });

  // Wholesale exposes money (total, paid, outstanding balance), so it is
  // manager-only like every other revenue module — owner decision 2026-08-03.
  test('secretary is blocked from every wholesale route (403)', async () => {
    expect((await asSec(request(app).get('/api/wholesale/orders'))).status).toBe(403);
    expect((await asSec(request(app).post('/api/wholesale/orders'))
      .send({ merchant_name: 'X', total_amount: 1000 })).status).toBe(403);

    const own = await asM(request(app).post('/api/wholesale/orders'))
      .send({ merchant_name: 'Interdit à la secrétaire', total_amount: 5000 });
    expect((await asSec(request(app).get(`/api/wholesale/orders/${own.body.id}`))).status).toBe(403);
    expect((await asSec(request(app).post(`/api/wholesale/orders/${own.body.id}/payments`))
      .send({ amount: 1000 })).status).toBe(403);
    expect((await asSec(request(app).delete(`/api/wholesale/orders/${own.body.id}`))).status).toBe(403);
  });
});
