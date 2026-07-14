-- ============================================================================
-- Item 9 — per-shop aesthetic identity. A public brand colour (hex) so each
-- resold instance can feel bespoke: it themes the app and shows on the login
-- screen. Public (readable pre-auth) like shop_name / logo_url; editable by the
-- manager in Paramètres. Default = the house Deep Teal.
-- ============================================================================

INSERT INTO settings (key, value, is_public) VALUES
  ('theme_color', '"#006D6D"', true)
ON CONFLICT (key) DO NOTHING;
