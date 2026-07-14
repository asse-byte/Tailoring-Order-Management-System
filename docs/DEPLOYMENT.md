# Livraison & déploiement — Rayan Couture

Guide de mise en production pour livrer l'app à un salon qui l'utilisera sur
**téléphones Android + iPhone + ordinateur portable**.

## Architecture de livraison

```
                    ┌─────────────────── VPS (DigitalOcean) ───────────────────┐
                    │  nginx (HTTPS, Let's Encrypt)                            │
  Android APK ─────▶│    ├─ api.mondomaine.com  → API Node (Docker :3000)      │
  iPhone (Safari) ─▶│    └─ app.mondomaine.com  → build web Flutter (statique) │
  Portable (navig.)▶│  PostgreSQL (Docker)  +  volume uploads                   │
                    └──────────────────────────────────────────────────────────┘
```

- **Android** : APK signé, installé directement (un fichier envoyé au salon).
- **iPhone + ordinateur portable** : ouvrent `https://app.mondomaine.com` dans
  le navigateur (le build web couvre les deux, aucun App Store nécessaire).
  *(Une app iOS native reste possible plus tard : elle exige un Mac + un compte
  Apple Developer à 99 $/an. Le web suffit pour démarrer.)*
- **HTTPS est obligatoire** : Android/iOS/navigateurs bloquent le HTTP simple.

---

## Étape 0 — Acheter un domaine (une fois)

Achetez un domaine bon marché (Namecheap, OVH, Porkbun… ~10 $/an). Dans le
DNS, créez deux enregistrements **A** vers l'IP de votre droplet :

```
api.mondomaine.com   A   <IP_DU_VPS>
app.mondomaine.com   A   <IP_DU_VPS>
```

---

## Étape 1 — Le serveur (VPS + Docker)

1. Créez un droplet DigitalOcean (Ubuntu, même méthode que EduGete). Installez
   Docker + Docker Compose.
2. Copiez le projet sur le VPS (`git clone …`).
3. Créez `.env` à la racine à partir de `backend/.env.example` :
   ```
   DB_PASSWORD=<mot de passe fort>
   JWT_SECRET=<chaîne aléatoire longue et UNIQUE>
   SEED_MANAGER_USERNAME=gerant     SEED_MANAGER_PASSWORD=<fort>
   SEED_SECRETARY_USERNAME=secretaire SEED_SECRETARY_PASSWORD=<fort>
   SHOP_NAME=Rayan Couture
   DEFAULT_PIECE_RATE=0
   PROMO_GROUP_LINK=
   ```
4. Démarrez, puis provisionnez le salon :
   ```
   docker compose up -d --build
   docker compose exec api npm run setup-shop
   ```
   `setup-shop` = migrations + les 2 comptes + identité du salon (idempotent).

L'API écoute alors sur le port 3000 du VPS.

---

## Étape 2 — HTTPS (nginx + Let's Encrypt)

Installez nginx + certbot sur le VPS. Reverse-proxy des deux sous-domaines
vers l'API (3000) et vers le dossier web statique :

```nginx
# /etc/nginx/sites-available/couture
server {
    server_name api.mondomaine.com;
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        client_max_body_size 20M;   # uploads jusqu'à 15 Mo
    }
}
server {
    server_name app.mondomaine.com;
    root /var/www/couture-web;       # build web Flutter (étape 3)
    location / { try_files $uri $uri/ /index.html; }
}
```

```
sudo ln -s /etc/nginx/sites-available/couture /etc/nginx/sites-enabled/
sudo certbot --nginx -d api.mondomaine.com -d app.mondomaine.com
sudo nginx -t && sudo systemctl reload nginx
```

certbot ajoute le HTTPS automatiquement. Testez : `https://api.mondomaine.com/api/settings/public` doit renvoyer le JSON du salon.

---

## Étape 3 — Version ordinateur / iPhone (build web)

Sur votre machine :
```
cd tailoring_app
flutter build web --release --dart-define=API_URL=https://api.mondomaine.com
```
Copiez `build/web/` vers `/var/www/couture-web` sur le VPS (scp/rsync). Le
salon ouvre alors `https://app.mondomaine.com` sur portable **et** iPhone.

---

## Étape 4 — L'APK Android (une fois la clé créée, réutilisable)

### 4.1 Créer la clé de signature (UNE SEULE FOIS — à garder précieusement)
> Perdre ce fichier = impossible de publier une mise à jour du même app id.
```
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA \
  -keysize 2048 -validity 10000 -alias upload
```
Rangez `upload-keystore.jks` hors du projet (ex. `C:/keys/`). Copiez
`tailoring_app/android/key.properties.example` → `android/key.properties` et
remplissez-le (chemin absolu du .jks + mots de passe). Ce fichier est
git-ignoré — ne le committez jamais.

### 4.2 Construire l'APK signé
```
cd tailoring_app
flutter build apk --release --dart-define=API_URL=https://api.mondomaine.com
```
Résultat : `build/app/outputs/flutter-apk/app-release.apk`.

### 4.3 Installer sur les téléphones du salon
Envoyez le fichier `.apk` (WhatsApp, câble, Drive…). Sur le téléphone :
autoriser « Installer des applications inconnues » pour l'app d'où vient le
fichier, puis ouvrir l'APK → Installer.

---

## Étape 5 — Remettre au client

- URL de l'app web : `https://app.mondomaine.com` (portable + iPhone).
- APK installé sur les téléphones Android.
- Les 2 comptes : **Gérant** (accès total) et **Secrétaire** (sans finances).
- Première connexion Gérant → **Paramètres** : vérifier le nom, téléverser le
  logo, régler le tarif à la pièce par défaut.

---

## Mises à jour plus tard

- **Serveur** : `git pull && docker compose up -d --build` (les migrations
  tournent automatiquement au démarrage).
- **App** : rebuild web (copier `build/web`) et/ou rebuild l'APK (même clé,
  incrémenter la version) et le renvoyer.

## Vendre à un autre salon

Répétez avec une nouvelle base/instance (voir `docs/ONBOARDING_NEW_SHOP.md`) :
autre `.env` (autre `SHOP_NAME`, `JWT_SECRET`), autres sous-domaines, et
rebuild avec le bon `API_URL`. Modèle : une instance isolée par salon.
