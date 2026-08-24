const request = require('supertest');
const { createApp } = require('../src/app');
const db = require('../src/db');
const { withFreshDb } = require('./helpers');

describe('Full Day Financial Simulation (Real Atelier Workflow Audit)', () => {
  withFreshDb();

  let app;
  let managerToken;
  let secretaryToken;
  let perfumeId;
  let shoesId;
  let boubouId;
  let tailorId;

  beforeAll(async () => {
    app = createApp();

    // 1. Authenticate Manager & Secretary
    const mgrRes = await request(app)
      .post('/api/auth/login')
      .send({ username: 'admin@tailor.app', password: 'Admin@1234' });
    managerToken = mgrRes.body.token;

    const secRes = await request(app)
      .post('/api/auth/login')
      .send({ username: 'secretary@tailor.app', password: 'Secretary@1234' });
    secretaryToken = secRes.body.token;

    // 2. Setup Staff Roster
    // Couturier (Piece rate: 2,500 FCFA)
    const tRes = await request(app)
      .post('/api/staff')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ full_name: 'Moussa Tailleur', phone: '77001122', type: 'couturier' });
    tailorId = tRes.body.id;

    await request(app)
      .put(`/api/staff-pay/${tailorId}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ piece_rate: 2500 });

    // Weekly Staff (Cleaner / Aide - 14,000 FCFA / week)
    const wRes = await request(app)
      .post('/api/staff')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ full_name: 'Amadou Aide', phone: '77334455', type: 'autre' });
    const weeklyStaffId = wRes.body.id;

    await request(app)
      .put(`/api/staff-pay/${weeklyStaffId}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ weekly_salary: 14000, pay_frequency: 'hebdo' });

    // Monthly Staff (Secretary - 60,000 FCFA / month)
    const mRes = await request(app)
      .post('/api/staff')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ full_name: 'Fatoumata Secretaire', phone: '77667788', type: 'autre' });
    const monthlyStaffId = mRes.body.id;

    await request(app)
      .put(`/api/staff-pay/${monthlyStaffId}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ monthly_salary: 60000, salary_due_day: 28, pay_frequency: 'mensuel' });

    // 3. Products Catalog
    const p1 = await request(app)
      .post('/api/products')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({
        category: 'parfum',
        name: 'Parfum Royal 100ml',
        price: 15000,
        cost_price: 8000,
        quantity: 10,
      });
    perfumeId = p1.body.id;

    const p2 = await request(app)
      .post('/api/products')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({
        category: 'chaussure',
        name: 'Mocassins Cuir',
        price: 25000,
        cost_price: 12000,
        quantity: 5,
      });
    shoesId = p2.body.id;

    // 4. Ready to wear model
    const m1 = await request(app)
      .post('/api/pret-a-porter')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({
        name: 'Grand Boubou Bazin Riche',
        price: 40000,
        cost_price: 18000,
      });
    boubouId = m1.body.id;
  });

  test('Simulates a complete real-world day and verifies every single financial total', async () => {
    const today = new Date().toISOString().slice(0, 10);

    // -------------------------------------------------------------------------
    // STEP A: Multi-item counter sale by Secretary
    // 2 Perfumes (2 * 15,000 = 30,000; cost: 16,000)
    // 1 Shoes with VIP discount at 22,000 (cost: 12,000)
    // -------------------------------------------------------------------------
    const receiptRes = await request(app)
      .post('/api/sales/receipts')
      .set('Authorization', `Bearer ${secretaryToken}`)
      .send({
        client_name: 'Client VIP Alpha',
        lines: [
          { kind: 'produit', item_id: perfumeId, qty: 2 },
          { kind: 'produit', item_id: shoesId, qty: 1, unit_price: 22000 },
        ],
      });

    expect(receiptRes.status).toBe(201);
    expect(receiptRes.body.total).toBe(52000);
    // Secretary must NEVER see unit_cost or cost_total
    for (const line of receiptRes.body.lines) {
      expect(line.unit_cost).toBeUndefined();
      expect(line.cost_total).toBeUndefined();
    }

    const perfumeSaleId = receiptRes.body.lines.find((l) => l.item_id === perfumeId).id;

    // Check inventory after sale
    const stockP1 = await db.query('SELECT quantity FROM products WHERE id = $1', [perfumeId]);
    expect(stockP1.rows[0].quantity).toBe(8); // 10 - 2

    // -------------------------------------------------------------------------
    // STEP B: Sale Correction (Customer returns 1 perfume)
    // -------------------------------------------------------------------------
    const corrRes = await request(app)
      .post(`/api/sales/${perfumeSaleId}/corrections`)
      .set('Authorization', `Bearer ${secretaryToken}`)
      .send({
        new_qty: 1,
        reason: 'Client ne prend finalement qu’un seul flacon',
      });
    expect(corrRes.status).toBe(201);

    // Check inventory after correction (restocked by 1)
    const stockP1After = await db.query('SELECT quantity FROM products WHERE id = $1', [perfumeId]);
    expect(stockP1After.rows[0].quantity).toBe(9); // 8 + 1

    // -------------------------------------------------------------------------
    // STEP C: Ready-to-wear sale
    // 1 Grand Boubou @ 40,000 (cost: 18,000)
    // -------------------------------------------------------------------------
    const rtwSale = await request(app)
      .post('/api/sales')
      .set('Authorization', `Bearer ${secretaryToken}`)
      .send({
        kind: 'pret_a_porter',
        item_id: boubouId,
        qty: 1,
      });
    expect(rtwSale.status).toBe(201);

    // -------------------------------------------------------------------------
    // STEP D: Tailoring Order with Advance Payment
    // Order total: 100,000 FCFA, Advance collected: 40,000 FCFA
    // -------------------------------------------------------------------------
    const clientRes = await request(app)
      .post('/api/clients')
      .set('Authorization', `Bearer ${secretaryToken}`)
      .send({ full_name: 'Ousmane Traore', phone: '76112233' });
    const clientId = clientRes.body.id;

    const orderRes = await request(app)
      .post('/api/orders')
      .set('Authorization', `Bearer ${secretaryToken}`)
      .send({
        client_id: clientId,
        tailor_id: tailorId,
        advance: 40000,
        expected_date: '2026-08-30',
        items: [
          { garment_type: 'Grand Boubou', quantity: 2, unit_price: 50000 },
        ],
      });
    expect(orderRes.status).toBe(201);

    // -------------------------------------------------------------------------
    // STEP E: Wholesale Order & Payment
    // Wholesale total: 150,000 FCFA, Advance collected: 50,000 FCFA
    // -------------------------------------------------------------------------
    const merchantRes = await request(app)
      .post('/api/wholesale/merchants')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ full_name: 'Boutique Alpha Grossiste', phone: '70998877' });
    const merchantId = merchantRes.body.id;

    const wholesaleRes = await request(app)
      .post('/api/wholesale/orders')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({
        merchant_id: merchantId,
        total_amount: 150000,
        advance_amount: 50000,
        items_description: '10 Boubous prêt-à-porter',
      });
    expect(wholesaleRes.status).toBe(201);

    // -------------------------------------------------------------------------
    // STEP F: Tailor Piece-Work Daily Entry
    // 4 pieces @ 2,500 FCFA = 10,000 FCFA
    // -------------------------------------------------------------------------
    const tailorEntryRes = await request(app)
      .post('/api/tailor-entries')
      .set('Authorization', `Bearer ${secretaryToken}`)
      .send({
        tailor_id: tailorId,
        entry_date: today,
        garment_type: 'Grand Boubou',
        pieces: 4,
        piece_rate: 2500,
      });
    expect(tailorEntryRes.status).toBe(201);

    // -------------------------------------------------------------------------
    // STEP G: Manual Workshop Expense
    // Threads & electricity = 7,000 FCFA
    // -------------------------------------------------------------------------
    const expRes = await request(app)
      .post('/api/expenses')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({
        reason: 'Achat fils et électricité atelier',
        amount: 7000,
        spent_at: today,
      });
    expect(expRes.status).toBe(201);

    // -------------------------------------------------------------------------
    // STEP H: VERIFY COMPLETE FINANCIALS IN /api/finance/summary & /api/reports/summary
    // -------------------------------------------------------------------------
    const finRes = await request(app)
      .get(`/api/finance/summary?from=${today}&to=${today}`)
      .set('Authorization', `Bearer ${managerToken}`);

    expect(finRes.status).toBe(200);
    const { revenue, costs, net_profit } = finRes.body;

    // Exact Hand-derived expectations:
    // Sales Revenue = 15,000 (1 perfume) + 22,000 (1 shoes) + 40,000 (1 boubou) = 77,000
    expect(revenue.sales).toBe(77000);
    // Order Revenue = 40,000 (cash advance)
    expect(revenue.orders).toBe(40000);
    // Wholesale Revenue = 50,000 (cash advance)
    expect(revenue.wholesale).toBe(50000);
    // Total Revenue = 77,000 + 40,000 + 50,000 = 167,000
    expect(revenue.total).toBe(167000);

    // COGS = 8,000 (1 perfume) + 12,000 (1 shoes) + 18,000 (1 boubou) = 38,000
    expect(costs.cost_of_goods_sold).toBe(38000);
    // Tailor Wages = 4 * 2,500 = 10,000
    expect(costs.tailor_wages).toBe(10000);
    // Expenses = 7,000
    expect(costs.expenses).toBe(7000);

    // Salaries:
    // Monthly: 60,000 / (days in month = 31 in Aug) = 1,935 FCFA
    // Weekly: 14,000 / 7 * 1 day = 2,000 FCFA
    // Total Salaries = 1,935 + 2,000 = 3,935 FCFA
    const daysInCurrentMonth = new Date(
      new Date().getUTCFullYear(),
      new Date().getUTCMonth() + 1,
      0
    ).getUTCDate();
    const expectedMonthly = Math.round(60000 / daysInCurrentMonth);
    const expectedWeekly = 2000;
    const expectedSalaries = expectedMonthly + expectedWeekly;
    expect(costs.salaries).toBe(expectedSalaries);

    // Total Costs = 38,000 + 10,000 + 7,000 + expectedSalaries
    const expectedTotalCosts = 38000 + 10000 + 7000 + expectedSalaries;
    expect(costs.total).toBe(expectedTotalCosts);

    // Net Profit = 167,000 - expectedTotalCosts
    expect(net_profit).toBe(167000 - expectedTotalCosts);

    // Reports summary must return identical numbers
    const repRes = await request(app)
      .get(`/api/reports/summary?from=${today}&to=${today}`)
      .set('Authorization', `Bearer ${managerToken}`);
    expect(repRes.status).toBe(200);
    expect(repRes.body.revenue).toEqual(revenue);
    expect(repRes.body.costs).toEqual(costs);
    expect(repRes.body.net_profit).toBe(net_profit);

    // -------------------------------------------------------------------------
    // STEP I: RBAC ISOLATION CHECKS
    // -------------------------------------------------------------------------
    // 1. Secretary calling /api/finance => 403
    const secFin = await request(app)
      .get(`/api/finance/summary?from=${today}&to=${today}`)
      .set('Authorization', `Bearer ${secretaryToken}`);
    expect(secFin.status).toBe(403);

    // 2. Secretary calling /api/reports => 403
    const secRep = await request(app)
      .get(`/api/reports/summary?from=${today}&to=${today}`)
      .set('Authorization', `Bearer ${secretaryToken}`);
    expect(secRep.status).toBe(403);

    // 3. Secretary calling /api/wholesale => 403
    const secWholesale = await request(app)
      .get('/api/wholesale/orders')
      .set('Authorization', `Bearer ${secretaryToken}`);
    expect(secWholesale.status).toBe(403);

    // 4. Secretary reading /api/sales list => rows stripped of cost
    const secSales = await request(app)
      .get('/api/sales')
      .set('Authorization', `Bearer ${secretaryToken}`);
    expect(secSales.status).toBe(200);
    for (const item of secSales.body.items) {
      expect(item.unit_cost).toBeUndefined();
      expect(item.cost_total).toBeUndefined();
    }
  });
});
