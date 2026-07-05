-- Final shop name: "Rayan Couture" (proper case, editable in Paramètres).
-- Only replaces the old seed value — a name the manager already customised
-- is left untouched.

UPDATE settings
SET value = '"Rayan Couture"'
WHERE key = 'shop_name' AND value = '"RAYAN COUTURE"';
