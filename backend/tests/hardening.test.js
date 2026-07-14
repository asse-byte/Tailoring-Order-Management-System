// =============================================================================
// Security hardening — baseline headers + upload content sniffing.
// =============================================================================
// Complements security.test.js (RBAC / financial isolation) with the
// defence-in-depth added later: security response headers, and rejecting a
// file whose bytes do not match its extension (the video path stores files
// as-is, so the magic-byte gate is what stops a renamed script).
// =============================================================================

const request = require('supertest');
const { createApp } = require('../src/app');
const db = require('../src/db');
const { SECRETARY, seedUsers, login } = require('./helpers');

let app;
let secToken;
const asSec = (r) => r.set('Authorization', `Bearer ${secToken}`);

beforeAll(async () => {
  app = createApp();
  await seedUsers();
  secToken = await login(app, SECRETARY);
});

afterAll(async () => {
  await db.closePool();
});

describe('Security headers', () => {
  it('sets nosniff / frame-deny / CSP on API responses', async () => {
    const res = await request(app).get('/api/settings/public');
    expect(res.headers['x-content-type-options']).toBe('nosniff');
    expect(res.headers['x-frame-options']).toBe('DENY');
    expect(res.headers['content-security-policy']).toMatch(/default-src 'none'/);
    expect(res.headers['x-powered-by']).toBeUndefined();
  });
});

describe('Upload content sniffing', () => {
  it('accepts a real PNG (magic bytes match the extension)', async () => {
    const { Jimp } = require('jimp');
    const png = await new Jimp({ width: 40, height: 40, color: 0x112233ff })
      .getBuffer('image/png');
    const res = await asSec(request(app).post('/api/upload'))
      .attach('file', png, 'ok.png');
    expect(res.status).toBe(201);

    // Clean up the stored files.
    const fs = require('fs');
    const path = require('path');
    const dir = path.join(__dirname, '../uploads');
    for (const u of [res.body.url, res.body.thumb_url]) {
      if (u) { try { fs.unlinkSync(path.join(dir, path.basename(u))); } catch (_) { /* ignore */ } }
    }
  });

  it('rejects a non-video disguised as .mp4 (bytes do not match)', async () => {
    const res = await asSec(request(app).post('/api/upload'))
      .attach('file', Buffer.from('this is definitely not a video'), 'fake.mp4');
    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/ne correspond pas/);
  });

  it('rejects a text file disguised as .png (bytes do not match)', async () => {
    const res = await asSec(request(app).post('/api/upload'))
      .attach('file', Buffer.from('<script>alert(1)</script>'), 'evil.png');
    expect(res.status).toBe(400);
  });

  it('accepts a minimal ftyp-signed mp4 container', async () => {
    // 0x00000018 'ftyp' 'isom' ... — a valid MP4 magic header.
    const header = Buffer.from([
      0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, // ....ftyp
      0x69, 0x73, 0x6f, 0x6d, 0x00, 0x00, 0x02, 0x00, // isom....
    ]);
    const res = await asSec(request(app).post('/api/upload'))
      .attach('file', header, 'clip.mp4');
    expect(res.status).toBe(201);
    expect(res.body.url).toMatch(/^\/uploads\/.+\.mp4$/);

    const fs = require('fs');
    const path = require('path');
    const dir = path.join(__dirname, '../uploads');
    try { fs.unlinkSync(path.join(dir, path.basename(res.body.url))); } catch (_) { /* ignore */ }
  });
});
