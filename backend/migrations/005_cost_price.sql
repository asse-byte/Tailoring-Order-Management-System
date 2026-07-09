-- Add cost_price column to products and pret_a_porter_models tables
-- for profit calculation (profit = price - cost_price).

ALTER TABLE products
  ADD COLUMN cost_price integer NOT NULL DEFAULT 0 CHECK (cost_price >= 0);

ALTER TABLE pret_a_porter_models
  ADD COLUMN cost_price integer NOT NULL DEFAULT 0 CHECK (cost_price >= 0);
