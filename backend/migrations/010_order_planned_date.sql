-- ============================================================================
-- Item 4 — production scheduling (programme journalier / hebdomadaire).
-- A nullable planned EXECUTION date on the order: the shop assigns which day
-- each order will be worked on. Orders with no planned_date form the waiting
-- queue (file d'attente). This is distinct from:
--   • expected_date  — the delivery date promised to the client (agenda), and
--   • start_date     — when the order was taken in.
-- Header field only (not financial) → plain column, editable in place.
-- ============================================================================

ALTER TABLE orders ADD COLUMN planned_date date;

-- Fast lookup of a day's / week's programme; skips the many unplanned rows.
CREATE INDEX orders_planned_idx ON orders (planned_date)
  WHERE planned_date IS NOT NULL;
