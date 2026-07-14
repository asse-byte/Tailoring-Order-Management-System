// =============================================================================
// Finance — fixed monthly salaries are PRORATED to the selected period.
// =============================================================================
// Regression for the reporting bug where a full month of fixed salaries was
// charged against a single day/week: the "Jour" / "Semaine" presets made net
// profit look massively negative. A calendar month now contributes its exact
// day-fraction, so a full month = 1×, a single day = 1/daysInMonth, a full
// year = 12×. Uses a baseline→after DELTA so it is robust to any other salaried
// staff already in the shared test database.
// =============================================================================

const request = require('supertest');
const { createApp } = require('../src/app');
const db = require('../src/db');
const { MANAGER, seedUsers, login } = require('./helpers');

let app;
let managerToken;
const asManager = (r) => r.set('Authorization', `Bearer ${managerToken}`);

const SALARY = 300000; // September has 30 days → 1 day = 10 000 exactly.

beforeAll(async () => {
  app = createApp();
  await seedUsers();
  managerToken = await login(app, MANAGER);
});

afterAll(async () => {
  await db.closePool();
});

async function salariesFor(from, to) {
  const res = await asManager(
    request(app).get(`/api/finance/summary?from=${from}&to=${to}`));
  expect(res.status).toBe(200);
  return res.body.costs.salaries;
}

test('a fixed monthly salary is prorated by day-fraction across presets', async () => {
  // Baselines BEFORE adding the salaried employee (other fixtures may exist).
  const dayBefore = await salariesFor('2026-09-15', '2026-09-15');
  const monthBefore = await salariesFor('2026-09-01', '2026-09-30');
  const yearBefore = await salariesFor('2026-01-01', '2026-12-31');

  const staffId = (await asManager(request(app).post('/api/staff'))
    .send({ full_name: 'Gardien Salarié', phone: '76000123', type: 'autre' })).body.id;
  await asManager(request(app).put(`/api/staff-pay/${staffId}`))
    .send({ monthly_salary: SALARY, salary_due_day: 1 });

  // Single day in a 30-day month → exactly 1/30 of the salary.
  expect(await salariesFor('2026-09-15', '2026-09-15') - dayBefore)
    .toBe(Math.round(SALARY / 30));
  // A full calendar month → exactly one salary (no more full-month-on-one-day).
  expect(await salariesFor('2026-09-01', '2026-09-30') - monthBefore)
    .toBe(SALARY);
  // A full year → twelve salaries.
  expect(await salariesFor('2026-01-01', '2026-12-31') - yearBefore)
    .toBe(SALARY * 12);
});

test('a week spanning two months is prorated across both', async () => {
  const before = await salariesFor('2026-01-29', '2026-02-04');
  const staffId = (await asManager(request(app).post('/api/staff'))
    .send({ full_name: 'Salarié Chevauchant', phone: '76000124', type: 'autre' })).body.id;
  await asManager(request(app).put(`/api/staff-pay/${staffId}`))
    .send({ monthly_salary: SALARY, salary_due_day: 1 });

  // Jan 29–31 = 3 days / 31 ; Feb 1–4 = 4 days / 28.
  const expected = Math.round(SALARY * (3 / 31 + 4 / 28));
  // The summary rounds the GRAND TOTAL of salaries × factor, so with other
  // salaried staff in the baseline the isolated delta can differ by ±1 franc.
  const delta = await salariesFor('2026-01-29', '2026-02-04') - before;
  expect(Math.abs(delta - expected)).toBeLessThanOrEqual(1);
});
