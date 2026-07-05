// =============================================================================
// Couture Mali — security-rules tests
// =============================================================================
// The single non-negotiable requirement: the SECRETARY must never be able to
// read any financial data (sales, expenses, pay rates, daily wage entries,
// financial settings), no matter what she tries — these tests hit the rules
// directly, bypassing the app UI entirely.
//
// Run:  npm test   (spins up the Firestore emulator via emulators:exec)
// =============================================================================

const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');

const ADMIN_UID = 'admin-uid';
const SEC_UID = 'secretary-uid';
const PROJECT_ID = 'demo-couture-mali';

let testEnv;

/** Firestore handle authenticated as the admin (le Gérant). */
const adminDb = () => testEnv.authenticatedContext(ADMIN_UID).firestore();
/** Firestore handle authenticated as the secretary. */
const secDb = () => testEnv.authenticatedContext(SEC_UID).firestore();
/** Unauthenticated handle. */
const anonDb = () => testEnv.unauthenticatedContext().firestore();

/** Seed baseline data with rules disabled. */
async function seed() {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc(`users/${ADMIN_UID}`).set({
      name: 'Gérant', email: 'admin@tailor.app', phone: '', role: 'admin',
    });
    await db.doc(`users/${SEC_UID}`).set({
      name: 'Secrétaire', email: 'secretary@tailor.app', phone: '', role: 'secretary',
    });
    await db.doc('settings/bootstrap').set({ done: true });
    await db.doc('settings/public').set({ shopName: 'Couture Mali', logoUrl: null });
    await db.doc('settings/private').set({ defaultPieceRate: 1500 });

    await db.doc('clients/client1').set({
      fullName: 'Amadou Traoré', nameLower: 'amadou traoré',
      phone: '70000000', phoneDigits: '70000000',
    });
    await db.doc('products/prod1').set({
      category: 'tissu', name: 'Bazin riche', price: 15000, quantity: 10,
    });
    await db.doc('pret_a_porter/model1').set({
      name: 'Boubou brodé', fabricType: 'bazin', price: 45000,
    });
    await db.doc('staff/tailor1').set({
      fullName: 'Moussa Keïta', phone: '76000000', type: 'couturier', active: true,
    });
    await db.doc('staff_pay/tailor1').set({ pieceRate: 2000 });
    await db.doc('tailor_daily_entries/tailor1_2026-07-01').set({
      tailorId: 'tailor1', date: '2026-07-01', piecesCount: 4,
      pieceRate: 2000, amount: 8000, weekId: '2026-W27',
      createdAt: new Date('2026-07-01T18:00:00Z'),
    });
    await db.doc('expenses/exp1').set({
      reason: 'Loyer', amount: 100000, date: new Date(), createdBy: ADMIN_UID,
    });
    await db.doc('sales/sale1').set({
      kind: 'produit', itemId: 'prod1', itemName: 'Bazin riche',
      qty: 1, unitPrice: 15000, total: 15000, date: new Date(), createdBy: ADMIN_UID,
    });
    await db.doc('orders/order1').set({
      clientId: 'client1', clientName: 'Amadou Traoré', garmentType: 'boubou',
      fabric: 'bazin', price: 30000, advance: 10000, status: 'en_cours',
    });
    await db.doc('appointments/rdv1').set({
      clientId: 'client1', clientName: 'Amadou Traoré',
      datetime: new Date(), reason: 'mesure',
    });
  });
}

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync(path.resolve(__dirname, '../../firestore.rules'), 'utf8'),
    },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await seed();
});

after(async () => {
  if (testEnv) await testEnv.cleanup();
});

// =============================================================================
// 1. FINANCIAL ISOLATION — the secretary must be denied, always.
// =============================================================================

describe('SECRETARY — financial data is completely blocked', () => {
  it('cannot read a sale document', () =>
    assertFails(secDb().doc('sales/sale1').get()));

  it('cannot list the sales collection', () =>
    assertFails(secDb().collection('sales').get()));

  it('cannot update or delete a sale', async () => {
    await assertFails(secDb().doc('sales/sale1').update({ total: 1 }));
    await assertFails(secDb().doc('sales/sale1').delete());
  });

  it('cannot read or list expenses', async () => {
    await assertFails(secDb().doc('expenses/exp1').get());
    await assertFails(secDb().collection('expenses').get());
  });

  it('cannot create an expense', () =>
    assertFails(secDb().collection('expenses').add({
      reason: 'x', amount: 1, date: new Date(), createdBy: SEC_UID,
    })));

  it('cannot read staff pay data (piece rates / salaries)', async () => {
    await assertFails(secDb().doc('staff_pay/tailor1').get());
    await assertFails(secDb().collection('staff_pay').get());
  });

  it('cannot read or list tailor daily wage entries', async () => {
    await assertFails(secDb().doc('tailor_daily_entries/tailor1_2026-07-01').get());
    await assertFails(secDb().collection('tailor_daily_entries').get());
  });

  it('cannot create a tailor daily entry', () =>
    assertFails(secDb().doc('tailor_daily_entries/tailor1_2026-07-02').set({
      tailorId: 'tailor1', date: '2026-07-02', piecesCount: 3,
      pieceRate: 2000, amount: 6000, weekId: '2026-W27', createdAt: new Date(),
    })));

  it('cannot read financial settings (default piece rate)', () =>
    assertFails(secDb().doc('settings/private').get()));

  it('cannot promote herself to admin', () =>
    assertFails(secDb().doc(`users/${SEC_UID}`).update({ role: 'admin' })));

  it('cannot read the admin user document', () =>
    assertFails(secDb().doc(`users/${ADMIN_UID}`).get()));
});

// =============================================================================
// 2. SECRETARY — daily operations she IS allowed to do.
// =============================================================================

describe('SECRETARY — allowed daily operations', () => {
  it('can read and create clients', async () => {
    await assertSucceeds(secDb().doc('clients/client1').get());
    await assertSucceeds(secDb().collection('clients').add({
      fullName: 'Fatoumata Diallo', nameLower: 'fatoumata diallo',
      phone: '65000000', phoneDigits: '65000000',
    }));
  });

  it('can manage client measurements', () =>
    assertSucceeds(secDb().doc('clients/client1/measurements/m1').set({
      garmentType: 'boubou', values: { epaule: 45, poitrine: 102 },
    })));

  it('can read products and prêt-à-porter (to sell at the counter)', async () => {
    await assertSucceeds(secDb().doc('products/prod1').get());
    await assertSucceeds(secDb().doc('pret_a_porter/model1').get());
  });

  it('can register a sale (create-only) with valid data', () =>
    assertSucceeds(secDb().collection('sales').add({
      kind: 'produit', itemId: 'prod1', itemName: 'Bazin riche',
      qty: 2, unitPrice: 15000, total: 30000, date: new Date(),
      createdBy: SEC_UID,
    })));

  it('cannot register a sale with a forged total', () =>
    assertFails(secDb().collection('sales').add({
      kind: 'produit', itemId: 'prod1', itemName: 'Bazin riche',
      qty: 2, unitPrice: 15000, total: 1, date: new Date(),
      createdBy: SEC_UID,
    })));

  it('can decrement product stock (sale), nothing else', async () => {
    await assertSucceeds(secDb().doc('products/prod1').update({ quantity: 9 }));
    // Increment: denied.
    await assertFails(secDb().doc('products/prod1').update({ quantity: 20 }));
    // Price change: denied.
    await assertFails(secDb().doc('products/prod1').update({ price: 1 }));
    // Create/delete products: denied.
    await assertFails(secDb().collection('products').add({
      category: 'parfum', name: 'x', price: 1, quantity: 1,
    }));
    await assertFails(secDb().doc('products/prod1').delete());
  });

  it('can read staff contact info but cannot modify staff', async () => {
    await assertSucceeds(secDb().doc('staff/tailor1').get());
    await assertSucceeds(secDb().collection('staff').get());
    await assertFails(secDb().doc('staff/tailor1').update({ fullName: 'X' }));
    await assertFails(secDb().collection('staff').add({ fullName: 'Y', type: 'autre' }));
  });

  it('can create and update orders with a valid status', async () => {
    await assertSucceeds(secDb().collection('orders').add({
      clientId: 'client1', clientName: 'Amadou Traoré', garmentType: 'chemise',
      fabric: 'wax', price: 20000, advance: 5000, status: 'en_cours',
    }));
    await assertSucceeds(secDb().doc('orders/order1').update({ status: 'livre' }));
    await assertFails(secDb().doc('orders/order1').update({ status: 'invalide' }));
    // Deleting orders is manager-only.
    await assertFails(secDb().doc('orders/order1').delete());
  });

  it('can manage appointments', async () => {
    await assertSucceeds(secDb().collection('appointments').add({
      clientId: 'client1', clientName: 'Amadou Traoré',
      datetime: new Date(), reason: 'essayage',
    }));
    await assertSucceeds(secDb().doc('appointments/rdv1').delete());
  });
});

// =============================================================================
// 3. ADMIN (le Gérant) — full access, plus audit-trail immutability.
// =============================================================================

describe('ADMIN — full access', () => {
  it('can read all financial collections', async () => {
    await assertSucceeds(adminDb().collection('sales').get());
    await assertSucceeds(adminDb().collection('expenses').get());
    await assertSucceeds(adminDb().doc('staff_pay/tailor1').get());
    await assertSucceeds(adminDb().collection('tailor_daily_entries').get());
    await assertSucceeds(adminDb().doc('settings/private').get());
  });

  it('can manage staff, pay and expenses', async () => {
    await assertSucceeds(adminDb().collection('staff').add({
      fullName: 'Nouveau', phone: '', type: 'autre', active: true,
    }));
    await assertSucceeds(adminDb().doc('staff_pay/tailor1').update({ pieceRate: 2500 }));
    await assertSucceeds(adminDb().collection('expenses').add({
      reason: 'Électricité', amount: 25000, date: new Date(), createdBy: ADMIN_UID,
    }));
  });

  it('can create a coherent daily entry (amount = pieces × rate)', async () => {
    await assertSucceeds(adminDb().doc('tailor_daily_entries/tailor1_2026-07-03').set({
      tailorId: 'tailor1', date: '2026-07-03', piecesCount: 5,
      pieceRate: 2000, amount: 10000, weekId: '2026-W27', createdAt: new Date(),
    }));
    // Incoherent amount is rejected even for the admin.
    await assertFails(adminDb().doc('tailor_daily_entries/tailor1_2026-07-04').set({
      tailorId: 'tailor1', date: '2026-07-04', piecesCount: 5,
      pieceRate: 2000, amount: 999, weekId: '2026-W27', createdAt: new Date(),
    }));
  });

  it('can NEVER delete a daily wage entry (immutable audit history)', () =>
    assertFails(adminDb().doc('tailor_daily_entries/tailor1_2026-07-01').delete()));

  it('cannot edit a daily entry after the 24h correction window', () =>
    // Seeded entry was created 2026-07-01; the window is long gone.
    assertFails(adminDb().doc('tailor_daily_entries/tailor1_2026-07-01').update({
      piecesCount: 9, pieceRate: 2000, amount: 18000,
    })));
});

// =============================================================================
// 4. UNAUTHENTICATED + BOOTSTRAP
// =============================================================================

describe('Unauthenticated access', () => {
  it('can read only the public shop settings (login screen)', async () => {
    await assertSucceeds(anonDb().doc('settings/public').get());
    await assertFails(anonDb().doc('settings/private').get());
    await assertFails(anonDb().collection('clients').get());
    await assertFails(anonDb().collection('orders').get());
  });
});

describe('Bootstrap — first admin creation', () => {
  it('a signed-in user cannot self-create an admin once bootstrap exists', () =>
    assertFails(
      testEnv.authenticatedContext('intruder').firestore()
        .doc('users/intruder').set({ name: 'X', role: 'admin' }),
    ));

  it('a signed-in user cannot self-create a secretary account either', () =>
    assertFails(
      testEnv.authenticatedContext('intruder').firestore()
        .doc('users/intruder').set({ name: 'X', role: 'secretary' }),
    ));

  it('first admin + bootstrap marker can be created together when empty', async () => {
    await testEnv.clearFirestore();
    const db = testEnv.authenticatedContext('first-admin').firestore();
    const batch = db.batch();
    batch.set(db.doc('users/first-admin'), {
      name: 'Gérant', email: 'admin@tailor.app', phone: '', role: 'admin',
    });
    batch.set(db.doc('settings/bootstrap'), { done: true });
    await assertSucceeds(batch.commit());
  });
});
