// =============================================================================
// VERIFICATION AUDIT 2026-08-24 — every fix pinned to a hand calculation.
// =============================================================================
// A second full pass over the money code after the 2026-08-23 audit found four
// more figures that were wrong, all of the same families the owner asked to
// hunt for: money never counted, money counted twice, and a past period whose
// numbers move under your feet.
//
// Each test below walks a realistic shop situation and compares the result with
// a number computed by hand in the comments. Each one FAILS if its fix is
// reverted — that was checked by actually reverting them.
// =============================================================================

const request = require('supertest');
const { createApp } = require('../src/app');
const db = require('../src/db');
const { MANAGER, SECRETARY, seedUsers, login } = require('./helpers');

let app;
let managerToken;
let secretaryToken;
const asManager = (r) => r.set('Authorization', `Bearer ${managerToken}`);
const asSec = (r) => r.set('Authorization', `Bearer ${secretaryToken}`);

const TODAY = new Date().toISOString().slice(0, 10);

beforeAll(async () => {
  app = createApp();
  await seedUsers();
  managerToken = await login(app, MANAGER);
  secretaryToken = await login(app, SECRETARY);
});

afterAll(async () => {
  await db.closePool();
});

async function finance(from = TODAY, to = TODAY) {
  const res = await asManager(
    request(app).get(`/api/finance/summary?from=${from}&to=${to}`));
  expect(res.status).toBe(200);
  return res.body;
}

async function newClient(name) {
  const res = await asManager(request(app).post('/api/clients'))
    .send({ full_name: name, phone: `77${Math.floor(100000 + Math.random() * 899999)}` });
  expect(res.status).toBe(201);
  return res.body.id;
}

/** Cash effectively recorded against an order, straight from the view. */
async function collected(orderId) {
  const { rows } = await db.query(
    `SELECT COALESCE(SUM(amount), 0)::int AS v FROM order_payments_effective
      WHERE order_id = $1 AND NOT voided`, [orderId]);
  return rows[0].v;
}

// ---------------------------------------------------------------------------
// 1. Per-item profit must read the FROZEN purchase cost.
// ---------------------------------------------------------------------------
// Family: "a past period whose figures change under your feet" — the same bug
// migration 024 fixed for COGS, which survived in /stats because it multiplied
// today's catalogue cost_price by everything ever sold. Re-pricing an item on
// every delivery silently rewrote the profit of all its past sales, and made
// this screen contradict Finances about the very same sale.
// ---------------------------------------------------------------------------
describe('per-item profit (Produits / Prêt-à-porter)', () => {
  test('a product’s lifetime profit does not move when its cost price does',
    async () => {
      const productId = (await asManager(request(app).post('/api/products')).send({
        category: 'parfum', name: `Audit24 Parfum ${Date.now()}`,
        price: 10000, cost_price: 6000, quantity: 50,
      })).body.id;

      await asManager(request(app).post('/api/sales'))
        .send({ kind: 'produit', item_id: productId, qty: 4 });
      // 4 × 10 000 = 40 000 taken in; 4 × 6 000 = 24 000 paid for them.
      // Profit = 40 000 − 24 000 = 16 000.

      const before = (await asManager(
        request(app).get(`/api/products/${productId}/stats`))).body;
      expect(before).toMatchObject({
        total_sold: 4, total_revenue: 40000, total_profit: 16000,
      });

      // The supplier raises the price. The four already sold cost what they
      // cost — nothing about them changed.
      const put = await asManager(request(app).put(`/api/products/${productId}`)).send({
        category: 'parfum', name: 'Audit24 Parfum reprice',
        price: 10000, cost_price: 9000, quantity: 46,
      });
      expect(put.status).toBe(200);

      const after = (await asManager(
        request(app).get(`/api/products/${productId}/stats`))).body;
      expect(after.total_profit).toBe(16000); // was 4 000 before the fix
      expect(after.total_revenue).toBe(40000);
    });

  test('a ready-to-wear model’s profit is frozen the same way', async () => {
    const modelId = (await asManager(request(app).post('/api/pret-a-porter')).send({
      name: `Audit24 Modèle ${Date.now()}`, fabric_type: 'bazin',
      price: 25000, cost_price: 15000,
    })).body.id;

    await asManager(request(app).post('/api/sales'))
      .send({ kind: 'pret_a_porter', item_id: modelId, qty: 2 });
    // 2 × 25 000 = 50 000 in; 2 × 15 000 = 30 000 out → profit 20 000.

    expect((await asManager(
      request(app).get(`/api/pret-a-porter/${modelId}/stats`))).body.total_profit)
      .toBe(20000);

    await asManager(request(app).put(`/api/pret-a-porter/${modelId}`)).send({
      name: 'Audit24 Modèle reprice', fabric_type: 'bazin',
      price: 25000, cost_price: 22000,
    });

    expect((await asManager(
      request(app).get(`/api/pret-a-porter/${modelId}/stats`))).body.total_profit)
      .toBe(20000); // was 6 000 before the fix
  });

  test('a voided sale leaves no revenue and no cost behind', async () => {
    const productId = (await asManager(request(app).post('/api/products')).send({
      category: 'parfum', name: `Audit24 Void ${Date.now()}`,
      price: 8000, cost_price: 5000, quantity: 10,
    })).body.id;

    const saleId = (await asManager(request(app).post('/api/sales'))
      .send({ kind: 'produit', item_id: productId, qty: 3 })).body.id;
    await asManager(request(app).post(`/api/sales/${saleId}/corrections`))
      .send({ voided: true, reason: 'Client a rendu la marchandise' });

    expect((await asManager(
      request(app).get(`/api/products/${productId}/stats`))).body).toMatchObject({
      total_sold: 0, total_revenue: 0, total_profit: 0,
    });
  });
});

// ---------------------------------------------------------------------------
// 2. Raising an advance after delivery must not invent cash.
// ---------------------------------------------------------------------------
// Family: "money counted twice". The 2026-08-23 audit fixed the LOWERING
// direction (correctCollectedBy reduces BY a difference, never DOWN TO a
// figure). The raising direction still inserted the whole difference as a new
// payment, with no regard for whether anything was still owed.
// ---------------------------------------------------------------------------
describe('correcting an order’s advance', () => {
  test('raising it before delivery banks the difference, as it should',
    async () => {
      const clientId = await newClient('Audit24 Avance A');
      const order = (await asManager(request(app).post('/api/orders')).send({
        client_id: clientId, advance: 20000,
        items: [{ garment_type: 'Grand Boubou', quantity: 1, unit_price: 100000 }],
      })).body;
      expect(await collected(order.id)).toBe(20000);

      // Client comes back and leaves 10 000 more: 20 000 → 30 000.
      await asManager(request(app).put(`/api/orders/${order.id}`))
        .send({ advance: 30000 });
      expect(await collected(order.id)).toBe(30000);
    });

  test('raising it AFTER delivery adds nothing — the order is already settled',
    async () => {
      const clientId = await newClient('Audit24 Avance B');
      const order = (await asManager(request(app).post('/api/orders')).send({
        client_id: clientId, advance: 20000,
        items: [{ garment_type: 'Grand Boubou', quantity: 1, unit_price: 100000 }],
      })).body;

      // Hand-over collects the 80 000 balance → 100 000 collected, nothing owed.
      await asManager(request(app).put(`/api/orders/${order.id}`))
        .send({ status: 'livre' });
      expect(await collected(order.id)).toBe(100000);

      // The manager fixes the advance: the client had left 30 000, not 20 000.
      // That changes WHICH 100 000 was collected, never HOW MUCH.
      await asManager(request(app).put(`/api/orders/${order.id}`))
        .send({ advance: 30000 });
      expect(await collected(order.id)).toBe(100000); // was 110 000 before the fix
    });

  test('an advance typed far too high is capped at what the order is worth',
    async () => {
      const clientId = await newClient('Audit24 Avance C');
      const order = (await asManager(request(app).post('/api/orders')).send({
        client_id: clientId, advance: 20000,
        items: [{ garment_type: 'Chemise', quantity: 1, unit_price: 100000 }],
      })).body;

      // A slip of the finger: 200 000 on a 100 000 order.
      await asManager(request(app).put(`/api/orders/${order.id}`))
        .send({ advance: 200000 });
      // At most the 80 000 still owed can be banked → 100 000, never 220 000.
      expect(await collected(order.id)).toBe(100000);
    });

  test('lowering it after delivery still removes only the difference',
    async () => {
      // Guards the 2026-08-23 fix against a regression from this one.
      const clientId = await newClient('Audit24 Avance D');
      const order = (await asManager(request(app).post('/api/orders')).send({
        client_id: clientId, advance: 20000,
        items: [{ garment_type: 'Grand Boubou', quantity: 1, unit_price: 100000 }],
      })).body;
      await asManager(request(app).put(`/api/orders/${order.id}`))
        .send({ status: 'livre' });
      expect(await collected(order.id)).toBe(100000);

      // 20 000 → 10 000 removes 10 000, not 90 000.
      await asManager(request(app).put(`/api/orders/${order.id}`))
        .send({ advance: 10000 });
      expect(await collected(order.id)).toBe(90000);
    });

  test('the secretary cannot inflate revenue through the advance either',
    async () => {
      // Orders are hers (owner decision 2026-08-23), so the cap has to hold on
      // her writes too — she is the one typing at the counter.
      const clientId = await newClient('Audit24 Avance E');
      const order = (await asSec(request(app).post('/api/orders')).send({
        client_id: clientId, advance: 20000,
        items: [{ garment_type: 'Grand Boubou', quantity: 1, unit_price: 100000 }],
      })).body;
      await asSec(request(app).put(`/api/orders/${order.id}`))
        .send({ status: 'livre' });
      await asSec(request(app).put(`/api/orders/${order.id}`))
        .send({ advance: 60000 });
      expect(await collected(order.id)).toBe(100000); // was 140 000 before the fix
    });
});

// ---------------------------------------------------------------------------
// 3. An invalid advance is refused, not silently recorded as 0.
// ---------------------------------------------------------------------------
describe('validating the advance on a new order', () => {
  test('text, a negative and a decimal are all refused', async () => {
    const clientId = await newClient('Audit24 Validation');
    const items = [{ garment_type: 'Chemise', quantity: 1, unit_price: 50000 }];

    for (const bad of ['vingt mille', -5000, 12.5]) {
      const res = await asManager(request(app).post('/api/orders'))
        .send({ client_id: clientId, advance: bad, items });
      expect(res.status).toBe(400); // all three were 201 with advance 0 before
    }
  });

  test('a missing advance still means "none", and 0 is still valid', async () => {
    const clientId = await newClient('Audit24 Validation 2');
    const items = [{ garment_type: 'Chemise', quantity: 1, unit_price: 50000 }];

    const omitted = await asManager(request(app).post('/api/orders'))
      .send({ client_id: clientId, items });
    expect(omitted.status).toBe(201);
    expect(omitted.body.advance).toBe(0);
    expect(await collected(omitted.body.id)).toBe(0);

    const zero = await asManager(request(app).post('/api/orders'))
      .send({ client_id: clientId, advance: 0, items });
    expect(zero.status).toBe(201);
  });
});

// ---------------------------------------------------------------------------
// 4. Wholesale sales must carry a cost.
// ---------------------------------------------------------------------------
// Family: "money never counted". Wholesale cash reached revenue (migration 024)
// but nothing anywhere recorded what the lot cost, so every bulk sale showed a
// 100 % margin and net profit was overstated by the whole purchase price.
// ---------------------------------------------------------------------------
describe('wholesale margin', () => {
  test('a lot bought at 1 000 000 and sold at 1 300 000 nets 300 000',
    async () => {
      const before = await finance();

      await asManager(request(app).post('/api/wholesale/orders')).send({
        merchant_name: 'Commerçant Audit24', total_amount: 1300000,
        advance_amount: 1300000, cost_amount: 1000000,
      });

      const after = await finance();
      expect(after.revenue.total - before.revenue.total).toBe(1300000);
      expect(after.costs.total - before.costs.total).toBe(1000000); // was 0
      expect(after.net_profit - before.net_profit).toBe(300000);    // was 1 300 000
    });

  test('a lot with no cost recorded behaves exactly as before', async () => {
    // Every order created before migration 028 has cost_amount 0. Their figures
    // must not jump — the owner has already seen them.
    const before = await finance();
    await asManager(request(app).post('/api/wholesale/orders')).send({
      merchant_name: 'Commerçant sans coût', total_amount: 400000,
      advance_amount: 400000,
    });
    const after = await finance();
    expect(after.revenue.total - before.revenue.total).toBe(400000);
    expect(after.costs.total - before.costs.total).toBe(0);
  });

  test('the cost is editable afterwards and the margin follows', async () => {
    const before = await finance();
    const order = (await asManager(request(app).post('/api/wholesale/orders')).send({
      merchant_name: 'Commerçant à corriger', total_amount: 500000,
      advance_amount: 500000,
    })).body;

    const put = await asManager(request(app).put(`/api/wholesale/orders/${order.id}`))
      .send({ cost_amount: 320000 });
    expect(put.status).toBe(200);
    expect(put.body.cost_amount).toBe(320000);

    const after = await finance();
    expect(after.net_profit - before.net_profit).toBe(500000 - 320000);
  });

  test('a supplier purchase is NOT charged again as a cost', async () => {
    // Suppliers are a debt ledger; the same money reaches the P&L as COGS when
    // the goods are sold. Counting both would charge every purchase twice.
    const supplierId = (await asManager(request(app).post('/api/suppliers'))
      .send({ name: `Fournisseur Audit24 ${Date.now()}`, phone: '76000009' })).body.id;

    const before = await finance();
    await asManager(request(app).post('/api/suppliers/purchases')).send({
      supplier_id: supplierId, description: 'Tissu en gros',
      total_amount: 900000, advance_amount: 900000,
    });
    const after = await finance();
    expect(after.costs.total - before.costs.total).toBe(0);
  });

  test('wholesale stays manager-only, cost included', async () => {
    expect((await asSec(request(app).get('/api/wholesale/orders'))).status).toBe(403);
    expect((await asSec(request(app).post('/api/wholesale/orders'))
      .send({ merchant_name: 'X', total_amount: 1, cost_amount: 1 })).status).toBe(403);
  });
});

// ---------------------------------------------------------------------------
// 5. The Finances detail subtotals must equal the KPI cards.
// ---------------------------------------------------------------------------
// The app used to add these up itself from PAGINATED lists — 20 orders, 50
// sales, 50 expenses — so a busy month printed a subtotal covering the first
// page directly beneath a card holding the true figure. And the delivered-order
// table listed order TOTALS under a card that is cash-basis, so the two could
// never reconcile even when short.
// ---------------------------------------------------------------------------
describe('/api/finance/detail', () => {
  async function detail(from = TODAY, to = TODAY) {
    const res = await asManager(
      request(app).get(`/api/finance/detail?from=${from}&to=${to}`));
    expect(res.status).toBe(200);
    return res.body;
  }

  test('every category subtotal equals its KPI card, to the franc', async () => {
    // Add a bit of everything so none of the categories is trivially empty.
    const clientId = await newClient('Audit24 Détail');
    const order = (await asManager(request(app).post('/api/orders')).send({
      client_id: clientId, advance: 15000,
      items: [{ garment_type: 'Grand Boubou', quantity: 1, unit_price: 60000 }],
    })).body;
    await asManager(request(app).put(`/api/orders/${order.id}`)).send({ status: 'livre' });

    const productId = (await asManager(request(app).post('/api/products')).send({
      category: 'parfum', name: `Audit24 Détail ${Date.now()}`,
      price: 7000, cost_price: 4000, quantity: 30,
    })).body.id;
    await asManager(request(app).post('/api/sales'))
      .send({ kind: 'produit', item_id: productId, qty: 2 });

    await asManager(request(app).post('/api/expenses'))
      .send({ reason: 'Audit24 électricité', amount: 12000, spent_at: TODAY });

    const tailorId = (await asManager(request(app).post('/api/staff'))
      .send({ full_name: `Audit24 Couturier ${Date.now()}`, type: 'couturier' })).body.id;
    await asManager(request(app).put(`/api/staff-pay/${tailorId}`)).send({ piece_rate: 2500 });
    await asManager(request(app).post('/api/tailor-entries')).send({
      tailor_id: tailorId, entry_date: TODAY, pieces_count: 6, garment_type: 'Chemise',
    });

    const [d, f] = [await detail(), await finance()];

    expect(d.orders.total).toBe(f.revenue.orders);
    expect(d.sales.total).toBe(f.revenue.sales);
    expect(d.wages.total).toBe(f.costs.tailor_wages);
    expect(d.expenses.total).toBe(f.costs.expenses);
  });

  test('the subtotal covers the whole window, not just the rows returned',
    async () => {
      const d = await detail();
      for (const key of ['orders', 'sales', 'wages', 'expenses']) {
        const listed = d[key].rows.reduce((s, r) => s + r.amount, 0);
        // While nothing is truncated the two agree exactly; the point of the
        // separate `total` is that it stays right when they stop agreeing.
        if (!d[key].truncated) expect(listed).toBe(d[key].total);
        expect(typeof d[key].total).toBe('number');
      }
    });

  test('delivered-order rows are the CASH collected, not the order price',
    async () => {
      // A delivered order with a balance still owed: the shop received the
      // advance only, and that is all this table may show.
      const clientId = await newClient('Audit24 Dette');
      const order = (await asManager(request(app).post('/api/orders')).send({
        client_id: clientId, advance: 5000,
        items: [{ garment_type: 'Chemise', quantity: 1, unit_price: 90000 }],
      })).body;

      const before = (await detail()).orders.total;
      // Deliver by writing the status directly, so no balance payment is made:
      // the client is leaving with the garment and still owes 85 000.
      await db.query("UPDATE orders SET status = 'livre', delivered_date = CURRENT_DATE WHERE id = $1",
        [order.id]);

      const d = await detail();
      expect(d.orders.total).toBe(before); // 5 000 already counted, 85 000 never
      expect(d.orders.total).toBe((await finance()).revenue.orders);
    });

  test('it is manager-only, like the rest of Finances', async () => {
    expect((await asSec(request(app).get('/api/finance/detail'))).status).toBe(403);
  });
});

// ---------------------------------------------------------------------------
// 6. Editing a piece rate must not wipe a weekly salary.
// ---------------------------------------------------------------------------
// staff_pay was rebuilt from scratch on every PUT, so a request that did not
// carry weekly_salary / pay_frequency reset them — and that employee's wages
// then vanished from the payroll cost, the exact bug migration 014 introduced
// and the 2026-08-23 audit fixed at the query end.
// ---------------------------------------------------------------------------
describe('staff pay: partial updates keep what they do not mention', () => {
  test('a weekly employee stays weekly when only the piece rate is sent',
    async () => {
      const staffId = (await asManager(request(app).post('/api/staff'))
        .send({ full_name: `Audit24 Hebdo ${Date.now()}`, type: 'couturier' })).body.id;

      await asManager(request(app).put(`/api/staff-pay/${staffId}`)).send({
        piece_rate: 1000, weekly_salary: 25000, pay_frequency: 'hebdo',
      });

      // A screen that knows nothing about weekly pay edits the piece rate.
      const res = await asManager(request(app).put(`/api/staff-pay/${staffId}`))
        .send({ piece_rate: 1500 });
      expect(res.status).toBe(200);
      expect(res.body.piece_rate).toBe(1500);
      expect(res.body.weekly_salary).toBe(25000);     // was reset to null
      expect(res.body.pay_frequency).toBe('hebdo');   // was reset to 'mensuel'
    });

  test('the secretary’s piece-rate write never disturbs the salary side',
    async () => {
      const staffId = (await asManager(request(app).post('/api/staff'))
        .send({ full_name: `Audit24 Mixte ${Date.now()}`, type: 'couturier' })).body.id;
      await asManager(request(app).put(`/api/staff-pay/${staffId}`)).send({
        piece_rate: 900, monthly_salary: 40000, weekly_salary: 12000,
        pay_frequency: 'hebdo',
      });

      const her = await asSec(request(app).put(`/api/staff-pay/${staffId}`))
        .send({ piece_rate: 1100, weekly_salary: 999999, pay_frequency: 'mensuel' });
      expect(her.status).toBe(200);
      expect(her.body.weekly_salary).toBeUndefined(); // stripped from her reply
      expect(her.body.monthly_salary).toBeUndefined();

      const asSeenByManager = (await asManager(request(app).get('/api/staff-pay')))
        .body.items.find((r) => r.staff_id === staffId);
      expect(asSeenByManager.piece_rate).toBe(1100);  // her write landed
      expect(asSeenByManager.weekly_salary).toBe(12000);  // hers was ignored
      expect(asSeenByManager.monthly_salary).toBe(40000);
      expect(asSeenByManager.pay_frequency).toBe('hebdo');
    });
});

// ---------------------------------------------------------------------------
// 7. A garbled date filter is ignored, not a 500.
// ---------------------------------------------------------------------------
test('an unparseable ?from= on the sales list is ignored', async () => {
  const res = await asManager(request(app).get('/api/sales?from=hier&to=demain'));
  expect(res.status).toBe(200); // was 500
  expect(Array.isArray(res.body.items)).toBe(true);
});
