#!/usr/bin/env bash
set -e
docker cp /tmp/yatt_services_logo.jpg yatt-services-api-1:/app/uploads/yatt_services_logo.jpg
docker compose -f /srv/yatt-services/docker-compose.yml exec -T db psql -U couture -d couture_mali -c "UPDATE settings SET value = '\"/uploads/yatt_services_logo.jpg\"'::jsonb WHERE key = 'logo_url';"
docker compose -f /srv/yatt-services/docker-compose.yml exec -T db psql -U couture -d couture_mali -c "UPDATE settings SET value = '\"+223 77 44 39 56 / 91 26 26 95\"'::jsonb WHERE key = 'promo_group_link';"
curl -s http://localhost:3003/api/settings/public
echo ""
