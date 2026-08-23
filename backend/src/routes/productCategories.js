const express = require('express');
const db = require('../db');
const { managerOnly } = require('../middleware/auth');
const { asyncH, intOrNull, str } = require('../util');

// The shop's own list of product types (migration 026). Reading is open to both
// roles — the secretary sells at the counter and needs the tabs — while adding,
// renaming and removing a type is the owner's, like every other Type-A master
// data write that is not one of the four opened to her in rule 2.
//
// Categories carry no money at all (no price, no cost, no margin), so nothing
// here touches rule 1.
const router = express.Router();

/** 'Grandes Montres' → 'grandes_montres'. Keeps the slug CHECK satisfied. */
function slugify(label) {
  return label
    .normalize('NFD').replace(/[\u0300-\u036f]/g, '') // drop accents
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 40);
}

router.get('/', asyncH(async (req, res) => {
  const { rows } = await db.query(
    `SELECT c.*, COALESCE(p.n, 0)::int AS products_count
       FROM product_categories c
       LEFT JOIN LATERAL (
         SELECT COUNT(*)::int AS n FROM products WHERE category = c.slug
       ) p ON true
      ORDER BY c.sort_order, c.label`);
  res.json({ items: rows });
}));

router.post('/', managerOnly, asyncH(async (req, res) => {
  const label = str(req.body.label);
  if (!label) return res.status(400).json({ error: 'Le nom du type est obligatoire.' });

  const slug = str(req.body.slug) || slugify(label);
  if (!/^[a-z0-9_]+$/.test(slug)) {
    return res.status(400).json({ error: 'Nom invalide : utilisez des lettres.' });
  }

  const { rows } = await db.query(
    `INSERT INTO product_categories (slug, label, icon, sort_order)
     VALUES ($1, $2, $3, COALESCE($4, 100))
     ON CONFLICT (slug) DO NOTHING
     RETURNING *`,
    [slug, label, str(req.body.icon) || null, intOrNull(req.body.sort_order)]);

  if (!rows[0]) return res.status(409).json({ error: 'Ce type de produit existe déjà.' });
  res.status(201).json(rows[0]);
}));

// The label, icon and order are free to change; the slug is NOT, because it is
// the value stored on every product row and on nothing else that would follow
// it. Renaming "Bonnets" to "Chapeaux" is a label change, never a slug change.
router.put('/:id', managerOnly, asyncH(async (req, res) => {
  const label = req.body.label === undefined ? null : str(req.body.label);
  if (label !== null && !label) {
    return res.status(400).json({ error: 'Le nom du type est obligatoire.' });
  }
  const { rows } = await db.query(
    `UPDATE product_categories
        SET label      = COALESCE($1, label),
            icon       = COALESCE($2, icon),
            sort_order = COALESCE($3, sort_order)
      WHERE id = $4 RETURNING *`,
    [label, str(req.body.icon) || null, intOrNull(req.body.sort_order), req.params.id]);
  if (!rows[0]) return res.status(404).json({ error: 'Type de produit introuvable.' });
  res.json(rows[0]);
}));

// Type-A delete, manager only. A category still holding products is refused
// rather than cascading: products would lose their type, and the FK is
// ON DELETE RESTRICT anyway. The message says how many are in the way so the
// manager knows what to move first.
router.delete('/:id', managerOnly, asyncH(async (req, res) => {
  const { rows: cur } = await db.query(
    'SELECT slug FROM product_categories WHERE id = $1', [req.params.id]);
  if (!cur[0]) return res.status(404).json({ error: 'Type de produit introuvable.' });

  const { rows: used } = await db.query(
    'SELECT COUNT(*)::int AS n FROM products WHERE category = $1', [cur[0].slug]);
  if (used[0].n > 0) {
    return res.status(409).json({
      error: `Impossible : ${used[0].n} produit(s) utilisent encore ce type. `
        + 'Changez leur type ou supprimez-les d’abord.',
    });
  }

  await db.query('DELETE FROM product_categories WHERE id = $1', [req.params.id]);
  res.status(204).end();
}));

module.exports = router;
