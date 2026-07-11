// =============================================================================
// Finance calculation correctness — products revenue, stock, and COGS.
// =============================================================================
// Proves, against the real API + PostgreSQL, the exact scenario the shop
// owner described: a product sold several times, one sale corrected and one
// voided, then the stock and the finance summary checked by hand.
//
// Uses a baseline→after DELTA on the finance summary so it is robust to any
// other fixtures already in the shared test database.
// =============================================================================

const request = require('supertest');
const { createApp } = require('../src/app');
const db = require('../src/db');
const { MANAGER, seedUsers, login } = require('./helpers');

let app;
let managerToken;
const asManager = (r) => r.set('Authorization', `Bearer ${managerToken}`);

const PRICE = 10000;
const COST = 6000;
const START_QTY = 50;

beforeAll(async () => {
  app = createApp();
  await seedUsers();
  managerToken = await login(app, MANAGER);
});

afterAll(async () => {
  await db.closePool();
});

async function summary() {
  const res = await asManager(request(app).get('/api/finance/summary'));
  expect(res.status).toBe(200);
  return res.body;
}

async function productStock(id) {
  const { rows } = await db.query('SELECT quantity FROM products WHERE id = $1', [id]);
  return rows[0].quantity;
}

test('stock, revenue and COGS stay consistent through a correction and a void', async () => {
  // A product with a known selling price AND cost price.
  const productId = (await asManager(request(app).post('/api/products')).send({
    category: 'tissu', name: 'Bazin COGS-test', price: PRICE, cost_price: COST,
    quantity: START_QTY,
  })).body.id;

  const before = await summary();

  // Three sales of the same product.
  const saleA = (await asManager(request(app).post('/api/sales'))
    .send({ kind: 'produit', item_id: productId, qty: 3 })).body;
  const saleB = (await asManager(request(app).post('/api/sales'))
    .send({ kind: 'produit', item_id: productId, qty: 5 })).body;
  await asManager(request(app).post('/api/sales'))
    .send({ kind: 'produit', item_id: productId, qty: 2 });

  // Correct sale A from 3 → 4 (one more unit leaves the shop).
  await asManager(request(app).post(`/api/sales/${saleA.id}/corrections`))
    .send({ new_qty: 4, reason: 'Client a pris une pièce de plus' });
  // Void sale B entirely (return / cancellation) — its 5 units come back.
  await asManager(request(app).post(`/api/sales/${saleB.id}/corrections`))
    .send({ voided: true, reason: 'Vente annulée' });

  // --- hand-computed expectations -----------------------------------------
  // Effective units sold = A(4) + C(2) = 6 ; B is voided.
  const effectiveUnits = 4 + 2;
  const expectedStock = START_QTY - effectiveUnits;          // 44
  const expectedRevenue = effectiveUnits * PRICE;            // 60,000
  const expectedCogs = effectiveUnits * COST;                // 36,000
  const expectedProfit = expectedRevenue - expectedCogs;     // 24,000

  // Stock is absolute (isolated to this product).
  expect(await productStock(productId)).toBe(expectedStock);

  // Finance summary deltas are robust to any other data in the DB.
  const after = await summary();
  expect(after.revenue.sales - before.revenue.sales).toBe(expectedRevenue);
  expect(after.costs.cost_of_goods_sold - before.costs.cost_of_goods_sold)
    .toBe(expectedCogs);
  expect(after.net_profit - before.net_profit).toBe(expectedProfit);
});
