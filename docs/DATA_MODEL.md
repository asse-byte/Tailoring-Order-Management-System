# Couture Mali — Firestore Data Model

Status: **proposed — awaiting owner review** (2026-07-05).
Roles: `admin` (= le Gérant / MANAGER, keeping the existing constant) and
`secretary`. Every rule below is enforced server-side in `firestore.rules`.

Legend: 🔒 = manager-only collection (secretary requests are rejected by
security rules, regardless of UI).

---

## users/{uid}
| field | type | notes |
|---|---|---|
| name | string | |
| email | string | |
| phone | string | |
| role | `admin` \| `secretary` | no `customer` anymore |
| fcmToken | string? | notifications |
| createdAt | timestamp | |

Rules: user reads own doc; admin reads/writes all. **No self-create** —
accounts are seeded by the admin setup flow only.

## clients/{clientId}
| field | type | notes |
|---|---|---|
| fullName | string | |
| nameLower | string | lowercase copy for prefix search |
| phone | string | |
| phoneDigits | string | digits-only copy for phone search |
| address | string? | |
| createdAt | timestamp | |

Rules: admin + secretary full CRUD.
Index: `nameLower` asc, `phoneDigits` asc (prefix queries with debounce).

### clients/{clientId}/measurements/{measurementId}
| field | type | notes |
|---|---|---|
| garmentType | string | e.g. `boubou`, `chemise`, `pantalon`, custom |
| values | map<string, number> | flexible key-value (épaule, poitrine, manche…) |
| updatedAt | timestamp | |

Rules: admin + secretary full CRUD.

## products/{productId}
| field | type | notes |
|---|---|---|
| category | `parfum` \| `chaussure` \| `tissu` | |
| name | string | |
| price | number | XOF, integer — sale price is visible to secretary |
| quantity | number | stock |
| lowStockThreshold | number | default 3, alert for admin |
| imageUrls | string[] | Storage URLs |
| thumbUrl | string? | compressed thumbnail shown in lists |
| createdAt | timestamp | |

Rules: admin + secretary read; admin + secretary can decrement `quantity`
via sale transaction; only admin creates/edits/deletes products.

## 🔒 sales/{saleId} — write-only for secretary
| field | type | notes |
|---|---|---|
| kind | `produit` \| `pret_a_porter` | |
| itemId | string | product or model id |
| itemName | string | snapshot at sale time |
| qty | number | |
| unitPrice | number | snapshot |
| total | number | qty × unitPrice |
| date | timestamp | |
| createdBy | uid | |

Rules: **secretary may `create` but never `read`/`list`** (Firestore allows
this split) — she can register a sale at the counter, but revenue history
and totals are admin-only. Stock decrement happens in the same batched
write as the sale doc.

## staff/{staffId} — contact info only (safe for secretary)
| field | type | notes |
|---|---|---|
| fullName | string | |
| phone | string | |
| type | `couturier` \| `autre` | |
| joinedAt | timestamp | |
| active | bool | |

Rules: admin full CRUD; secretary read-only (names/contacts for daily work).

## 🔒 staff_pay/{staffId}
| field | type | notes |
|---|---|---|
| pieceRate | number? | couturiers: XOF per piece (falls back to default) |
| monthlySalary | number? | non-couturiers: fixed salary |
| salaryDueDay | number? | day of month |

Rules: admin only, read + write. Same document id as `staff/{staffId}`.

## 🔒 tailor_daily_entries/{entryId}
| field | type | notes |
|---|---|---|
| tailorId | string | FK → staff |
| date | string `YYYY-MM-DD` | one entry per tailor per day (id = `tailorId_date`) |
| piecesCount | number | |
| pieceRate | number | snapshot of rate that day |
| amount | number | piecesCount × pieceRate |
| weekId | string `YYYY-Www` | for weekly totals |
| createdAt | timestamp | |

Rules: admin only. **Never deleted** after week close (audit history);
rules forbid `delete` entirely, allow `update` only same-day.
Index: (`tailorId`, `weekId`), (`weekId`).

## 🔒 expenses/{expenseId}
| field | type | notes |
|---|---|---|
| reason | string | loyer, électricité, matière première… |
| amount | number | |
| date | timestamp | |
| createdBy | uid | |

Rules: admin only.

## pret_a_porter/{modelId}
| field | type | notes |
|---|---|---|
| name | string | |
| fabricType | string | |
| price | number | sale price, visible to secretary |
| imageUrls | string[] | |
| thumbUrl | string? | |
| videoUrl | string? | |
| createdAt | timestamp | |

Rules: admin + secretary read; admin writes.

## orders/{orderId}
| field | type | notes |
|---|---|---|
| clientId | string | FK → clients |
| clientName | string | snapshot for fast lists |
| garmentType | string | |
| fabric | string | |
| measurementsSnapshot | map | copied from client file at order time |
| price | number | what the client pays (secretary needs it to invoice) |
| advance | number | acompte received |
| startDate | timestamp | |
| expectedDate | timestamp | |
| deliveredDate | timestamp? | set when status → `livre` |
| status | `en_cours` \| `pret` \| `livre` | `livre` = appears in Historique |
| notes | string? | |
| createdAt | timestamp | |

Historique = query `status == 'livre'` — a status change *moves* the order,
nothing is copied, no detail is lost.
Rules: admin + secretary full CRUD (secretary registers orders daily).
Indexes: (`status`, `expectedDate`), (`clientId`, `createdAt` desc),
(`status`, `deliveredDate` desc).

## appointments/{appointmentId}
| field | type | notes |
|---|---|---|
| clientId | string | |
| clientName | string | snapshot |
| datetime | timestamp | |
| reason | `mesure` \| `essayage` \| `livraison` \| `autre` | |
| notes | string? | |

Rules: admin + secretary full CRUD. Index: (`datetime`).

## settings/public
`shopName`, `logoUrl` — readable **without auth** (login screen shows them);
writable by admin only.

## settings/private 🔒
`defaultPieceRate` — admin only.

---

## Finance screen (no collection — computed)

All manager-only aggregates are computed client-side from 🔒 collections
(sales + orders revenue − tailor entries − salaries − expenses), filtered
by period. Firestore rules make these queries impossible for the secretary,
so the screen (and its data) simply cannot exist for her.

## Security-rules test plan (non-negotiable)

Automated tests with the Firestore emulator (`@firebase/rules-unit-testing`)
asserting, as the secretary: read/list on `sales`, `expenses`, `staff_pay`,
`tailor_daily_entries`, `settings/private` → **denied**; create on `sales`
→ allowed; everything else per table above.
