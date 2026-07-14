// =============================================================================
// Item 3 — salary payment ledger (append-only + correction log, manager-only).
// =============================================================================

const request = require('supertest');
const { createApp } = require('../src/app');
const db = require('../src/db');
const { MANAGER, SECRETARY, seedUsers, login } = require('./helpers');

let app;
let mToken;
let sToken;
let staffId;
let payId;
const asM = (r) => r.set('Authorization', `Bearer ${mToken}`);
const asS = (r) => r.set('Authorization', `Bearer ${sToken}`);

beforeAll(async () => {
  app = createApp();
  await seedUsers();
  mToken = await login(app, MANAGER);
  sToken = await login(app, SECRETARY);
  staffId = (await asM(request(app).post('/api/staff'))
    .send({ full_name: 'Ibrahim Gardien', phone: '76000200', type: 'autre' })).body.id;
  await asM(request(app).put(`/api/staff-pay/${staffId}`))
    .send({ monthly_salary: 150000, salary_due_day: 1 });
});

afterAll(async () => { await db.closePool(); });

describe('Salary payments — manager-only ledger', () => {
  it('secretary is blocked (403) from reading and writing', async () => {
    expect((await asS(request(app).get('/api/salary-payments'))).status).toBe(403);
    expect((await asS(request(app).post('/api/salary-payments'))
      .send({ staff_id: staffId, period: '2026-07', kind: 'mensuel', amount: 1 }))
      .status).toBe(403);
  });

  it('records a monthly payment and lists it by staff + year', async () => {
    const res = await asM(request(app).post('/api/salary-payments')).send({
      staff_id: staffId, period: '2026-07', kind: 'mensuel',
      amount: 150000, paid_at: '2026-07-31',
    });
    expect(res.status).toBe(201);
    payId = res.body.id;

    const list = await asM(request(app)
      .get(`/api/salary-payments?staff_id=${staffId}&year=2026`));
    expect(list.status).toBe(200);
    const p = list.body.items.find((x) => x.period === '2026-07');
    expect(p.amount).toBe(150000);
    expect(p.voided).toBe(false);
    expect(p.staff_name).toBe('Ibrahim Gardien');
  });

  it('rejects a bad period format and a duplicate period (409)', async () => {
    expect((await asM(request(app).post('/api/salary-payments'))
      .send({ staff_id: staffId, period: '2026/07', kind: 'mensuel', amount: 1 }))
      .status).toBe(400);
    // duplicate (staff_id, period) → unique violation → 409
    expect((await asM(request(app).post('/api/salary-payments'))
      .send({ staff_id: staffId, period: '2026-07', kind: 'mensuel', amount: 150000 }))
      .status).toBe(409);
  });

  it('correction requires a reason; void excludes it, keeps the original', async () => {
    expect((await asM(request(app).post(`/api/salary-payments/${payId}/corrections`))
      .send({ voided: true })).status).toBe(400);

    const ok = await asM(request(app).post(`/api/salary-payments/${payId}/corrections`))
      .send({ voided: true, reason: 'Paiement annulé: doublon' });
    expect(ok.status).toBe(201);

    const list = await asM(request(app).get(`/api/salary-payments?staff_id=${staffId}`));
    const p = list.body.items.find((x) => x.id === payId);
    expect(p.voided).toBe(true);
    expect(p.corrected).toBe(true);

    const { rows } = await db.query(
      'SELECT amount FROM salary_payments WHERE id = $1', [payId]);
    expect(rows[0].amount).toBe(150000); // original untouched

    const history = await asM(request(app)
      .get(`/api/salary-payments/${payId}/corrections`));
    expect(history.body.items).toHaveLength(1);
    expect(history.body.items[0].corrected_by_name).toBeTruthy();
  });

  it('append-only: direct UPDATE/DELETE raise', async () => {
    await expect(db.query('UPDATE salary_payments SET amount = 1 WHERE id = $1', [payId]))
      .rejects.toThrow(/append-only/);
    await expect(db.query('DELETE FROM salary_payments WHERE id = $1', [payId]))
      .rejects.toThrow(/append-only/);
  });

  it('there is NO update/delete route', async () => {
    expect((await asM(request(app).put(`/api/salary-payments/${payId}`))
      .send({ amount: 1 })).status).toBe(404);
    expect((await asM(request(app).delete(`/api/salary-payments/${payId}`)))
      .status).toBe(404);
  });
});
