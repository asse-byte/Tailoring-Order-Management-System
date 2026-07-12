-- Item 7 — a promotional group link (WhatsApp/Facebook/…) the manager sets in
-- Paramètres and that is printed as a clickable line on every order invoice.
-- Public so the invoice can include it for both the manager and the secretary.
INSERT INTO settings (key, value, is_public) VALUES
  ('promo_group_link', '""', true)
ON CONFLICT (key) DO NOTHING;
