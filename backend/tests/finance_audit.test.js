// =============================================================================
// FULL FINANCIAL AUDIT — every money figure checked against a hand calculation.
// =============================================================================
// The owner reported that "Rapport et statistique" did not match reality. This
// suite walks a realistic shop day end-to-end (product sale + ready-to-wear
// sale + tailoring order with an advance and a delivery balance + tailor wages
// + a manual expense + a monthly salary + a weekly salary + a wholesale order
// to a merchant) and asserts every single line of /api/finance/summary and
// /api/reports/summary against numbers computed by hand in the comments.
//
// Each test isolates its own contribution with a baseline→after DELTA, so it is
// robust to the fixtures other suites leave in the shared test database.
//
// It covers the three failure families the owner asked to hunt for:
//   (a) money that is NEVER counted,
//   (b) money counted TWICE,
//   (c) money counted on the WRONG DATE.
// =============================================================================

const request = require('supertest');
const { createApp } = require('../src/app');
const db = require('../src/db');
const { MANAGER, seedUsers, login } = require('./helpers');

let app;
let managerToken;
const asManager = (r) => r.set('Authorization', `Bearer ${managerToken}`);

const TODAY = new Date().toISOString().slice(0, 10);

beforeAll(async () => {
  app = createApp();
  await seedUsers();
  managerToken = await login(app, MANAGER);
});

afterAll(async () => {
  await db.closePool();
});

/** /api/finance/summary for a window (defaults to today only). */
async function finance(from = TODAY, to = TODAY) {
  const res = await asManager(
    request(app).get(`/api/finance/summary?from=${from}&to=${to}`));
  expect(res.status).toBe(200);
  return res.body;
}

/** /api/reports/summary for the same window — must agree with finance. */
async function report(from = TODAY, to = TODAY) {
  const res = await asManager(
    request(app).get(`/api/reports/summary?from=${from}&to=${to}`));
  expect(res.status).toBe(200);
  return res.body;
}

async function newClient(name) {
  const res = await asManager(request(app).post('/api/clients'))
    .send({ full_name: name, phone: `76${Math.floor(100000 + Math.random() * 899999)}` });
  expect(res.status).toBe(201);
  return res.body.id;
}

// ---------------------------------------------------------------------------
// 1. The whole shop day, added up by hand.
// ---------------------------------------------------------------------------
test('a full shop day: every revenue and cost line matches the hand calculation', async () => {
  const before = await finance();

  // --- a product sale: 3 bottles at 10 000, bought at 6 000 each ------------
  const productId = (await asManager(request(app).post('/api/products')).send({
    category: 'parfum', name: 'Audit Parfum', price: 10000, cost_price: 6000,
    quantity: 20,
  })).body.id;
  await asManager(request(app).post('/api/sales'))
    .send({ kind: 'produit', item_id: productId, qty: 3 });
  //   revenue 3 × 10 000 = 30 000 ; COGS 3 × 6 000 = 18 000

  // --- a ready-to-wear sale: 1 model at 25 000, bought at 15 000 ------------
  const modelId = (await asManager(request(app).post('/api/pret-a-porter')).send({
    name: 'Audit Modèle', price: 25000, cost_price: 15000, fabric: 'Bazin',
  })).body.id;
  await asManager(request(app).post('/api/sales'))
    .send({ kind: 'pret_a_porter', item_id: modelId, qty: 1 });
  //   revenue 25 000 ; COGS 15 000

  // --- a tailoring order: 100 000 total, 20 000 advance, delivered today ----
  const clientId = await newClient('Client Audit');
  const orderId = (await asManager(request(app).post('/api/orders')).send({
    client_id: clientId,
    items: [
      { garment_type: 'Grand Boubou', quantity: 1, unit_price: 60000 },
      { garment_type: 'Chemise', quantity: 2, unit_price: 20000 },
    ],
    advance: 20000,
  })).body.id;
  await asManager(request(app).put(`/api/orders/${orderId}`)).send({ status: 'livre' });
  //   cash in today: 20 000 advance + 80 000 balance at delivery = 100 000

  // --- tailor wages: 5 pieces at 2 000 -------------------------------------
  const tailorId = (await asManager(request(app).post('/api/staff'))
    .send({ full_name: 'Tailleur Audit', phone: '76111222', type: 'couturier' })).body.id;
  await asManager(request(app).put(`/api/staff-pay/${tailorId}`)).send({ piece_rate: 2000 });
  await asManager(request(app).post('/api/tailor-entries')).send({
    tailor_id: tailorId, entry_date: TODAY, pieces_count: 5,
    garment_type: 'Grand Boubou', piece_rate: 2000,
  });
  //   wages 5 × 2 000 = 10 000

  // --- a manual expense ----------------------------------------------------
  await asManager(request(app).post('/api/expenses'))
    .send({ reason: 'Fil et boutons', amount: 7000, spent_at: TODAY });
  //   expenses 7 000

  const after = await finance();

  // ---- hand-computed deltas ----------------------------------------------
  expect(after.revenue.sales - before.revenue.sales).toBe(30000 + 25000);
  expect(after.revenue.orders - before.revenue.orders).toBe(100000);
  expect(after.revenue.total - before.revenue.total).toBe(155000);

  expect(after.costs.cost_of_goods_sold - before.costs.cost_of_goods_sold)
    .toBe(18000 + 15000);
  expect(after.costs.tailor_wages - before.costs.tailor_wages).toBe(10000);
  expect(after.costs.expenses - before.costs.expenses).toBe(7000);

  // Net profit must be exactly revenue − costs, with no drift.
  expect(after.net_profit).toBe(after.revenue.total - after.costs.total);
  expect(after.costs.total).toBe(
    after.costs.cost_of_goods_sold + after.costs.tailor_wages
    + after.costs.salaries + after.costs.expenses);

  // The report screen must show the SAME money as the finance screen.
  const rep = await report();
  expect(rep.revenue).toEqual(after.revenue);
  expect(rep.costs).toEqual(after.costs);
  expect(rep.net_profit).toBe(after.net_profit);
});

// ---------------------------------------------------------------------------
// 2. FAMILY (a): money never counted — weekly-paid staff.
// ---------------------------------------------------------------------------
test('a weekly-paid employee is charged to the period, like a monthly one', async () => {
  const WEEKLY = 14000; // 14 000 / week → exactly 2 000 per day.

  const weekBefore = (await finance('2026-05-04', '2026-05-10')).costs.salaries;
  const yearBefore = (await finance('2026-01-01', '2026-12-31')).costs.salaries;

  const staffId = (await asManager(request(app).post('/api/staff'))
    .send({ full_name: 'Employé Hebdo Audit', phone: '76333444', type: 'autre' })).body.id;
  await asManager(request(app).put(`/api/staff-pay/${staffId}`))
    .send({ weekly_salary: WEEKLY, pay_frequency: 'hebdo' });

  // A full 7-day week costs exactly one weekly salary.
  expect((await finance('2026-05-04', '2026-05-10')).costs.salaries - weekBefore)
    .toBe(WEEKLY);

  // A full (365-day) year costs 365/7 weekly salaries.
  const yearDelta = (await finance('2026-01-01', '2026-12-31')).costs.salaries - yearBefore;
  expect(Math.abs(yearDelta - Math.round(WEEKLY * 365 / 7))).toBeLessThanOrEqual(1);
});

// ---------------------------------------------------------------------------
// 3. FAMILY (a): money never counted — wholesale sales to merchants.
// ---------------------------------------------------------------------------
test('cash collected from a wholesale merchant appears in revenue', async () => {
  const before = await finance();

  const woId = (await asManager(request(app).post('/api/wholesale/orders')).send({
    merchant_name: 'Commerçant Audit', total_amount: 500000, advance_amount: 150000,
    order_date: TODAY,
  })).body.id;
  // The merchant settles another 200 000 the same day.
  await asManager(request(app).post(`/api/wholesale/orders/${woId}/payments`))
    .send({ amount: 200000, paid_at: TODAY });

  const after = await finance();

  // 150 000 advance + 200 000 settlement = 350 000 of real cash in the till.
  expect(after.revenue.wholesale - before.revenue.wholesale).toBe(350000);
  expect(after.revenue.total - before.revenue.total).toBe(350000);
  expect(after.revenue.total).toBe(
    after.revenue.sales + after.revenue.orders + after.revenue.wholesale);
});

// ---------------------------------------------------------------------------
// 4. FAMILY (b/c): the advance edited after delivery must not erase the
//    balance that was collected at hand-over.
// ---------------------------------------------------------------------------
test('lowering the advance after delivery only removes the difference', async () => {
  const clientId = await newClient('Client Avance');
  const orderId = (await asManager(request(app).post('/api/orders')).send({
    client_id: clientId,
    items: [{ garment_type: 'Grand Boubou', quantity: 1, unit_price: 100000 }],
    advance: 20000,
  })).body.id;

  const beforeDelivery = await finance();
  await asManager(request(app).put(`/api/orders/${orderId}`)).send({ status: 'livre' });
  // 80 000 balance collected at delivery → 100 000 total on this order.
  expect((await finance()).revenue.orders - beforeDelivery.revenue.orders).toBe(80000);

  const beforeFix = await finance();
  // The manager corrects the advance: the client really deposited 10 000.
  await asManager(request(app).put(`/api/orders/${orderId}`)).send({ advance: 10000 });

  // Only the 10 000 difference may leave the books — NOT the 80 000 balance.
  expect((await finance()).revenue.orders - beforeFix.revenue.orders).toBe(-10000);

  const { rows } = await db.query(
    `SELECT COALESCE(SUM(amount), 0)::int AS paid FROM order_payments_effective
     WHERE order_id = $1 AND NOT voided`, [orderId]);
  expect(rows[0].paid).toBe(90000);
});

// ---------------------------------------------------------------------------
// 5. FAMILY (c): a past period's cost must never change when today's data does.
//    COGS has to use the purchase cost AT THE TIME OF SALE.
// ---------------------------------------------------------------------------
test('changing a cost price today does not rewrite yesterday’s profit', async () => {
  const productId = (await asManager(request(app).post('/api/products')).send({
    category: 'chaussure', name: 'Audit Chaussure', price: 20000, cost_price: 12000,
    quantity: 10,
  })).body.id;

  const before = await finance();
  await asManager(request(app).post('/api/sales'))
    .send({ kind: 'produit', item_id: productId, qty: 2 });
  const afterSale = await finance();
  expect(afterSale.costs.cost_of_goods_sold - before.costs.cost_of_goods_sold)
    .toBe(24000); // 2 × 12 000

  // The next delivery from the supplier costs more; the manager updates it.
  await asManager(request(app).put(`/api/products/${productId}`))
    .send({ category: 'chaussure', name: 'Audit Chaussure', price: 20000, cost_price: 18000, quantity: 8 });

  // The sale already made must still cost what it cost that day.
  const afterRepricing = await finance();
  expect(afterRepricing.costs.cost_of_goods_sold)
    .toBe(afterSale.costs.cost_of_goods_sold);
  expect(afterRepricing.net_profit).toBe(afterSale.net_profit);
});

// ---------------------------------------------------------------------------
// 6. Corrections and voids must flow through to every total (the *_effective
//    views), on both the finance and the reports screen.
// ---------------------------------------------------------------------------
test('voiding a sale removes its revenue AND its cost from both screens', async () => {
  const productId = (await asManager(request(app).post('/api/products')).send({
    category: 'parfum', name: 'Audit Void', price: 30000, cost_price: 20000,
    quantity: 10,
  })).body.id;

  const before = await finance();
  const saleId = (await asManager(request(app).post('/api/sales'))
    .send({ kind: 'produit', item_id: productId, qty: 2 })).body.id;

  const afterSale = await finance();
  expect(afterSale.revenue.sales - before.revenue.sales).toBe(60000);
  expect(afterSale.costs.cost_of_goods_sold - before.costs.cost_of_goods_sold).toBe(40000);

  await asManager(request(app).post(`/api/sales/${saleId}/corrections`))
    .send({ voided: true, reason: 'Client a rendu la marchandise' });

  const afterVoid = await finance();
  // Back exactly where we started — revenue and cost both gone.
  expect(afterVoid.revenue.sales).toBe(before.revenue.sales);
  expect(afterVoid.costs.cost_of_goods_sold).toBe(before.costs.cost_of_goods_sold);

  // The stock came back too.
  const { rows } = await db.query('SELECT quantity FROM products WHERE id = $1', [productId]);
  expect(rows[0].quantity).toBe(10);

  const rep = await report();
  expect(rep.revenue.sales).toBe(afterVoid.revenue.sales);
  expect(rep.costs.cost_of_goods_sold).toBe(afterVoid.costs.cost_of_goods_sold);
});

// ---------------------------------------------------------------------------
// 7. The debt figure on the dashboard must equal total − collected, per order.
// ---------------------------------------------------------------------------
test('outstanding client debt equals the order total minus the cash collected', async () => {
  const dashBefore = (await asManager(request(app).get('/api/reports/dashboard'))).body;

  const clientId = await newClient('Client Dette');
  const orderId = (await asManager(request(app).post('/api/orders')).send({
    client_id: clientId,
    items: [{ garment_type: 'Grand Boubou', quantity: 3, unit_price: 40000 }],
    advance: 30000,
  })).body.id;
  // 120 000 total − 30 000 advance = 90 000 still owed.

  const dashAfter = (await asManager(request(app).get('/api/reports/dashboard'))).body;
  expect(dashAfter.debt.total - dashBefore.debt.total).toBe(90000);
  expect(dashAfter.today.payments_collected - dashBefore.today.payments_collected).toBe(30000);

  // Cancelling the order removes the debt but keeps the 30 000 already taken.
  await asManager(request(app).delete(`/api/orders/${orderId}`))
    .send({ reason: 'Client a changé d’avis' });
  const dashCancelled = (await asManager(request(app).get('/api/reports/dashboard'))).body;
  expect(dashCancelled.debt.total).toBe(dashBefore.debt.total);
  expect(dashCancelled.today.payments_collected)
    .toBe(dashBefore.today.payments_collected + 30000);
});
