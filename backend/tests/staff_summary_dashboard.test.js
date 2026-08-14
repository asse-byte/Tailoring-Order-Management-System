// =============================================================================
// New surfaces: all-time staff sheet, dashboard KPIs, unpaid-order reminders.
// =============================================================================
// Follows the baseline→after DELTA style of reports.test.js: the suite shares
// one database and runs --runInBand, so absolute counts from other files are
// never asserted — only the movement this file causes.
//
// Fixture names/phones carry a QWX / 9955 marker used nowhere else in
// backend/tests, so Jest file ordering cannot make these assertions flap.
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

let tailorId;
let monthlyId;

beforeAll(async () => {
  app = createApp();
  await seedUsers();
  mToken = await login(app, MANAGER);
  sToken = await login(app, SECRETARY);

  tailorId = (await asM(request(app).post('/api/staff')).send({
    full_name: 'QWX Couturier', phone: '99551001', type: 'couturier',
  })).body.id;
  monthlyId = (await asM(request(app).post('/api/staff')).send({
    full_name: 'QWX Mensuel', phone: '99551002', type: 'autre',
  })).body.id;

  // Piece work in 2027 — the year security.test.js and entry_corrections.test.js
  // already use to stay clear of the exact 2026 finance windows other suites
  // assert on (July in security.test.js, October in reports.test.js).
  for (const [date, pieces, rate, garment] of [
    ['2027-11-03', 3, 4000, 'Chemise'],
    ['2027-11-04', 2, 6000, 'Veste'],
    ['2027-11-05', 1, 4000, 'Chemise'],
  ]) {
    await asM(request(app).post('/api/tailor-entries')).send({
      tailor_id: tailorId, entry_date: date, pieces_count: pieces,
      piece_rate: rate, garment_type: garment,
    });
  }
  // 3×4000 + 2×6000 + 1×4000 = 28 000 across 3 days, 6 pieces.
});

afterAll(async () => { await db.closePool(); });

// ---------------------------------------------------------------------------
describe('GET /api/staff/:id/all-time-summary', () => {
  test('manager sees pieces, earnings, per-garment split and the net balance', async () => {
    const res = await asM(request(app).get(`/api/staff/${tailorId}/all-time-summary`));
    expect(res.status).toBe(200);
    expect(res.body.staff.full_name).toBe('QWX Couturier');
    expect(res.body.pieces_total).toBe(6);
    expect(res.body.earned_total).toBe(28000);
    expect(res.body.days_worked).toBe(3);
    expect(res.body.first_entry_date).toContain('2027-11-03');
    expect(res.body.last_entry_date).toContain('2027-11-05');

    // Per-model breakdown, ordered by amount desc: Veste 12000, Chemise 16000.
    const byGarment = Object.fromEntries(
      res.body.by_garment.map((g) => [g.garment_type, g]));
    expect(byGarment.Chemise).toEqual({ garment_type: 'Chemise', pieces: 4, amount: 16000 });
    expect(byGarment.Veste).toEqual({ garment_type: 'Veste', pieces: 2, amount: 12000 });

    // Nothing paid yet → the shop owes the full amount.
    expect(res.body.salary_paid_total).toBe(0);
    expect(res.body.net_balance).toBe(28000);
  });

  test('a salary payment lowers the net balance by exactly that amount', async () => {
    // paid_at is pinned to 2027 on purpose. finance.js charges
    // max(actualSalaryPaid, proratedSalaries), so a payment landing inside a
    // window another suite asserts on makes that suite's delta non-linear —
    // finance_salary_proration.test.js fails intermittently otherwise. 2027 is
    // already this suite's convention for "outside every asserted window".
    await asM(request(app).post('/api/salary-payments')).send({
      staff_id: tailorId, period: '2027-W46', kind: 'hebdo', amount: 10000,
      paid_at: '2027-11-15',
    });
    const res = await asM(request(app).get(`/api/staff/${tailorId}/all-time-summary`));
    expect(res.body.salary_paid_total).toBe(10000);
    expect(res.body.net_balance).toBe(18000);
    expect(res.body.earned_total).toBe(28000); // earnings untouched by a payment
  });

  test('a voided entry correction removes its pieces and francs', async () => {
    const entryId = (await asM(request(app).post('/api/tailor-entries')).send({
      tailor_id: tailorId, entry_date: '2027-11-06', pieces_count: 5,
      piece_rate: 1000, garment_type: 'Boubou',
    })).body.id;

    const withEntry = (await asM(
      request(app).get(`/api/staff/${tailorId}/all-time-summary`))).body;
    expect(withEntry.earned_total).toBe(33000);

    await asM(request(app).post(`/api/tailor-entries/${entryId}/corrections`)).send({
      voided: true, reason: 'Saisie erronée (test)',
    });

    const after = (await asM(
      request(app).get(`/api/staff/${tailorId}/all-time-summary`))).body;
    expect(after.earned_total).toBe(28000);
    expect(after.pieces_total).toBe(6);
    // The voided garment disappears from the breakdown entirely.
    expect(after.by_garment.map((g) => g.garment_type)).not.toContain('Boubou');
  });

  test('secretary sees a tailor performance but NEVER the salary side', async () => {
    const res = await asS(request(app).get(`/api/staff/${tailorId}/all-time-summary`));
    expect(res.status).toBe(200);
    // The piece-rate work is hers (owner decision 2026-07-20).
    expect(res.body.pieces_total).toBe(6);
    expect(res.body.earned_total).toBe(28000);
    // The money the shop pays out is not.
    expect(res.body).not.toHaveProperty('salary_paid_total');
    expect(res.body).not.toHaveProperty('net_balance');
    expect(res.body).not.toHaveProperty('salary_payments_count');
    expect(JSON.stringify(res.body)).not.toContain('10000');
  });

  test('secretary is refused the sheet of a monthly employee (403)', async () => {
    expect((await asS(
      request(app).get(`/api/staff/${monthlyId}/all-time-summary`))).status).toBe(403);
    // …while the manager gets it, with net_balance null (no piece work to net).
    const res = await asM(request(app).get(`/api/staff/${monthlyId}/all-time-summary`));
    expect(res.status).toBe(200);
    expect(res.body.net_balance).toBeNull();
  });

  test('unknown staff id is a 404 for the manager', async () => {
    const res = await asM(request(app).get(
      '/api/staff/00000000-0000-0000-0000-000000000000/all-time-summary'));
    expect(res.status).toBe(404);
  });
});

// ---------------------------------------------------------------------------
describe('GET /api/reports/dashboard', () => {
  test('secretary is blocked (403) — it carries cash and client debt', async () => {
    expect((await asS(request(app).get('/api/reports/dashboard'))).status).toBe(403);
  });

  test('a new order moves today\'s counters and the outstanding debt', async () => {
    const before = (await asM(request(app).get('/api/reports/dashboard'))).body;

    const clientId = (await asM(request(app).post('/api/clients')).send({
      full_name: 'QWX Debiteur', phone: '99552001',
    })).body.id;
    // 50 000 owed, 20 000 paid up front → 30 000 outstanding.
    await asM(request(app).post('/api/orders')).send({
      client_id: clientId,
      advance: 20000,
      status: 'en_cours',
      items: [{ garment_type: 'Veste', quantity: 1, unit_price: 50000 }],
    });

    const after = (await asM(request(app).get('/api/reports/dashboard'))).body;

    expect(after.today.orders_created - before.today.orders_created).toBe(1);
    expect(after.today.payments_collected - before.today.payments_collected).toBe(20000);
    expect(after.orders.en_cours - before.orders.en_cours).toBe(1);
    expect(after.debt.total - before.debt.total).toBe(30000);
    expect(after.debt.orders_count - before.debt.orders_count).toBe(1);
    expect(after.debt.clients_count - before.debt.clients_count).toBe(1);
  });

  test('delivering an order collects the balance and clears it from the debt', async () => {
    const clientId = (await asM(request(app).post('/api/clients')).send({
      full_name: 'QWX Solde', phone: '99552002',
    })).body.id;
    const orderId = (await asM(request(app).post('/api/orders')).send({
      client_id: clientId,
      advance: 5000,
      items: [{ garment_type: 'Chemise', quantity: 1, unit_price: 25000 }],
    })).body.id;

    const before = (await asM(request(app).get('/api/reports/dashboard'))).body;
    await asM(request(app).put(`/api/orders/${orderId}`)).send({ status: 'livre' });
    const after = (await asM(request(app).get('/api/reports/dashboard'))).body;

    // Delivery banks the outstanding 20 000 (orders.js) …
    expect(after.today.payments_collected - before.today.payments_collected).toBe(20000);
    // … so the order stops counting as a debt.
    expect(after.debt.total - before.debt.total).toBe(-20000);
  });

  test('a cancelled order is never counted as owed', async () => {
    const clientId = (await asM(request(app).post('/api/clients')).send({
      full_name: 'QWX Annule', phone: '99552003',
    })).body.id;
    const orderId = (await asM(request(app).post('/api/orders')).send({
      client_id: clientId,
      advance: 0,
      items: [{ garment_type: 'Boubou', quantity: 1, unit_price: 40000 }],
    })).body.id;

    const withOrder = (await asM(request(app).get('/api/reports/dashboard'))).body;
    await asM(request(app).delete(`/api/orders/${orderId}`)).send({ reason: 'Test' });
    const after = (await asM(request(app).get('/api/reports/dashboard'))).body;

    expect(withOrder.debt.total - after.debt.total).toBe(40000);
  });
});

// ---------------------------------------------------------------------------
describe('GET /api/reports/unpaid-orders', () => {
  test('secretary is blocked (403)', async () => {
    expect((await asS(request(app).get('/api/reports/unpaid-orders'))).status).toBe(403);
  });

  test('lists delivered orders that still owe, with the phone for the reminder', async () => {
    const clientId = (await asM(request(app).post('/api/clients')).send({
      full_name: 'QWX Impaye', phone: '99553001',
    })).body.id;
    const orderId = (await asM(request(app).post('/api/orders')).send({
      client_id: clientId,
      advance: 10000,
      items: [{ garment_type: 'Veste', quantity: 1, unit_price: 60000 }],
    })).body.id;

    // Hand-over: delivering banks the outstanding balance (orders.js), so the
    // order is momentarily settled.
    await asM(request(app).put(`/api/orders/${orderId}`)).send({ status: 'livre' });
    const before = (await asM(request(app).get('/api/reports/unpaid-orders'))).body;
    expect(before.items.find((o) => o.id === orderId)).toBeUndefined();

    // Real life: the client took the garment and paid only 5 000 in the end.
    // The manager corrects the collected cash DOWN — which orders.js records
    // through order_payment_corrections, never a negative counter-row.
    await asM(request(app).put(`/api/orders/${orderId}`)).send({ advance: 5000 });
    const after = (await asM(request(app).get('/api/reports/unpaid-orders'))).body;

    expect(after.total_count - before.total_count).toBe(1);
    expect(after.total_due - before.total_due).toBe(55000);

    const mine = after.items.find((o) => o.id === orderId);
    expect(mine).toBeTruthy();
    expect(mine.client_name).toBe('QWX Impaye');
    expect(mine.client_phone).toBe('99553001'); // needed for the wa.me reminder
    expect(mine.total).toBe(60000);
    expect(mine.paid).toBe(5000);
    expect(mine.reste).toBe(55000);
  });

  test('a fully settled delivered order is absent from the list', async () => {
    const clientId = (await asM(request(app).post('/api/clients')).send({
      full_name: 'QWX Regle', phone: '99553002',
    })).body.id;
    const orderId = (await asM(request(app).post('/api/orders')).send({
      client_id: clientId,
      advance: 15000,
      items: [{ garment_type: 'Chemise', quantity: 1, unit_price: 15000 }],
    })).body.id;
    await asM(request(app).put(`/api/orders/${orderId}`)).send({ status: 'livre' });

    const res = (await asM(request(app).get('/api/reports/unpaid-orders'))).body;
    expect(res.items.find((o) => o.id === orderId)).toBeUndefined();
  });
});
