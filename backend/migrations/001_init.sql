-- ============================================================================
-- Couture Mali — initial schema
-- ============================================================================
-- Money is FCFA/XOF stored as integers (no decimals).
-- Financial history (tailor_daily_entries, expenses and their corrections)
-- is APPEND-ONLY, enforced by triggers: even a direct SQL session cannot
-- UPDATE or DELETE those rows. Corrections are new rows with a mandatory
-- reason — the full audit trail survives forever.
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ---------- users -----------------------------------------------------------

CREATE TABLE users (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  username      text NOT NULL UNIQUE,
  password_hash text NOT NULL,
  name          text NOT NULL DEFAULT '',
  role          text NOT NULL CHECK (role IN ('MANAGER', 'SECRETARY')),
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- ---------- clients ----------------------------------------------------------

CREATE TABLE clients (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name  text NOT NULL,
  phone      text NOT NULL DEFAULT '',
  address    text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX clients_name_idx  ON clients (lower(full_name) text_pattern_ops);
CREATE INDEX clients_phone_idx ON clients (phone);

CREATE TABLE client_measurements (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id    uuid NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
  garment_type text NOT NULL,
  measures     jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (client_id, garment_type)
);

-- ---------- products & prêt-à-porter ----------------------------------------

CREATE TABLE products (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category            text NOT NULL CHECK (category IN ('parfum', 'chaussure', 'tissu')),
  name                text NOT NULL,
  price               integer NOT NULL CHECK (price >= 0),
  quantity            integer NOT NULL DEFAULT 0 CHECK (quantity >= 0),
  low_stock_threshold integer NOT NULL DEFAULT 3,
  created_at          timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX products_category_idx ON products (category, name);

CREATE TABLE product_images (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  url        text NOT NULL,
  thumb_url  text
);

CREATE TABLE pret_a_porter_models (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name        text NOT NULL,
  fabric_type text NOT NULL DEFAULT '',
  price       integer NOT NULL CHECK (price >= 0),
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE model_media (
  id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  model_id  uuid NOT NULL REFERENCES pret_a_porter_models(id) ON DELETE CASCADE,
  url       text NOT NULL,
  kind      text NOT NULL DEFAULT 'image' CHECK (kind IN ('image', 'video')),
  thumb_url text
);

-- ---------- sales [FINANCE] --------------------------------------------------
-- unit_price/total are written by the server from DB prices, inside the same
-- transaction that decrements stock. The client never sends prices.

CREATE TABLE sales (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  kind       text NOT NULL CHECK (kind IN ('produit', 'pret_a_porter')),
  item_id    uuid NOT NULL,
  item_name  text NOT NULL,
  qty        integer NOT NULL CHECK (qty > 0),
  unit_price integer NOT NULL CHECK (unit_price >= 0),
  total      integer NOT NULL CHECK (total = qty * unit_price),
  sold_at    timestamptz NOT NULL DEFAULT now(),
  created_by uuid NOT NULL REFERENCES users(id)
);
CREATE INDEX sales_sold_at_idx ON sales (sold_at DESC);
CREATE INDEX sales_kind_idx    ON sales (kind, sold_at DESC);

-- ---------- staff ------------------------------------------------------------
-- Contact info (secretary may read) is split from pay data (manager only).

CREATE TABLE staff (
  id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name text NOT NULL,
  phone     text NOT NULL DEFAULT '',
  type      text NOT NULL CHECK (type IN ('couturier', 'autre')),
  joined_at date NOT NULL DEFAULT CURRENT_DATE,
  active    boolean NOT NULL DEFAULT true
);

CREATE TABLE staff_pay (
  staff_id       uuid PRIMARY KEY REFERENCES staff(id) ON DELETE CASCADE,
  piece_rate     integer CHECK (piece_rate >= 0),
  monthly_salary integer CHECK (monthly_salary >= 0),
  salary_due_day integer CHECK (salary_due_day BETWEEN 1 AND 31)
);

-- ---------- tailor daily entries [FINANCE, APPEND-ONLY] -----------------------

CREATE TABLE tailor_daily_entries (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tailor_id    uuid NOT NULL REFERENCES staff(id),
  entry_date   date NOT NULL,
  pieces_count integer NOT NULL CHECK (pieces_count >= 0),
  piece_rate   integer NOT NULL CHECK (piece_rate >= 0),
  -- The DB computes the amount; it cannot be forged by any caller.
  amount       integer GENERATED ALWAYS AS (pieces_count * piece_rate) STORED,
  week_id      text NOT NULL,
  created_by   uuid NOT NULL REFERENCES users(id),
  created_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tailor_id, entry_date)
);
CREATE INDEX tde_week_idx   ON tailor_daily_entries (week_id);
CREATE INDEX tde_tailor_idx ON tailor_daily_entries (tailor_id, entry_date);

CREATE TABLE entry_corrections (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  entry_id     uuid NOT NULL REFERENCES tailor_daily_entries(id),
  old_pieces   integer NOT NULL,
  new_pieces   integer NOT NULL CHECK (new_pieces >= 0),
  reason       text NOT NULL CHECK (length(trim(reason)) > 0),
  corrected_by uuid NOT NULL REFERENCES users(id),
  corrected_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX entry_corrections_entry_idx ON entry_corrections (entry_id, corrected_at DESC);

-- ---------- expenses [FINANCE, APPEND-ONLY] ------------------------------------

CREATE TABLE expenses (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reason     text NOT NULL CHECK (length(trim(reason)) > 0),
  amount     integer NOT NULL CHECK (amount >= 0),
  spent_at   date NOT NULL DEFAULT CURRENT_DATE,
  created_by uuid NOT NULL REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX expenses_spent_idx ON expenses (spent_at DESC);

CREATE TABLE expense_corrections (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  expense_id   uuid NOT NULL REFERENCES expenses(id),
  new_amount   integer NOT NULL CHECK (new_amount >= 0),
  new_reason   text NOT NULL,
  voided       boolean NOT NULL DEFAULT false,
  reason       text NOT NULL CHECK (length(trim(reason)) > 0),
  corrected_by uuid NOT NULL REFERENCES users(id),
  corrected_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX expense_corrections_idx ON expense_corrections (expense_id, corrected_at DESC);

-- ---------- append-only enforcement -------------------------------------------
-- History can NEVER be rewritten, not even by a superuser session that
-- forgets itself. Corrections are the only path, and they are themselves
-- append-only.

CREATE FUNCTION forbid_mutation() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'Table % est en append-only: % interdit (utilisez une correction).',
    TG_TABLE_NAME, TG_OP;
END $$;

CREATE TRIGGER tde_append_only
  BEFORE UPDATE OR DELETE ON tailor_daily_entries
  FOR EACH ROW EXECUTE FUNCTION forbid_mutation();
CREATE TRIGGER entry_corrections_append_only
  BEFORE UPDATE OR DELETE ON entry_corrections
  FOR EACH ROW EXECUTE FUNCTION forbid_mutation();
CREATE TRIGGER expenses_append_only
  BEFORE UPDATE OR DELETE ON expenses
  FOR EACH ROW EXECUTE FUNCTION forbid_mutation();
CREATE TRIGGER expense_corrections_append_only
  BEFORE UPDATE OR DELETE ON expense_corrections
  FOR EACH ROW EXECUTE FUNCTION forbid_mutation();

-- ---------- effective views (latest correction wins) ---------------------------

CREATE VIEW tailor_entries_effective AS
SELECT e.id, e.tailor_id, e.entry_date, e.week_id, e.piece_rate,
       COALESCE(c.new_pieces, e.pieces_count)                AS pieces_count,
       COALESCE(c.new_pieces, e.pieces_count) * e.piece_rate AS amount,
       (c.id IS NOT NULL)                                    AS corrected,
       e.created_by, e.created_at
FROM tailor_daily_entries e
LEFT JOIN LATERAL (
  SELECT id, new_pieces FROM entry_corrections c
  WHERE c.entry_id = e.id
  ORDER BY corrected_at DESC, id DESC LIMIT 1
) c ON true;

CREATE VIEW expenses_effective AS
SELECT x.id,
       COALESCE(c.new_reason, x.reason) AS reason,
       COALESCE(c.new_amount, x.amount) AS amount,
       COALESCE(c.voided, false)        AS voided,
       (c.id IS NOT NULL)               AS corrected,
       x.spent_at, x.created_by, x.created_at
FROM expenses x
LEFT JOIN LATERAL (
  SELECT id, new_amount, new_reason, voided FROM expense_corrections c
  WHERE c.expense_id = x.id
  ORDER BY corrected_at DESC, id DESC LIMIT 1
) c ON true;

-- ---------- orders --------------------------------------------------------------

CREATE TABLE orders (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id             uuid NOT NULL REFERENCES clients(id),
  garment_type          text NOT NULL,
  fabric                text NOT NULL DEFAULT '',
  measurements_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
  price                 integer NOT NULL DEFAULT 0 CHECK (price >= 0),
  advance               integer NOT NULL DEFAULT 0 CHECK (advance >= 0),
  start_date            date NOT NULL DEFAULT CURRENT_DATE,
  expected_date         date,
  delivered_date        date,
  status                text NOT NULL DEFAULT 'en_cours'
                        CHECK (status IN ('en_cours', 'pret', 'livre')),
  notes                 text,
  created_at            timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX orders_status_expected_idx  ON orders (status, expected_date);
CREATE INDEX orders_client_idx           ON orders (client_id, created_at DESC);
CREATE INDEX orders_status_delivered_idx ON orders (status, delivered_date DESC);

-- ---------- appointments ----------------------------------------------------------

CREATE TABLE appointments (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id    uuid NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
  scheduled_at timestamptz NOT NULL,
  reason       text NOT NULL DEFAULT 'autre'
               CHECK (reason IN ('mesure', 'essayage', 'livraison', 'autre')),
  notes        text,
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX appointments_time_idx ON appointments (scheduled_at);

-- ---------- settings ----------------------------------------------------------------
-- Public rows feed the login screen before authentication; private rows are
-- financial and manager-only.

CREATE TABLE settings (
  key       text PRIMARY KEY,
  value     jsonb NOT NULL,
  is_public boolean NOT NULL DEFAULT false
);

INSERT INTO settings (key, value, is_public) VALUES
  ('shop_name',          '"Rayan Couture"', true),
  ('logo_url',           'null',           true),
  ('default_piece_rate', '0',              false);
