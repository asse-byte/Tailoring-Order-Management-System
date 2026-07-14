// =============================================================================
// Item 9 — per-shop theme colour: public (login screen), manager-editable.
// =============================================================================

const request = require('supertest');
const { createApp } = require('../src/app');
const db = require('../src/db');
const { MANAGER, seedUsers, login } = require('./helpers');

let app;
let mToken;
const asM = (r) => r.set('Authorization', `Bearer ${mToken}`);

beforeAll(async () => {
  app = createApp();
  await seedUsers();
  mToken = await login(app, MANAGER);
});

afterAll(async () => { await db.closePool(); });

test('theme_color is exposed in public settings (pre-auth)', async () => {
  const res = await request(app).get('/api/settings/public');
  expect(res.status).toBe(200);
  expect(res.body).toHaveProperty('theme_color');
  expect(res.body.theme_color).toMatch(/^#[0-9A-F]{6}$/);
});

test('manager can update it; a bad hex is rejected', async () => {
  const bad = await asM(request(app).put('/api/settings/private'))
    .send({ theme_color: 'blue' });
  expect(bad.status).toBe(400);

  const ok = await asM(request(app).put('/api/settings/private'))
    .send({ theme_color: '#8e44ad' });
  expect(ok.status).toBe(200);
  expect(ok.body.theme_color).toBe('#8E44AD'); // normalised upper-case

  const pub = await request(app).get('/api/settings/public');
  expect(pub.body.theme_color).toBe('#8E44AD');
});
