#!/usr/bin/env bash
# Provision a COMPLETE new shop instance on the VPS in one interactive run:
#   questions → unique port + strong secrets → git clone → .env → docker up
#   → setup-shop → nginx server block → certbot HTTPS → backup cron
#   → ready-to-paste registry CSV line + credentials handover.
#
# Run ON THE VPS as root:
#     ./scripts/new-shop.sh                 # provision a new shop
#     ./scripts/new-shop.sh --delete <slug> # tear a shop down (asks twice)
#
# Env overrides:
#   SHOPS_DIR        base dir of shop deployments        (default /srv)
#   WEB_ROOT_BASE    base dir of web builds               (default /var/www)
#   REPO_URL         git repo to clone (default: origin of an existing shop)
#   CERTBOT_EMAIL    email for the FIRST certbot registration on this server
#   NEW_SHOP_DRY_RUN=1  answer questions + print everything that WOULD be done
#                       (env file, nginx block, cron line, CSV) without touching
#                       the system — safe to run anywhere, used by local tests.
#
# Never touches existing shops: refuses to reuse an existing folder, port, or
# secret, and only ever writes inside the NEW shop's folder + its own nginx
# file + one new crontab line.
set -euo pipefail

SHOPS_DIR="${SHOPS_DIR:-/srv}"
WEB_ROOT_BASE="${WEB_ROOT_BASE:-/var/www}"
NGINX_AVAIL="${NGINX_AVAIL:-/etc/nginx/sites-available}"
NGINX_ENABLED="${NGINX_ENABLED:-/etc/nginx/sites-enabled}"
DRY="${NEW_SHOP_DRY_RUN:-0}"

say()  { printf '\n\033[1;36m%s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m  ! %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31mERREUR: %s\033[0m\n' "$*" >&2; exit 1; }

ask() { # ask "Question" "default" -> REPLY
  local q="$1" def="${2:-}" ans
  if [ -n "$def" ]; then
    read -r -p "$q [$def] : " ans; REPLY="${ans:-$def}"
  else
    read -r -p "$q : " ans; REPLY="$ans"
  fi
}

slugify() { # "Atelier Diallo & Fils" -> atelier-diallo-fils
  local s
  s="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  # Strip accents when iconv is available; otherwise keep going (accented
  # chars just become dashes in the next step).
  if command -v iconv >/dev/null 2>&1; then
    s="$(printf '%s' "$s" | iconv -f utf8 -t ascii//TRANSLIT 2>/dev/null || printf '%s' "$s")"
  fi
  printf '%s' "$s" | sed -e 's/[^a-z0-9]\+/-/g' -e 's/^-\+//' -e 's/-\+$//'
}

gen_secret() { # strong hex secret, PROVABLY unique across every existing .env
  local s
  while :; do
    s="$(openssl rand -hex 32)"
    grep -qsrF "$s" "$SHOPS_DIR"/*/.env 2>/dev/null || { printf '%s' "$s"; return; }
  done
}

gen_password() { # shorter human-typable strong password (login screens)
  printf '%s' "$(openssl rand -hex 6 | tr 'a-f' 'A-F')@$(openssl rand -hex 3)"
}

# ---------------------------------------------------------------- delete mode
if [ "${1:-}" = "--delete" ]; then
  slug="${2:?usage: new-shop.sh --delete <slug>}"
  dir="$SHOPS_DIR/$slug"
  [ -f "$dir/docker-compose.yml" ] || die "$dir n'est pas un déploiement de salon"
  warn "SUPPRESSION DÉFINITIVE de $dir (conteneurs, BASE DE DONNÉES, volumes, nginx, cron)."
  read -r -p "Retapez le slug pour confirmer : " confirm
  [ "$confirm" = "$slug" ] || die "confirmation incorrecte — rien n'a été touché"
  ( cd "$dir" && docker compose down -v --remove-orphans ) || warn "docker compose down a échoué (déjà arrêté ?)"
  rm -rf "$dir" "$WEB_ROOT_BASE/${slug}-web"
  rm -f "$NGINX_ENABLED/$slug" "$NGINX_AVAIL/$slug"
  nginx -t && systemctl reload nginx || warn "reload nginx à vérifier"
  ( crontab -l 2>/dev/null | grep -vF "cd $dir && ./scripts/backup.sh" ) | crontab - || true
  echo "Certificat HTTPS : supprimez-le vous-même si besoin :  certbot delete"
  echo "✅ Salon '$slug' supprimé."
  exit 0
fi

# ------------------------------------------------------------- pre-flight
if [ "$DRY" != "1" ]; then
  [ "$(id -u)" = "0" ] || die "à lancer en root (nginx/certbot/crontab)"
  for c in git docker nginx certbot openssl curl; do
    command -v "$c" >/dev/null || die "commande manquante: $c"
  done
else
  say "MODE SIMULATION (dry-run) — rien ne sera modifié."
fi

# ------------------------------------------------------------- questions
say "═══ Nouveau salon ═══"
ask "Nom du salon (ex: Atelier Diallo)"; shop_name="$REPLY"
[ -n "$shop_name" ] || die "le nom est obligatoire"

ask "Slug (dossier + sous-domaines)" "$(slugify "$shop_name")"; slug="$REPLY"
printf '%s' "$slug" | grep -qE '^[a-z0-9][a-z0-9-]*$' || die "slug invalide: $slug"
dir="$SHOPS_DIR/$slug"
[ -e "$dir" ] && die "$dir existe déjà — ce script ne touche JAMAIS un salon existant"

ask "Domaine de base (ex: couturepro.app)"; base_domain="$REPLY"
[ -n "$base_domain" ] || die "domaine obligatoire"
ask "Sous-domaine API" "api.$slug.$base_domain"; api_domain="$REPLY"
ask "Sous-domaine App (web)" "app.$slug.$base_domain"; app_domain="$REPLY"

# Unique port: first free one ≥ 3001, checking every existing shop's .env
# AND what is actually listening on the host.
used_ports="$(grep -hsE '^API_PORT=' "$SHOPS_DIR"/*/.env 2>/dev/null | cut -d= -f2 | tr -d ' \t\r' || true)"
port=3001
while printf '%s\n' "$used_ports" | grep -qx "$port" \
      || { command -v ss >/dev/null && ss -ltn 2>/dev/null | grep -q ":$port "; }; do
  port=$((port + 1))
done
ask "Port hôte de l'API (unique par salon)" "$port"; api_port="$REPLY"
printf '%s\n' "$used_ports" | grep -qx "$api_port" && die "port $api_port déjà pris par un autre salon"

ask "Tarif à la pièce par défaut (FCFA)" "0"; piece_rate="$REPLY"
ask "Lien groupe promo WhatsApp (vide si aucun)" ""; promo_link="$REPLY"

# ------------------------------------------------------------- secrets
say "Génération des secrets (uniques, jamais réutilisés)…"
jwt_secret="$(gen_secret)"
db_password="$(gen_secret)"
manager_pw="$(gen_password)"
secretary_pw="$(gen_password)"

# ------------------------------------------------------------- repo url
repo_url="${REPO_URL:-}"
if [ -z "$repo_url" ]; then
  for d in "$SHOPS_DIR"/*/; do
    [ -d "${d}.git" ] || continue
    repo_url="$(git -C "$d" remote get-url origin 2>/dev/null || true)"
    [ -n "$repo_url" ] && break
  done
fi
ask "URL du dépôt git" "${repo_url:-https://github.com/asse-byte/Tailoring-Order-Management-System.git}"
repo_url="$REPLY"

# ------------------------------------------------------------- .env content
env_content="# Salon: $shop_name — généré par new-shop.sh le $(date +%F)
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
DEFAULT_PIECE_RATE=$piece_rate
PROMO_GROUP_LINK=$promo_link"

# ------------------------------------------------------------- nginx block
web_root="$WEB_ROOT_BASE/${slug}-web"
nginx_conf="server {
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
}"

# Stagger backup time so shops don't all dump at the same minute.
shop_count="$(find "$SHOPS_DIR" -mindepth 2 -maxdepth 2 -name docker-compose.yml 2>/dev/null | wc -l)"
cron_min=$(( (shop_count * 7) % 60 ))
cron_line="$cron_min 3 * * * cd $dir && ./scripts/backup.sh >> /var/log/couture-backup.log 2>&1"

# ------------------------------------------------------------- CSV line
today="$(date +%F)"
app_id_suggestion="com.couturepro.$(printf '%s' "$slug" | tr -d '-')"
csv_line="$shop_name,$dir,$api_port,$api_domain,$app_domain,$app_id_suggestion,$shop_name,,yes,no,$today,,,,${today},à déployer,\"backup cron actif — tester restore.sh puis passer backup_ok=yes\""

if [ "$DRY" = "1" ]; then
  say "─── .env qui serait écrit ───";   printf '%s\n' "$env_content"
  say "─── nginx: $NGINX_AVAIL/$slug ───"; printf '%s\n' "$nginx_conf"
  say "─── ligne crontab ───";           printf '%s\n' "$cron_line"
  say "─── ligne CSV (registre) ───";    printf '%s\n' "$csv_line"
  say "Dry-run terminé — rien n'a été modifié."
  exit 0
fi

# ------------------------------------------------------------- execute
say "[1/7] Clone du dépôt → $dir"
git clone "$repo_url" "$dir"

say "[2/7] Écriture du .env"
printf '%s\n' "$env_content" > "$dir/.env"
chmod 600 "$dir/.env"

say "[3/7] Démarrage Docker (build + up)…"
( cd "$dir" && docker compose up -d --build )

say "    Attente de l'API sur :$api_port…"
ok=""
for _ in $(seq 1 60); do
  if curl -fsS "http://localhost:$api_port/api/settings/public" >/dev/null 2>&1; then ok=1; break; fi
  sleep 2
done
[ -n "$ok" ] || die "l'API ne répond pas sur :$api_port — voir: cd $dir && docker compose logs api"

say "[4/7] setup-shop (migrations + comptes + identité)…"
( cd "$dir" && docker compose exec -T api npm run setup-shop )

say "[5/7] nginx pour $api_domain + $app_domain"
# install -d sets the mode explicitly (755) regardless of root's umask, so
# nginx (www-data) can always traverse the web root. A plain `mkdir -p` would
# inherit a 077 umask → 700 → nginx gets 403/HTML for every asset.
install -d -m 755 "$web_root"
[ -f "$web_root/index.html" ] || printf '<h1>%s</h1><p>Application en cours d&#39;installation…</p>\n' "$shop_name" > "$web_root/index.html"
# Ensure everything already under the web root is world-readable/traversable
# (harmless when empty; corrects perms after a future upload runs through here).
chmod -R o+rX "$web_root"
printf '%s\n' "$nginx_conf" > "$NGINX_AVAIL/$slug"
ln -sf "$NGINX_AVAIL/$slug" "$NGINX_ENABLED/$slug"
nginx -t
systemctl reload nginx

say "[6/7] Certificat HTTPS (certbot)"
server_ip="$(curl -fsS -4 https://ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')"
dns_ok=1
for d in "$api_domain" "$app_domain"; do
  resolved="$(getent hosts "$d" | awk '{print $1}' | head -1 || true)"
  if [ "$resolved" != "$server_ip" ]; then
    warn "$d → '${resolved:-non résolu}' (serveur: $server_ip) — DNS pas encore propagé ?"
    dns_ok=0
  fi
done
if [ "$dns_ok" = "1" ]; then
  certbot --nginx -d "$api_domain" -d "$app_domain" --non-interactive --agree-tos \
    ${CERTBOT_EMAIL:+--email "$CERTBOT_EMAIL"} \
    || warn "certbot a échoué — relancez plus tard: certbot --nginx -d $api_domain -d $app_domain"
else
  warn "certbot SAUTÉ (DNS). Une fois le DNS pointé, lancez:"
  warn "  certbot --nginx -d $api_domain -d $app_domain"
fi

say "[7/7] Cron de sauvegarde quotidienne"
if crontab -l 2>/dev/null | grep -qF "cd $dir && ./scripts/backup.sh"; then
  echo "  déjà présent."
else
  ( crontab -l 2>/dev/null; printf '%s\n' "$cron_line" ) | crontab -
  echo "  ajouté: $cron_line"
fi

# ------------------------------------------------------------- summary
say "═══════════ ✅ Salon '$shop_name' provisionné ═══════════"
cat <<EOF

  API      : https://$api_domain   (port interne :$api_port)
  Web      : https://$app_domain   (racine: $web_root — encore vide)
  Dossier  : $dir

  ── Identifiants à remettre au client (montrés UNE fois — notez-les) ──
  Gérant     : gerant / $manager_pw
  Secrétaire : secretaire / $secretary_pw

  ── Ligne à coller dans docs/shops-registry-template.csv ──
$csv_line

  ── Étapes restantes (sur votre machine de dev) ──
  1. Builder web + APK pour ce salon :
     .\\scripts\\build-shop-app.ps1 -ShopSlug $slug -AppId $app_id_suggestion \`
        -AppName "$shop_name" -ApiUrl https://$api_domain
  2. Copier la build web SANS wildcard (tar évite tout fichier oublié) :
     tar -czf - -C dist/$slug/web . | ssh root@$server_ip "tar -xzf - -C $web_root && chmod -R o+rX $web_root"
     # Le chmod final est OBLIGATOIRE : une archive peut arriver en 700 et
     # nginx (www-data) renverrait alors du HTML pour chaque fichier.
  3. Tester la restauration une fois: cd $dir && ./scripts/restore.sh backups/db_*.sql.gz
     puis passer backup_ok=yes dans le registre.
  4. Configurer la copie HORS-SITE dans scripts/backup.sh (rclone/scp).
EOF
