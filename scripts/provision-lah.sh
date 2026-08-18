#!/usr/bin/env bash
set -euo pipefail

SHOPS_DIR="/srv"
WEB_ROOT_BASE="/var/www"
NGINX_AVAIL="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"

slug="lah-collection"
shop_name="LAH COLLECTION"
base_domain="couturepro.app"
api_domain="api.lah-collection.couturepro.app"
app_domain="app.lah-collection.couturepro.app"
api_port="3004"
dir="$SHOPS_DIR/$slug"
web_root="$WEB_ROOT_BASE/${slug}-web"
repo_url="https://github.com/asse-byte/Tailoring-Order-Management-System.git"

echo "=== Provisioning $shop_name ($slug) on :$api_port ==="

if [ -d "$dir" ]; then
  echo "Directory $dir already exists!"
  exit 1
fi

gen_secret() {
  openssl rand -hex 32
}
gen_password() {
  printf '%s' "$(openssl rand -hex 6 | tr 'a-f' 'A-F')@$(openssl rand -hex 3)"
}

jwt_secret="$(gen_secret)"
db_password="$(gen_secret)"
manager_pw="$(gen_password)"
secretary_pw="$(gen_password)"

echo "[1/7] Cloning repo to $dir..."
git clone "$repo_url" "$dir"

echo "[2/7] Writing .env..."
cat <<EOF > "$dir/.env"
# Salon: $shop_name — provisioned on $(date +%F)
DB_PASSWORD=$db_password
JWT_SECRET=$jwt_secret
API_PORT=$api_port
SEED_MANAGER_USERNAME=gerant
SEED_MANAGER_PASSWORD=$manager_pw
SEED_MANAGER_NAME=Le Gérant
SEED_SECRETARY_USERNAME=secretaire
SEED_SECRETARY_PASSWORD=$secretary_pw
SEED_SECRETARY_NAME=La Secrétaire
SHOP_NAME=$shop_name
DEFAULT_PIECE_RATE=0
PROMO_GROUP_LINK=
EOF
chmod 600 "$dir/.env"

echo "[3/7] Starting Docker containers..."
( cd "$dir" && docker compose up -d --build )

echo "Waiting for API to answer on port $api_port..."
ok=""
for _ in $(seq 1 60); do
  if curl -fsS "http://localhost:$api_port/api/settings/public" >/dev/null 2>&1; then ok=1; break; fi
  sleep 2
done
if [ -z "$ok" ]; then
  echo "ERROR: API did not respond on :$api_port"
  cd "$dir" && docker compose logs api
  exit 1
fi

echo "[4/7] Running setup-shop..."
( cd "$dir" && docker compose exec -T api npm run setup-shop )

# Copy logo and set settings
if [ -f "/tmp/lah_collection_logo.jpg" ]; then
  echo "Attaching logo and luxury gold theme..."
  docker cp /tmp/lah_collection_logo.jpg lah-collection-api-1:/app/uploads/lah_collection_logo.jpg
  docker compose -f "$dir/docker-compose.yml" exec -T db psql -U couture -d couture_mali -c "UPDATE settings SET value = '\"/uploads/lah_collection_logo.jpg\"'::jsonb WHERE key = 'logo_url';"
  docker compose -f "$dir/docker-compose.yml" exec -T db psql -U couture -d couture_mali -c "UPDATE settings SET value = '\"#D4AF37\"'::jsonb WHERE key = 'theme_color';"
fi

echo "[5/7] Configuring Nginx..."
install -d -m 755 "$web_root"
[ -f "$web_root/index.html" ] || printf '<h1>%s</h1><p>Application en cours d&#39;installation…</p>\n' "$shop_name" > "$web_root/index.html"
chmod -R o+rX "$web_root"

cat <<EOF > "$NGINX_AVAIL/$slug"
server {
    server_name $api_domain;
    location / {
        proxy_pass http://127.0.0.1:$api_port;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        client_max_body_size 20M;
    }
}
server {
    server_name $app_domain;
    root $web_root;
    location / { try_files \$uri \$uri/ /index.html; }
}
EOF

ln -sf "$NGINX_AVAIL/$slug" "$NGINX_ENABLED/$slug"
nginx -t
systemctl reload nginx

echo "[6/7] Obtaining SSL certificates..."
certbot --nginx -d "$api_domain" -d "$app_domain" --non-interactive --agree-tos --register-unsafely-without-email || echo "Certbot warning"

echo "[7/7] Adding daily backup cron..."
cron_line="28 3 * * * cd $dir && ./scripts/backup.sh >> /var/log/couture-backup.log 2>&1"
if ! crontab -l 2>/dev/null | grep -qF "cd $dir && ./scripts/backup.sh"; then
  ( crontab -l 2>/dev/null; printf '%s\n' "$cron_line" ) | crontab -
fi

echo "============================================================"
echo "  SHOP PROVISIONED SUCCESSFULLY"
echo "  Shop Name : $shop_name"
echo "  Slug      : $slug"
echo "  Port      : $api_port"
echo "  API URL   : https://$api_domain"
echo "  App URL   : https://$app_domain"
echo "  Manager   : gerant / $manager_pw"
echo "  Secretary : secretaire / $secretary_pw"
echo "============================================================"
