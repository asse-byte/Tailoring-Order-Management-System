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
let secretaryToken;
let tailorId;
let weekId;
const asM = (r) => r.set('Authorization', `Bearer ${token}`);
const asS = (r) => r.set('Authorization', `Bearer ${secretaryToken}`);

async function detail() {
  const res = await asM(request(app)
    .get(`/api/tailor-entries/weekly-detail?week_id=${weekId}&tailor_id=${tailorId}`));
  return res.body;
}

beforeAll(async () => {
  app = createApp();
  await seedUsers();
  token = await login(app, MANAGER);
  secretaryToken = await login(app, SECRETARY);
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
  expect(row.corrected_by_name).toBeDefined();
  expect(row.correction_reason).toBe('Erreur de saisie');
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

test('voiding an entry cancels it (counts 0 pieces and 0 amount) but keeps it in log', async () => {
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
  expect(row.pieces_count).toBe(0); // voided entry contributes 0 pieces
  expect(row.amount).toBe(0);      // contributes nothing
  expect(row.correction_reason).toBe('Saisie en double');
  expect(d.total).toBe(before - 15000); // 5 × 3000 removed
});

test('secretary can correct tailor entries and records corrected_by', async () => {
  const e = await asS(request(app).post('/api/tailor-entries')).send({
    tailor_id: tailorId, entry_date: '2027-03-05', pieces_count: 4,
    piece_rate: 2500, garment_type: 'Veste',
  });
  const entryId = e.body.id;
  const res = await asS(request(app).post(`/api/tailor-entries/${entryId}/corrections`))
    .send({ new_pieces: 2, reason: 'Correction par la secrétaire' });
  expect(res.status).toBe(201);

  const d = await detail();
  const row = d.items.find((i) => i.id === entryId);
  expect(row.pieces_count).toBe(2);
  expect(row.amount).toBe(5000);
  expect(row.corrected_by_name).toBe('secretaire');
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
