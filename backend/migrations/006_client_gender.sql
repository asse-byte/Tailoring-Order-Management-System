ALTER TABLE clients ADD COLUMN gender text NOT NULL DEFAULT 'homme' CHECK (gender IN ('homme', 'femme'));

INSERT INTO settings (key, value, is_public) VALUES ('custom_garments', '{"homme": {}, "femme": {}}', true)
ON CONFLICT (key) DO NOTHING;
