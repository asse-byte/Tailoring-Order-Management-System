// =============================================================================
// Shop-defined product types, and one trip to the till = one receipt.
// =============================================================================
// Two owner requests (2026-08-23):
//   * products were locked to parfum / chaussure / tissu by a CHECK, and the
//     owner must be able to add a type himself (watches and caps were asked
//     for by name) without anyone editing code again;
//   * a customer buying several things produced unrelated sale rows attached to
//     nobody, with no way to print a single invoice.
//
// The receipt path must sell on exactly the same rules as the counter sale:
// server-read prices, atomic stock, frozen purchase cost, append-only history,
// and the secretary never seeing the shop's takings.
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

async function newProduct(category, name, price, cost, qty) {
  const res = await asM(request(app).post('/api/products'))
    .send({ category, name, price, cost_price: cost, quantity: qty });
  expect(res.status).toBe(201);
  return res.body.id;
}

// ---------------------------------------------------------------------------
describe('product types are the shop’s own list', () => {
  test('the five seeded types include the watches and caps that were asked for',
    async () => {
      const res = await asM(request(app).get('/api/product-categories'));
      expect(res.status).toBe(200);
      const slugs = res.body.items.map((c) => c.slug);
      expect(slugs).toEqual(
        expect.arrayContaining(['parfum', 'chaussure', 'tissu', 'montre', 'bonnet']));
    });

  test('the manager adds a type and can immediately sell in it', async () => {
    const created = await asM(request(app).post('/api/product-categories'))
      .send({ label: 'Lunettes de soleil' });
    expect(created.status).toBe(201);
    expect(created.body.slug).toBe('lunettes_de_soleil');

    // The whole point: a brand-new type works with no code change.
    const productId = await newProduct('lunettes_de_soleil', 'Ray-Ban', 45000, 30000, 4);
    const listed = await asM(
      request(app).get('/api/products?category=lunettes_de_soleil'));
    expect(listed.body.items.map((p) => p.id)).toContain(productId);
  });

  test('accents are handled and a duplicate type is refused', async () => {
    const first = await asM(request(app).post('/api/product-categories'))
      .send({ label: 'Écharpes' });
    expect(first.status).toBe(201);
    expect(first.body.slug).toBe('echarpes');

    expect((await asM(request(app).post('/api/product-categories'))
      .send({ label: 'Écharpes' })).status).toBe(409);
  });

  test('a type still holding products cannot be removed', async () => {
    const cat = (await asM(request(app).post('/api/product-categories'))
      .send({ label: 'Ceintures' })).body;
    await newProduct(cat.slug, 'Ceinture cuir', 12000, 7000, 3);

    const refused = await asM(request(app).delete(`/api/product-categories/${cat.id}`));
    expect(refused.status).toBe(409);
    expect(refused.body.error).toMatch(/1 produit/);
  });

  test('an empty type is removed cleanly', async () => {
    const cat = (await asM(request(app).post('/api/product-categories'))
      .send({ label: 'Cravates' })).body;
    expect((await asM(request(app).delete(`/api/product-categories/${cat.id}`))).status)
      .toBe(204);
  });

  test('an unknown type is refused on a product', async () => {
    expect((await asM(request(app).post('/api/products'))
      .send({ category: 'inexistant', name: 'X', price: 1000, quantity: 1 })).status)
      .toBe(400);
  });

  test('the secretary reads the types but cannot change them', async () => {
    expect((await asSec(request(app).get('/api/product-categories'))).status).toBe(200);
    expect((await asSec(request(app).post('/api/product-categories'))
      .send({ label: 'Interdit' })).status).toBe(403);

    const cat = (await asM(request(app).post('/api/product-categories'))
      .send({ label: 'Sacs' })).body;
    expect((await asSec(request(app).put(`/api/product-categories/${cat.id}`))
      .send({ label: 'Sacs à main' })).status).toBe(403);
    expect((await asSec(request(app).delete(`/api/product-categories/${cat.id}`))).status)
      .toBe(403);
  });
});

// ---------------------------------------------------------------------------
describe('one trip to the till = one receipt', () => {
  test('a basket of five different things becomes ONE receipt with one total',
    async () => {
      // Exactly the scenario the owner described.
      const perfume = await newProduct('parfum', 'Oud Royal', 15000, 9000, 10);
      const cap = await newProduct('bonnet', 'Bonnet brodé', 5000, 2500, 10);
      const shoe = await newProduct('chaussure', 'Mocassin', 30000, 20000, 10);
      const watch = await newProduct('montre', 'Montre acier', 40000, 25000, 10);
      const modelId = (await asM(request(app).post('/api/pret-a-porter'))
        .send({ name: 'Boubou brodé', price: 60000, cost_price: 35000 })).body.id;

      const clientId = (await asM(request(app).post('/api/clients'))
        .send({ full_name: 'Client Panier', phone: '76909090' })).body.id;

      const res = await asSec(request(app).post('/api/sales/receipts')).send({
        client_id: clientId,
        lines: [
          { kind: 'pret_a_porter', item_id: modelId, qty: 2 },
          { kind: 'produit', item_id: cap, qty: 1 },
          { kind: 'produit', item_id: shoe, qty: 1 },
          { kind: 'produit', item_id: perfume, qty: 1 },
          { kind: 'produit', item_id: watch, qty: 1 },
        ],
      });
      expect(res.status).toBe(201);

      // 2×60 000 + 5 000 + 30 000 + 15 000 + 40 000 = 210 000
      expect(res.body.total).toBe(210000);
      expect(res.body.items_count).toBe(6);
      expect(res.body.lines).toHaveLength(5);
      expect(res.body.client_name_snapshot).toBe('Client Panier');

      // Stock left the shelves for every product line.
      for (const [id, left] of [[perfume, 9], [cap, 9], [shoe, 9], [watch, 9]]) {
        const { rows } = await db.query('SELECT quantity FROM products WHERE id = $1', [id]);
        expect(rows[0].quantity).toBe(left);
      }

      // And the receipt reads back with all five lines.
      const detail = await asM(request(app).get(`/api/sales/receipts/${res.body.id}`));
      expect(detail.status).toBe(200);
      expect(detail.body.lines).toHaveLength(5);
      expect(detail.body.total).toBe(210000);
      expect(detail.body.items_count).toBe(6);
    });

  test('a walk-in with no client still gets a receipt', async () => {
    const productId = await newProduct('parfum', 'Musc blanc', 8000, 5000, 5);
    const res = await asSec(request(app).post('/api/sales/receipts')).send({
      lines: [{ kind: 'produit', item_id: productId, qty: 2 }],
    });
    expect(res.status).toBe(201);
    expect(res.body.total).toBe(16000);
    expect(res.body.client_id).toBeNull();
  });

  test('one bad line cancels the WHOLE basket — no half sale, no lost stock',
    async () => {
      const ok = await newProduct('parfum', 'Ambre', 10000, 6000, 5);
      const short = await newProduct('chaussure', 'Sandale', 20000, 12000, 1);

      const res = await asSec(request(app).post('/api/sales/receipts')).send({
        lines: [
          { kind: 'produit', item_id: ok, qty: 2 },
          { kind: 'produit', item_id: short, qty: 3 }, // only 1 in stock
        ],
      });
      expect(res.status).toBe(409);
      expect(res.body.error).toMatch(/Stock insuffisant/);

      // The good line must NOT have gone through.
      for (const [id, left] of [[ok, 5], [short, 1]]) {
        const { rows } = await db.query('SELECT quantity FROM products WHERE id = $1', [id]);
        expect(rows[0].quantity).toBe(left);
      }
      const { rows: receipts } = await db.query(
        `SELECT COUNT(*)::int AS n FROM sale_receipts r
          WHERE NOT EXISTS (SELECT 1 FROM sales WHERE receipt_id = r.id)`);
      expect(receipts[0].n).toBe(0); // no orphan header left behind
    });

  test('an empty basket is refused', async () => {
    expect((await asSec(request(app).post('/api/sales/receipts'))
      .send({ lines: [] })).status).toBe(400);
  });

  test('the receipt lands in revenue exactly once, at its full total', async () => {
    const today = new Date().toISOString().slice(0, 10);
    const before = (await asM(
      request(app).get(`/api/finance/summary?from=${today}&to=${today}`))).body;

    const productId = await newProduct('tissu', 'Bazin riche', 25000, 15000, 10);
    await asSec(request(app).post('/api/sales/receipts')).send({
      lines: [{ kind: 'produit', item_id: productId, qty: 4 }],
    });

    const after = (await asM(
      request(app).get(`/api/finance/summary?from=${today}&to=${today}`))).body;
    expect(after.revenue.sales - before.revenue.sales).toBe(100000);      // 4 × 25 000
    expect(after.costs.cost_of_goods_sold - before.costs.cost_of_goods_sold)
      .toBe(60000);                                                        // 4 × 15 000
  });

  test('correcting a line updates the receipt total and puts stock back',
    async () => {
      const productId = await newProduct('bonnet', 'Bonnet laine', 6000, 3000, 10);
      const receipt = (await asM(request(app).post('/api/sales/receipts')).send({
        lines: [{ kind: 'produit', item_id: productId, qty: 5 }],
      })).body;
      expect(receipt.total).toBe(30000);

      // The client returns 2 of them: a correction, never an UPDATE.
      const saleId = receipt.lines[0].id;
      expect((await asM(request(app).post(`/api/sales/${saleId}/corrections`))
        .send({ new_qty: 3, reason: 'Client a rendu 2 bonnets' })).status).toBe(201);

      const after = await asM(request(app).get(`/api/sales/receipts/${receipt.id}`));
      expect(after.body.total).toBe(18000); // 3 × 6 000
      const { rows } = await db.query('SELECT quantity FROM products WHERE id = $1', [productId]);
      expect(rows[0].quantity).toBe(7); // 2 back on the shelf
    });

  test('voiding every line cancels the sale and restores all the stock',
    async () => {
      const productId = await newProduct('montre', 'Montre cuir', 35000, 20000, 6);
      const receipt = (await asM(request(app).post('/api/sales/receipts')).send({
        lines: [{ kind: 'produit', item_id: productId, qty: 2 }],
      })).body;

      await asM(request(app).post(`/api/sales/${receipt.lines[0].id}/corrections`))
        .send({ voided: true, reason: 'Vente annulée, client remboursé' });

      const after = await asM(request(app).get(`/api/sales/receipts/${receipt.id}`));
      expect(after.body.total).toBe(0);
      expect(after.body.voided).toBe(true);
      const { rows } = await db.query('SELECT quantity FROM products WHERE id = $1', [productId]);
      expect(rows[0].quantity).toBe(6); // fully back
    });

  test('the receipt header is append-only, like every financial row', async () => {
    const productId = await newProduct('parfum', 'Santal', 12000, 7000, 5);
    const receipt = (await asM(request(app).post('/api/sales/receipts')).send({
      lines: [{ kind: 'produit', item_id: productId, qty: 1 }],
    })).body;

    await expect(
      db.query('UPDATE sale_receipts SET note = $1 WHERE id = $2', ['x', receipt.id])
    ).rejects.toThrow(/append-only/i);
    await expect(
      db.query('DELETE FROM sale_receipts WHERE id = $1', [receipt.id])
    ).rejects.toThrow(/append-only/i);
  });
});

// ---------------------------------------------------------------------------
describe('financial isolation still holds for receipts', () => {
  // The owner opened the sales history to the secretary on 2026-08-23 so she
  // can fix her own counter mistakes. What was NOT relaxed is the purchase
  // cost: she may see what the shop took, never what it paid, because that is
  // the margin.
  test('the secretary can read back a sale she made, and correct it', async () => {
    const productId = await newProduct('parfum', 'Rose Taif', 20000, 12000, 5);
    const created = await asSec(request(app).post('/api/sales/receipts'))
      .send({ lines: [{ kind: 'produit', item_id: productId, qty: 2 }] });
    expect(created.status).toBe(201);

    const listed = await asSec(request(app).get('/api/sales/receipts'));
    expect(listed.status).toBe(200);
    expect(listed.body.items.map((r) => r.id)).toContain(created.body.id);

    const detail = await asSec(
      request(app).get(`/api/sales/receipts/${created.body.id}`));
    expect(detail.status).toBe(200);
    expect(detail.body.total).toBe(40000);

    // She fixes it: the client only took one.
    const fix = await asSec(
      request(app).post(`/api/sales/${detail.body.lines[0].id}/corrections`))
      .send({ new_qty: 1, reason: 'Le client n’en a pris qu’un' });
    expect(fix.status).toBe(201);

    const after = await asSec(
      request(app).get(`/api/sales/receipts/${created.body.id}`));
    expect(after.body.total).toBe(20000);
    const { rows } = await db.query(
      'SELECT quantity FROM products WHERE id = $1', [productId]);
    expect(rows[0].quantity).toBe(4); // one back on the shelf

    // And the correction names her, so the owner can always audit it.
    const { rows: who } = await db.query(
      `SELECT u.role FROM sale_corrections c JOIN users u ON u.id = c.corrected_by
        WHERE c.sale_id = $1`, [detail.body.lines[0].id]);
    expect(who[0].role).toBe('SECRETARY');
  });

  test('nothing she reads back carries the purchase cost', async () => {
    const productId = await newProduct('montre', 'Montre or', 90000, 55000, 3);
    const created = await asSec(request(app).post('/api/sales/receipts'))
      .send({ lines: [{ kind: 'produit', item_id: productId, qty: 1 }] });

    for (const res of [
      await asSec(request(app).get('/api/sales/receipts')),
      await asSec(request(app).get(`/api/sales/receipts/${created.body.id}`)),
      await asSec(request(app).get('/api/sales')),
    ]) {
      expect(res.status).toBe(200);
      expect(JSON.stringify(res.body)).not.toMatch(/unit_cost|cost_total/);
      expect(JSON.stringify(res.body)).not.toContain('55000');
    }
  });

  test('the profit stats stay manager-only', async () => {
    const productId = await newProduct('bonnet', 'Bonnet or', 9000, 4000, 3);
    expect((await asSec(request(app).get(`/api/products/${productId}/stats`))).status)
      .toBe(403);
  });

  test('the caller cannot choose the sale date', async () => {
    // Backdating a receipt would move takings into another period — the exact
    // class of problem the 2026-08-23 audit was about. The server clock wins.
    const productId = await newProduct('parfum', 'Jasmin', 11000, 6000, 5);
    const res = await asSec(request(app).post('/api/sales/receipts')).send({
      sold_at: '2020-01-01',
      lines: [{ kind: 'produit', item_id: productId, qty: 1 }],
    });
    expect(res.status).toBe(201);

    const { rows } = await db.query(
      'SELECT sold_at::date AS d FROM sale_receipts WHERE id = $1', [res.body.id]);
    expect(rows[0].d.toISOString().slice(0, 10))
      .toBe(new Date().toISOString().slice(0, 10));
  });

  test('a "%" in the search is a literal, not a wildcard', async () => {
    // Regression for the repo's own hardening rule: search terms are never
    // handed to LIKE as patterns (commit 2e38eb7).
    const res = await asM(request(app).get('/api/sales/receipts?search=%25'));
    expect(res.status).toBe(200);
    expect(res.body.items).toHaveLength(0);
  });

  test('the receipt she gets back carries no purchase cost', async () => {
    const productId = await newProduct('chaussure', 'Babouche', 15000, 9000, 5);
    const res = await asSec(request(app).post('/api/sales/receipts'))
      .send({ lines: [{ kind: 'produit', item_id: productId, qty: 1 }] });
    expect(res.status).toBe(201);
    for (const line of res.body.lines) {
      expect(line).not.toHaveProperty('unit_cost');
    }
  });
});
