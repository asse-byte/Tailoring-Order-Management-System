// =============================================================================
// Couture Mali — API security tests
// =============================================================================
// Ports the 29 Firestore-rules guarantees 1:1 to the SQL backend, plus
// SQL-only guarantees (append-only triggers, server-side pricing).
// The single non-negotiable requirement: the SECRETARY must never be able
// to read any financial data — verified here against the real API + a real
// PostgreSQL, bypassing the Flutter UI entirely.
// =============================================================================

const request = require('supertest');
const jwt = require('jsonwebtoken');
const { createApp } = require('../src/app');
const db = require('../src/db');
const { MANAGER, SECRETARY, seedUsers, login } = require('./helpers');

let app;
let ids;               // { MANAGER: uuid, SECRETARY: uuid }
let managerToken;
let secToken;

// Seeded fixtures shared across tests.
let clientId;
let productId;
let modelId;
let tailorId;
let entryId;
let expenseId;
let orderId;

const asManager = (r) => r.set('Authorization', `Bearer ${managerToken}`);
const asSec = (r) => r.set('Authorization', `Bearer ${secToken}`);

beforeAll(async () => {
  app = createApp();
  ids = await seedUsers();
  managerToken = await login(app, MANAGER);
  secToken = await login(app, SECRETARY);

  // Fixtures created as the manager (the happy path is asserted implicitly).
  clientId = (await asManager(request(app).post('/api/clients'))
    .send({ full_name: 'Amadou Traoré', phone: '70000000' })).body.id;
  productId = (await asManager(request(app).post('/api/products'))
    .send({ category: 'tissu', name: 'Bazin riche', price: 15000, quantity: 10 })).body.id;
  modelId = (await asManager(request(app).post('/api/pret-a-porter'))
    .send({ name: 'Boubou brodé', fabric_type: 'bazin', price: 45000 })).body.id;
  tailorId = (await asManager(request(app).post('/api/staff'))
    .send({ full_name: 'Moussa Keïta', phone: '76000000', type: 'couturier' })).body.id;
  await asManager(request(app).put(`/api/staff-pay/${tailorId}`))
    .send({ piece_rate: 2000 });
  entryId = (await asManager(request(app).post('/api/tailor-entries'))
    .send({ tailor_id: tailorId, entry_date: '2026-07-01', pieces_count: 4 })).body.id;
  expenseId = (await asManager(request(app).post('/api/expenses'))
    .send({ reason: 'Loyer', amount: 100000, spent_at: '2026-07-01' })).body.id;
  orderId = (await asManager(request(app).post('/api/orders'))
    .send({ client_id: clientId, fabric: 'bazin', advance: 10000,
      items: [{ garment_type: 'boubou', quantity: 1, unit_price: 30000 }] })).body.id;
});

afterAll(async () => {
  await db.closePool();
});

// =============================================================================
// 1. FINANCIAL ISOLATION — the secretary must get 403, always.
// =============================================================================

describe('SECRETARY — financial routes are completely blocked (403)', () => {
  const NIL = '00000000-0000-0000-0000-000000000000';
  const financialReads = [
    ['GET', '/api/sales'],
    ['GET', `/api/sales/${NIL}/corrections`],
    ['GET', '/api/expenses'],
    ['GET', '/api/staff-pay'],
    ['GET', `/api/staff-pay/${NIL}/history`],
    ['GET', '/api/salary-payments'],
    ['GET', `/api/salary-payments/${NIL}/corrections`],
    ['GET', '/api/tailor-entries'],
    ['GET', '/api/tailor-entries/weekly?week_id=2026-W27'],
    ['GET', '/api/tailor-entries/monthly?month=2026-07'],
    ['GET', `/api/tailor-entries/weekly-detail?week_id=2026-W27&tailor_id=${NIL}`],
    ['GET', '/api/finance/summary'],
    ['GET', '/api/reports/summary'],
    ['GET', '/api/settings/private'],
    ['GET', '/api/users'],
  ];
  it.each(financialReads)('%s %s → 403', async (method, url) => {
    const res = await asSec(request(app)[method.toLowerCase()](url));
    expect(res.status).toBe(403);
  });

  it('cannot create an expense', async () => {
    const res = await asSec(request(app).post('/api/expenses'))
      .send({ reason: 'x', amount: 1 });
    expect(res.status).toBe(403);
  });

  it('cannot create a tailor daily entry or a correction', async () => {
    const e = await asSec(request(app).post('/api/tailor-entries'))
      .send({ tailor_id: tailorId, entry_date: '2026-07-02', pieces_count: 3 });
    expect(e.status).toBe(403);
    const c = await asSec(request(app).post(`/api/tailor-entries/${entryId}/corrections`))
      .send({ new_pieces: 9, reason: 'tentative' });
    expect(c.status).toBe(403);
  });

  it('cannot set piece rates or salaries', async () => {
    const res = await asSec(request(app).put(`/api/staff-pay/${tailorId}`))
      .send({ piece_rate: 1 });
    expect(res.status).toBe(403);
  });

  it('cannot correct a sale (corrections are manager-only)', async () => {
    const res = await asSec(
      request(app).post(`/api/sales/${NIL}/corrections`))
      .send({ new_qty: 1, reason: 'tentative' });
    expect(res.status).toBe(403);
  });

  it('cannot create users or change passwords of others', async () => {
    const res = await asSec(request(app).post('/api/users'))
      .send({ username: 'hack', password: 'longenough1', role: 'MANAGER' });
    expect(res.status).toBe(403);
    const pw = await asSec(request(app).put(`/api/users/${ids.MANAGER}/password`))
      .send({ new_password: 'longenough1' });
    expect(pw.status).toBe(403);
  });
});

// =============================================================================
// 2. SECRETARY — daily operations she IS allowed to do.
// =============================================================================

describe('SECRETARY — allowed daily operations', () => {
  it('can read, create and update clients', async () => {
    expect((await asSec(request(app).get('/api/clients'))).status).toBe(200);
    const created = await asSec(request(app).post('/api/clients'))
      .send({ full_name: 'Fatoumata Diallo', phone: '65000000' });
    expect(created.status).toBe(201);
    const updated = await asSec(request(app).put(`/api/clients/${created.body.id}`))
      .send({ full_name: 'Fatoumata Diallo', phone: '65000001' });
    expect(updated.status).toBe(200);
  });

  it('can manage client measurements (flexible key-value)', async () => {
    const res = await asSec(
      request(app).put(`/api/clients/${clientId}/measurements/boubou`))
      .send({ measures: { epaule: 45, poitrine: 102, manche: 61 } });
    expect(res.status).toBe(200);
    expect(res.body.measures.poitrine).toBe(102);
  });

  it('can edit the custom-garments catalog (INTENTIONAL — measurement workflow)', async () => {
    // Deliberate design, twice questioned in review: while taking a client's
    // measurements the secretary may create a new garment type on the spot
    // (client_detail_screen → saveCustomGarments). The catalog is garment
    // names + measurement fields — NOT financial data — so it is shared by
    // both roles. Do not restrict this PUT to the manager without redesigning
    // that workflow.
    const catalog = {
      homme: { 'Veste croisée': ['epaule', 'poitrine', 'manche'] },
      femme: {},
    };
    const put = await asSec(
      request(app).put('/api/clients/settings/custom-garments')).send(catalog);
    expect(put.status).toBe(200);
    const get = await asSec(
      request(app).get('/api/clients/settings/custom-garments'));
    expect(get.status).toBe(200);
    expect(get.body.homme['Veste croisée']).toEqual(['epaule', 'poitrine', 'manche']);

    // The guard that actually matters stays shut: private settings (finance,
    // piece rates…) remain manager-only for every method.
    expect((await asSec(request(app).get('/api/settings/private'))).status).toBe(403);
    expect((await asSec(request(app).put('/api/settings/private'))
      .send({ default_piece_rate: 1 })).status).toBe(403);
  });

  it('can read products and prêt-à-porter (to sell at the counter)', async () => {
    expect((await asSec(request(app).get('/api/products'))).status).toBe(200);
    expect((await asSec(request(app).get('/api/pret-a-porter'))).status).toBe(200);
  });

  it('never receives cost_price / profit on products or prêt-à-porter', async () => {
    // The manager records a purchase price on a fresh product + model.
    const prod = await asManager(request(app).post('/api/products'))
      .send({ category: 'parfum', name: 'Parfum Oud', price: 20000, cost_price: 12000, quantity: 5 });
    expect(prod.status).toBe(201);
    const model = await asManager(request(app).post('/api/pret-a-porter'))
      .send({ name: 'Kaftan luxe', fabric_type: 'soie', price: 60000, cost_price: 35000 });
    expect(model.status).toBe(201);

    // The manager sees cost_price — it is what lets the app compute profit.
    const mgrProd = (await asManager(request(app).get('/api/products')))
      .body.items.find((p) => p.id === prod.body.id);
    expect(mgrProd.cost_price).toBe(12000);
    const mgrModel = (await asManager(request(app).get('/api/pret-a-porter')))
      .body.items.find((m) => m.id === model.body.id);
    expect(mgrModel.cost_price).toBe(35000);

    // The secretary must NEVER receive cost_price on either read endpoint.
    const secProducts = await asSec(request(app).get('/api/products'));
    expect(secProducts.status).toBe(200);
    for (const p of secProducts.body.items) expect(p).not.toHaveProperty('cost_price');
    const secModels = await asSec(request(app).get('/api/pret-a-porter'));
    expect(secModels.status).toBe(200);
    for (const m of secModels.body.items) expect(m).not.toHaveProperty('cost_price');
    // Belt and suspenders: no cost figure anywhere in the raw payloads.
    expect(JSON.stringify(secProducts.body)).not.toMatch(/cost_price/);
    expect(JSON.stringify(secModels.body)).not.toMatch(/cost_price/);
  });

  it('cannot create, edit or delete products', async () => {
    expect((await asSec(request(app).post('/api/products'))
      .send({ category: 'parfum', name: 'x', price: 1 })).status).toBe(403);
    expect((await asSec(request(app).put(`/api/products/${productId}`))
      .send({ category: 'tissu', name: 'Bazin', price: 1, quantity: 999 })).status).toBe(403);
    expect((await asSec(request(app).delete(`/api/products/${productId}`))).status).toBe(403);
  });

  it('can manage staff contacts read-only', async () => {
    const list = await asSec(request(app).get('/api/staff'));
    expect(list.status).toBe(200);
    // Contact info only — no pay fields in the payload.
    expect(JSON.stringify(list.body)).not.toMatch(/piece_rate|monthly_salary/);
    expect((await asSec(request(app).post('/api/staff'))
      .send({ full_name: 'X', type: 'autre' })).status).toBe(403);
  });

  it('can create and update orders; invalid status rejected; delete denied', async () => {
    const created = await asSec(request(app).post('/api/orders'))
      .send({ client_id: clientId,
        items: [{ garment_type: 'chemise', quantity: 1, unit_price: 20000 }] });
    expect(created.status).toBe(201);
    expect((await asSec(request(app).put(`/api/orders/${created.body.id}`))
      .send({ status: 'livre' })).status).toBe(200);
    expect((await asSec(request(app).put(`/api/orders/${created.body.id}`))
      .send({ status: 'invalide' })).status).toBe(400);
    expect((await asSec(request(app).delete(`/api/orders/${created.body.id}`))).status)
      .toBe(403);
  });

  it('Historique: delivered orders filter by client and by date', async () => {
    const created = await asSec(request(app).post('/api/orders'))
      .send({ client_id: clientId,
        items: [{ garment_type: 'veste', quantity: 1, unit_price: 25000 }] });
    await asSec(request(app).put(`/api/orders/${created.body.id}`))
      .send({ status: 'livre' });

    const today = new Date().toISOString().slice(0, 10);
    const inRange = await asSec(request(app)
      .get(`/api/orders?status=livre&client_id=${clientId}&from=${today}&to=${today}`));
    expect(inRange.status).toBe(200);
    expect(inRange.body.items.some((o) => o.id === created.body.id)).toBe(true);

    const outOfRange = await asSec(request(app)
      .get('/api/orders?status=livre&from=2020-01-01&to=2020-12-31'));
    expect(outOfRange.body.items).toHaveLength(0);
  });

  it('can manage appointments', async () => {
    const created = await asSec(request(app).post('/api/appointments'))
      .send({ client_id: clientId, scheduled_at: '2026-07-10T10:00:00Z', reason: 'essayage' });
    expect(created.status).toBe(201);
    expect((await asSec(request(app).delete(`/api/appointments/${created.body.id}`))).status)
      .toBe(204);
  });

  it('can upload an image — compressed copy + thumbnail are produced', async () => {
    const { Jimp } = require('jimp');
    const png = await new Jimp({ width: 900, height: 600, color: 0x336699ff })
      .getBuffer('image/png');
    const res = await asSec(request(app).post('/api/upload'))
      .attach('file', png, 'photo.png');
    expect(res.status).toBe(201);
    expect(res.body.url).toMatch(/^\/uploads\/.+\.png$/);
    expect(res.body.thumb_url).toMatch(/^\/uploads\/thumb_.+\.png$/);

    const fs = require('fs');
    const path = require('path');
    const uploadsDir = path.join(__dirname, '../uploads');
    const mainPath = path.join(uploadsDir, path.basename(res.body.url));
    const thumbPath = path.join(uploadsDir, path.basename(res.body.thumb_url));
    expect(fs.existsSync(mainPath)).toBe(true);
    expect(fs.existsSync(thumbPath)).toBe(true);

    // Speed rule: the stored image is resized down, the thumbnail further.
    const main = await Jimp.fromBuffer(fs.readFileSync(mainPath));
    const thumb = await Jimp.fromBuffer(fs.readFileSync(thumbPath));
    expect(main.width).toBeLessThanOrEqual(800);
    expect(thumb.width).toBeLessThanOrEqual(150);

    fs.unlinkSync(mainPath);
    fs.unlinkSync(thumbPath);
  });

  it('non-media uploads are rejected (public /uploads must never host scripts)', async () => {
    for (const name of ['note.txt', 'page.html', 'tool.exe']) {
      const res = await asSec(request(app).post('/api/upload'))
        .attach('file', Buffer.from('hello world'), name);
      expect(res.status).toBe(400);
    }
  });
});

// =============================================================================
// 3. SALES — write-only for the secretary, atomic, server-priced.
// =============================================================================

describe('Sales — server-side pricing and atomic stock', () => {
  it('secretary can register a sale; stock decrements atomically', async () => {
    const res = await asSec(request(app).post('/api/sales'))
      .send({ kind: 'produit', item_id: productId, qty: 2 });
    expect(res.status).toBe(201);
    const { rows } = await db.query('SELECT quantity FROM products WHERE id = $1', [productId]);
    expect(rows[0].quantity).toBe(8); // 10 - 2
  });

  it('any price/total sent by the client is IGNORED — the DB prices the sale', async () => {
    await asSec(request(app).post('/api/sales'))
      .send({ kind: 'produit', item_id: productId, qty: 1, unit_price: 1, total: 1 });
    const { rows } = await db.query(
      'SELECT unit_price, total FROM sales ORDER BY sold_at DESC LIMIT 1');
    expect(rows[0].unit_price).toBe(15000);
    expect(rows[0].total).toBe(15000);
  });

  it('sale beyond stock → 409 and stock unchanged', async () => {
    const before = (await db.query(
      'SELECT quantity FROM products WHERE id = $1', [productId])).rows[0].quantity;
    const res = await asSec(request(app).post('/api/sales'))
      .send({ kind: 'produit', item_id: productId, qty: 9999 });
    expect(res.status).toBe(409);
    const after = (await db.query(
      'SELECT quantity FROM products WHERE id = $1', [productId])).rows[0].quantity;
    expect(after).toBe(before);
  });

  it('prêt-à-porter models keep description, images and optional video', async () => {
    const created = await asManager(request(app).post('/api/pret-a-porter'))
      .send({
        name: 'Ensemble Wax',
        fabric_type: 'wax',
        price: 60000,
        description: 'Deux pièces, broderie col',
        media: [
          { url: '/uploads/wax1.jpg', kind: 'image', thumb_url: '/uploads/thumb_wax1.jpg' },
          { url: '/uploads/wax-demo.mp4', kind: 'video' },
        ],
      });
    expect(created.status).toBe(201);
    expect(created.body.description).toBe('Deux pièces, broderie col');
    expect(created.body.media).toHaveLength(2);

    const list = await asSec(request(app).get('/api/pret-a-porter'));
    const model = list.body.items.find((m) => m.id === created.body.id);
    expect(model.media.map((m) => m.kind).sort()).toEqual(['image', 'video']);

    // PUT replaces the media list atomically.
    const updated = await asManager(
      request(app).put(`/api/pret-a-porter/${created.body.id}`))
      .send({
        name: 'Ensemble Wax',
        fabric_type: 'wax',
        price: 60000,
        description: 'Deux pièces',
        media: [{ url: '/uploads/wax2.jpg', kind: 'image' }],
      });
    expect(updated.status).toBe(200);
    expect(updated.body.media).toHaveLength(1);
    expect(updated.body.media[0].url).toBe('/uploads/wax2.jpg');
  });

  it('prêt-à-porter sales work and are priced from the model', async () => {
    const res = await asSec(request(app).post('/api/sales'))
      .send({ kind: 'pret_a_porter', item_id: modelId, qty: 1, total: 5 });
    expect(res.status).toBe(201);
    const { rows } = await db.query(
      "SELECT total FROM sales WHERE kind = 'pret_a_porter' ORDER BY sold_at DESC LIMIT 1");
    expect(rows[0].total).toBe(45000);
  });

  it('manager reads the sales history; secretary already proven 403', async () => {
    const res = await asManager(request(app).get('/api/sales'));
    expect(res.status).toBe(200);
    expect(res.body.items.length).toBeGreaterThanOrEqual(3);
  });
});

// =============================================================================
// 3b. SALES follow the same append-only + correction-log principle.
// =============================================================================

describe('Sales — append-only with correction log (project principle)', () => {
  let corrProductId;
  let corrSaleId;

  beforeAll(async () => {
    corrProductId = (await asManager(request(app).post('/api/products'))
      .send({ category: 'parfum', name: 'Oud Royal', price: 10000, quantity: 10 })).body.id;
    await asSec(request(app).post('/api/sales'))
      .send({ kind: 'produit', item_id: corrProductId, qty: 5 });
    const { rows } = await db.query(
      'SELECT id FROM sales WHERE item_id = $1', [corrProductId]);
    corrSaleId = rows[0].id;
  });

  const stockOf = async (id) => (await db.query(
    'SELECT quantity FROM products WHERE id = $1', [id])).rows[0].quantity;

  it('there is NO update/delete route for sales', async () => {
    expect((await asManager(request(app).put(`/api/sales/${corrSaleId}`))
      .send({ qty: 1 })).status).toBe(404);
    expect((await asManager(request(app).delete(`/api/sales/${corrSaleId}`))).status)
      .toBe(404);
  });

  it('correction requires a reason', async () => {
    const res = await asManager(
      request(app).post(`/api/sales/${corrSaleId}/corrections`))
      .send({ new_qty: 2 });
    expect(res.status).toBe(400);
  });

  it('qty correction updates effective total, restores stock, keeps the original', async () => {
    expect(await stockOf(corrProductId)).toBe(5); // 10 - 5 sold

    const ok = await asManager(
      request(app).post(`/api/sales/${corrSaleId}/corrections`))
      .send({ new_qty: 2, reason: 'Erreur de saisie: 2 flacons vendus, pas 5' });
    expect(ok.status).toBe(201);
    expect(ok.body.old_qty).toBe(5);

    // 3 units back on the shelf, effective total recomputed.
    expect(await stockOf(corrProductId)).toBe(8);
    const { rows: eff } = await db.query(
      'SELECT qty, total, corrected FROM sales_effective WHERE id = $1', [corrSaleId]);
    expect(eff[0].qty).toBe(2);
    expect(eff[0].total).toBe(2 * 10000);
    expect(eff[0].corrected).toBe(true);

    // Original row untouched — full audit trail.
    const { rows: orig } = await db.query(
      'SELECT qty, total FROM sales WHERE id = $1', [corrSaleId]);
    expect(orig[0].qty).toBe(5);
    expect(orig[0].total).toBe(5 * 10000);
  });

  it('voiding a sale returns remaining units and excludes it from revenue', async () => {
    const ok = await asManager(
      request(app).post(`/api/sales/${corrSaleId}/corrections`))
      .send({ voided: true, reason: 'Vente annulée: client remboursé' });
    expect(ok.status).toBe(201);

    expect(await stockOf(corrProductId)).toBe(10); // everything back
    const { rows: eff } = await db.query(
      'SELECT voided FROM sales_effective WHERE id = $1', [corrSaleId]);
    expect(eff[0].voided).toBe(true);

    // Voided sales contribute nothing to the finance summary.
    const today = new Date().toISOString().slice(0, 10);
    const sum = await asManager(request(app)
      .get(`/api/finance/summary?from=${today}&to=${today}`));
    const { rows: contrib } = await db.query(
      `SELECT COALESCE(SUM(total), 0)::int AS v FROM sales_effective
       WHERE NOT voided AND item_id = $1`, [corrProductId]);
    expect(contrib[0].v).toBe(0);
    expect(sum.status).toBe(200);

    const history = await asManager(
      request(app).get(`/api/sales/${corrSaleId}/corrections`));
    expect(history.body.items).toHaveLength(2);
    history.body.items.forEach((c) => expect(c.reason.length).toBeGreaterThan(0));
  });

  it('pay-rate changes are journaled in staff_pay_history (who/when/from→to)', async () => {
    await asManager(request(app).put(`/api/staff-pay/${tailorId}`))
      .send({ piece_rate: 2200 });
    const res = await asManager(
      request(app).get(`/api/staff-pay/${tailorId}/history`));
    expect(res.status).toBe(200);
    expect(res.body.items.length).toBeGreaterThanOrEqual(2); // seed + this change
    expect(res.body.items[0].new_piece_rate).toBe(2200);
    expect(res.body.items[0].changed_by_name).toBeTruthy();
  });
});

// =============================================================================
// 4. MANAGER — full access + append-only audit trail with correction log.
// =============================================================================

describe('MANAGER — financial access and audit trail', () => {
  it('reads all financial data', async () => {
    for (const url of ['/api/sales', '/api/expenses', '/api/staff-pay',
      '/api/tailor-entries', '/api/finance/summary', '/api/settings/private']) {
      expect((await asManager(request(app).get(url))).status).toBe(200);
    }
  });

  it('daily entry amount is computed by the DB (pieces × snapshotted rate)', async () => {
    const { rows } = await db.query(
      'SELECT pieces_count, piece_rate, amount FROM tailor_daily_entries WHERE id = $1',
      [entryId]);
    expect(rows[0].amount).toBe(rows[0].pieces_count * rows[0].piece_rate);
    expect(rows[0].amount).toBe(4 * 2000);
  });

  it('a tailor can have several itemised entries on the same day', async () => {
    // Item 6: the one-entry-per-day rule was removed so a tailor can log
    // different garment types on the same day. Uses a dedicated tailor so the
    // shared weekly/finance totals below stay clean.
    const t = (await asManager(request(app).post('/api/staff'))
      .send({ full_name: 'Multi Jour', phone: '76000099', type: 'couturier' })).body.id;
    await asManager(request(app).put(`/api/staff-pay/${t}`)).send({ piece_rate: 1000 });
    // Dated in August so it stays out of the July finance-summary window and
    // the 2026-W27 weekly totals asserted by other tests.
    const a = await asManager(request(app).post('/api/tailor-entries'))
      .send({ tailor_id: t, entry_date: '2026-08-03', pieces_count: 2, garment_type: 'Grand Boubou' });
    const b = await asManager(request(app).post('/api/tailor-entries'))
      .send({ tailor_id: t, entry_date: '2026-08-03', pieces_count: 3, garment_type: 'Chemise' });
    expect(a.status).toBe(201);
    expect(b.status).toBe(201);
  });

  it('there is NO update/delete route for entries — correction log only', async () => {
    expect((await asManager(request(app).put(`/api/tailor-entries/${entryId}`))
      .send({ pieces_count: 9 })).status).toBe(404);
    expect((await asManager(request(app).delete(`/api/tailor-entries/${entryId}`))).status)
      .toBe(404);
  });

  it('correction requires a reason, changes the effective value, keeps the original', async () => {
    const noReason = await asManager(
      request(app).post(`/api/tailor-entries/${entryId}/corrections`))
      .send({ new_pieces: 6 });
    expect(noReason.status).toBe(400);

    const ok = await asManager(
      request(app).post(`/api/tailor-entries/${entryId}/corrections`))
      .send({ new_pieces: 6, reason: 'Erreur de saisie: 6 pièces, pas 4' });
    expect(ok.status).toBe(201);
    expect(ok.body.old_pieces).toBe(4);

    const effective = await asManager(
      request(app).get(`/api/tailor-entries?tailor_id=${tailorId}`));
    const entry = effective.body.items.find((e) => e.id === entryId);
    expect(entry.pieces_count).toBe(6);
    expect(entry.amount).toBe(6 * 2000);
    expect(entry.corrected).toBe(true);

    // The original row is untouched — full audit trail.
    const { rows } = await db.query(
      'SELECT pieces_count FROM tailor_daily_entries WHERE id = $1', [entryId]);
    expect(rows[0].pieces_count).toBe(4);

    const history = await asManager(
      request(app).get(`/api/tailor-entries/${entryId}/corrections`));
    expect(history.body.items).toHaveLength(1);
    expect(history.body.items[0].reason).toMatch(/Erreur de saisie/);
  });

  it('weekly totals use the corrected value', async () => {
    const res = await asManager(
      request(app).get('/api/tailor-entries/weekly?week_id=2026-W27'));
    const row = res.body.items.find((r) => r.tailor_id === tailorId);
    expect(row.amount_total).toBe(6 * 2000);
  });

  it('expenses: corrected/voided with mandatory reason, never edited', async () => {
    const noReason = await asManager(
      request(app).post(`/api/expenses/${expenseId}/corrections`))
      .send({ new_amount: 90000 });
    expect(noReason.status).toBe(400);

    const ok = await asManager(
      request(app).post(`/api/expenses/${expenseId}/corrections`))
      .send({ new_amount: 90000, reason: 'Facture réelle: 90 000, pas 100 000' });
    expect(ok.status).toBe(201);

    const list = await asManager(request(app).get('/api/expenses?from=2026-07-01&to=2026-07-01'));
    const exp = list.body.items.find((e) => e.id === expenseId);
    expect(exp.amount).toBe(90000);
    expect(exp.corrected).toBe(true);
  });

  it('finance summary aggregates effective (corrected) values', async () => {
    const res = await asManager(
      request(app).get('/api/finance/summary?from=2026-07-01&to=2026-07-31'));
    expect(res.status).toBe(200);
    expect(res.body.costs.tailor_wages).toBe(6 * 2000);
    expect(res.body.costs.expenses).toBe(90000);
    expect(res.body.net_profit).toBe(
      res.body.revenue.total - res.body.costs.total);
  });
});

// =============================================================================
// 5. DATABASE-LEVEL immutability — even raw SQL cannot rewrite history.
// =============================================================================

describe('Append-only triggers (direct SQL, bypassing the API)', () => {
  const appendOnlyTables = [
    ['tailor_daily_entries', 'pieces_count = 999'],
    ['expenses', 'amount = 1'],
    ['sales', 'qty = 999'],
    ['entry_corrections', 'new_pieces = 999'],
    ['expense_corrections', 'new_amount = 1'],
    ['sale_corrections', 'new_qty = 999'],
    ['staff_pay_history', 'new_piece_rate = 1'],
  ];

  it.each(appendOnlyTables)('UPDATE %s raises', async (table, setClause) => {
    await expect(db.query(`UPDATE ${table} SET ${setClause}`))
      .rejects.toThrow(/append-only/);
  });

  it.each(appendOnlyTables)('DELETE FROM %s raises', async (table) => {
    await expect(db.query(`DELETE FROM ${table}`))
      .rejects.toThrow(/append-only/);
  });
});

// =============================================================================
// 6. AUTHENTICATION — tokens, tampering, public surface.
// =============================================================================

describe('Authentication and token integrity', () => {
  it('unauthenticated: only login and public settings are reachable', async () => {
    expect((await request(app).get('/api/settings/public')).status).toBe(200);
    for (const url of ['/api/clients', '/api/orders', '/api/sales',
      '/api/finance/summary', '/api/products']) {
      expect((await request(app).get(url)).status).toBe(401);
    }
  });

  it('public settings expose only the public keys (shop identity)', async () => {
    const res = await request(app).get('/api/settings/public');
    expect(res.body).toHaveProperty('shop_name');
    expect(res.body).not.toHaveProperty('default_piece_rate');
  });

  it('a token signed with the wrong secret → 401', async () => {
    const forged = jwt.sign({ sub: ids.MANAGER }, 'wrong-secret');
    const res = await request(app).get('/api/clients')
      .set('Authorization', `Bearer ${forged}`);
    expect(res.status).toBe(401);
  });

  it('a role claim inside the token is IGNORED — DB is the source of truth', async () => {
    // Correctly signed token for the secretary, with a forged MANAGER claim.
    const sneaky = jwt.sign(
      { sub: ids.SECRETARY, role: 'MANAGER' }, process.env.JWT_SECRET);
    const res = await request(app).get('/api/finance/summary')
      .set('Authorization', `Bearer ${sneaky}`);
    expect(res.status).toBe(403);
  });

  it('a token for a deleted user → 401', async () => {
    const { rows } = await db.query(
      `INSERT INTO users (username, password_hash, name, role)
       VALUES ('ghost', 'x', 'Ghost', 'MANAGER') RETURNING id`);
    const token = jwt.sign({ sub: rows[0].id }, process.env.JWT_SECRET);
    await db.query('DELETE FROM users WHERE id = $1', [rows[0].id]);
    const res = await request(app).get('/api/clients')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(401);
  });

  it('login rejects bad credentials', async () => {
    const res = await request(app).post('/api/auth/login')
      .send({ username: MANAGER.username, password: 'wrong' });
    expect(res.status).toBe(401);
  });

  it('GET /me restores the session with the DB role', async () => {
    const me = await asSec(request(app).get('/api/auth/me'));
    expect(me.status).toBe(200);
    expect(me.body.user.role).toBe('SECRETARY');
    expect((await request(app).get('/api/auth/me')).status).toBe(401);
  });

  it('self change-password requires the current password', async () => {
    const wrong = await asSec(request(app).post('/api/auth/change-password'))
      .send({ current_password: 'nope', new_password: 'NewPass#1234' });
    expect(wrong.status).toBe(401);

    const ok = await asSec(request(app).post('/api/auth/change-password'))
      .send({ current_password: SECRETARY.password, new_password: 'NewPass#1234' });
    expect(ok.status).toBe(200);
    expect((await request(app).post('/api/auth/login')
      .send({ username: SECRETARY.username, password: 'NewPass#1234' })).status).toBe(200);

    // Restore for any later run against the same DB.
    await asSec(request(app).post('/api/auth/change-password'))
      .send({ current_password: 'NewPass#1234', new_password: SECRETARY.password });
  });
});
