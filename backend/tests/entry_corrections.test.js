// =============================================================================
// A tailor daily entry is fully correctable via the append-only correction log:
// quantity, garment type (model) AND price-per-piece (the montant), plus a void
// that cancels the entry (counts 0). The base row is never edited or deleted.
// =============================================================================

const request = require('supertest');
const { createApp } = require('../src/app');
const db = require('../src/db');
const { MANAGER, SECRETARY, seedUsers, login } = require('./helpers');

let app;
let token;
let tailorId;
let weekId;
const asM = (r) => r.set('Authorization', `Bearer ${token}`);

async function detail() {
  const res = await asM(request(app)
    .get(`/api/tailor-entries/weekly-detail?week_id=${weekId}&tailor_id=${tailorId}`));
  return res.body;
}

beforeAll(async () => {
  app = createApp();
  await seedUsers();
  token = await login(app, MANAGER);
  tailorId = (await asM(request(app).post('/api/staff'))
    .send({ full_name: 'Aboubacar', phone: '76009000', type: 'couturier' })).body.id;
});

afterAll(async () => { await db.closePool(); });

test('correcting quantity, model and price recomputes the montant', async () => {
  const e = await asM(request(app).post('/api/tailor-entries')).send({
    tailor_id: tailorId, entry_date: '2027-03-01', pieces_count: 2,
    piece_rate: 4000, garment_type: 'Complet normal',
  });
  weekId = e.body.week_id;
  const entryId = e.body.id;
  expect((await detail()).total).toBe(8000); // 2 × 4000

  // Change all three fields at once.
  const c = await asM(request(app).post(`/api/tailor-entries/${entryId}/corrections`))
    .send({
      new_pieces: 3, new_piece_rate: 5000,
      new_garment_type: 'Grand Boubou', reason: 'Erreur de saisie',
    });
  expect(c.status).toBe(201);

  const d = await detail();
  const row = d.items.find((i) => i.id === entryId);
  expect(row.pieces_count).toBe(3);
  expect(row.piece_rate).toBe(5000);
  expect(row.garment_type).toBe('Grand Boubou');
  expect(row.amount).toBe(15000); // 3 × 5000, recomputed
  expect(row.corrected).toBe(true);
  expect(d.total).toBe(15000);
});

test('correcting only the price keeps quantity and model', async () => {
  const e = await asM(request(app).post('/api/tailor-entries')).send({
    tailor_id: tailorId, entry_date: '2027-03-02', pieces_count: 2,
    piece_rate: 4000, garment_type: 'Chemise',
  });
  const entryId = e.body.id;
  await asM(request(app).post(`/api/tailor-entries/${entryId}/corrections`))
    .send({ new_piece_rate: 6000, reason: 'Prix ajusté' });
  const row = (await detail()).items.find((i) => i.id === entryId);
  expect(row.pieces_count).toBe(2);        // unchanged
  expect(row.garment_type).toBe('Chemise'); // unchanged
  expect(row.amount).toBe(12000);           // 2 × 6000
});

test('voiding an entry cancels it (counts 0) but keeps it in the log', async () => {
  const e = await asM(request(app).post('/api/tailor-entries')).send({
    tailor_id: tailorId, entry_date: '2027-03-03', pieces_count: 5,
    piece_rate: 3000, garment_type: 'Pantalon',
  });
  const entryId = e.body.id;
  const before = (await detail()).total;

  const v = await asM(request(app).post(`/api/tailor-entries/${entryId}/corrections`))
    .send({ voided: true, reason: 'Saisie en double' });
  expect(v.status).toBe(201);

  const d = await detail();
  const row = d.items.find((i) => i.id === entryId);
  expect(row).toBeDefined();       // still present in the audit trail
  expect(row.voided).toBe(true);
  expect(row.amount).toBe(0);      // contributes nothing
  expect(d.total).toBe(before - 15000); // 5 × 3000 removed
});

test('a correction still requires a mandatory reason', async () => {
  const e = await asM(request(app).post('/api/tailor-entries')).send({
    tailor_id: tailorId, entry_date: '2027-03-04', pieces_count: 1,
    piece_rate: 2000, garment_type: 'Chemise',
  });
  const res = await asM(request(app).post(`/api/tailor-entries/${e.body.id}/corrections`))
    .send({ new_pieces: 4 }); // no reason
  expect(res.status).toBe(400);
});

// ---------------------------------------------------------------------------
// The audit trail is the shop owner's evidence when a tailor disputes their
// pay, so it must name the person who made each change and show what the value
// was before it. Both roles may correct entries (owner decision), which is
// exactly why attribution has to be recorded and readable.
// ---------------------------------------------------------------------------
test('the correction history names who changed what, from → to, and why', async () => {
  const secToken = await login(app, SECRETARY);
  const asSec = (r) => r.set('Authorization', `Bearer ${secToken}`);

  const e = await asM(request(app).post('/api/tailor-entries')).send({
    tailor_id: tailorId, entry_date: '2027-03-05', pieces_count: 4,
    piece_rate: 2500, garment_type: 'Chemise',
  });
  const entryId = e.body.id;

  // The secretary corrects the quantity…
  await asSec(request(app).post(`/api/tailor-entries/${entryId}/corrections`))
    .send({ new_pieces: 6, reason: 'Comptage refait le soir' });
  // …then the manager corrects the rate.
  await asM(request(app).post(`/api/tailor-entries/${entryId}/corrections`))
    .send({ new_piece_rate: 3000, reason: 'Tarif renégocié' });

  const hist = await asM(request(app).get(`/api/tailor-entries/${entryId}/corrections`));
  expect(hist.status).toBe(200);
  expect(hist.body.items.length).toBe(2);

  // Newest first.
  const [rate, qty] = hist.body.items;

  expect(rate.corrected_by_name).toBe(MANAGER.username);
  expect(rate.reason).toBe('Tarif renégocié');
  expect(rate.old_piece_rate).toBe(2500);
  expect(rate.new_piece_rate).toBe(3000);
  expect(rate.old_pieces).toBe(6);      // carried over from the first correction
  expect(rate.new_amount).toBe(18000);  // 6 × 3000

  expect(qty.corrected_by_name).toBe(SECRETARY.username);
  expect(qty.reason).toBe('Comptage refait le soir');
  expect(qty.old_pieces).toBe(4);       // the original entry's value
  expect(qty.new_pieces).toBe(6);
  expect(qty.old_amount).toBe(10000);   // 4 × 2500
  expect(qty.new_amount).toBe(15000);   // 6 × 2500

  // Every row is attributed to a real user, never an anonymous role.
  for (const item of hist.body.items) {
    expect(item.corrected_by).toBeTruthy();
    expect(item.corrected_at).toBeTruthy();
  }
});
