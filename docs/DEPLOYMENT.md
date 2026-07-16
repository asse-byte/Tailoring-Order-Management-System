# Livraison & déploiement — Rayan Couture

> **Version de référence : `DEPLOYMENT_AR.md` (arabe)** — plus complète
> (multi-salons via sous-domaines, port par salon `API_PORT`, sauvegardes
> hors VPS, checklist de livraison). Ce document reste un résumé français.

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

---

## Personnaliser l'app au nom de CHAQUE salon

Tout ce qui identifie le salon est décidé **au moment du build** — un seul code
source, autant de salons que vous voulez.

| Élément | Comment | Où ça se voit |
| --- | --- | --- |
| Nom sur l'écran d'accueil du téléphone | `appName` dans `android/gradle.properties` | Sous l'icône Android |
| Identifiant technique de l'app | `appId` dans `android/gradle.properties` | Interne (2 salons = 2 ids) |
| Nom dans l'app (login, factures) | `SHOP_NAME` (base de données) | Partout dans l'app + PDF |
| Logo | Paramètres → téléverser | Login, factures |
| Onglet du navigateur (web) | automatique (lit `SHOP_NAME`) | Version web |

Recette complète pour un nouveau salon « Atelier Diallo » :

1. Éditez `tailoring_app/android/gradle.properties` :
   ```properties
   appName=Atelier Diallo
   appId=com.atelierdiallo.app
   ```
2. Construisez avec l'API du salon :
   ```bash
   cd tailoring_app
   flutter build apk --release --dart-define=API_URL=https://api.atelier-diallo.com
   ```

> Ces deux valeurs doivent passer par `gradle.properties` : les variables
> d'environnement `ORG_GRADLE_PROJECT_*` ne sont **pas** transmises à Gradle
> par `flutter build` (vérifié — l'APK sortait avec les valeurs par défaut).

**Une fois un salon livré, ne changez plus son `appId`** (Android verrait une
app différente) et gardez **son** keystore. Astuce : notez le triplet
(`appName`, `appId`, `API_URL`) de chaque salon dans un tableau à part.

L'icône du lanceur reste commune. Pour une icône par salon : remplacez
`assets/logo.jpeg` + `android/app/src/main/res/mipmap-*/ic_launcher.png`
(le paquet `flutter_launcher_icons` automatise ça) avant le build.

---

## Vendre au 2e, 3e… salon (répéter la recette)

Modèle : **une instance isolée par salon** (voir `docs/ONBOARDING_NEW_SHOP.md`).
Pour chaque nouveau salon, répétez :

1. **Base + API** : nouveau dossier/stack Docker avec son `.env` — `SHOP_NAME`,
   `JWT_SECRET` **unique**, mots de passe uniques, et un port interne libre
   (3001, 3002…). Puis `docker compose up -d --build` +
   `docker compose exec api npm run setup-shop`.
2. **Domaine** : un sous-domaine par salon (`api.salon2.com`) pointant sur le
   même VPS ; nouveau bloc nginx + `certbot --nginx -d …`.
3. **Web** : `flutter build web --release --dart-define=API_URL=https://api.salon2.com`
   → copier dans `/var/www/salon2-web` + bloc nginx.
4. **APK** : build avec `appName` / `appId` / `API_URL` du salon (ci-dessus).
5. **Livrer** : APK + URL web + les 2 comptes.

Rien n'est partagé entre salons : bases, secrets et données restent isolés.

---

## Maintenance & nouvelles fonctionnalités

**Règle d'or : on ne développe jamais en production.** Le cycle :

1. Développez et testez **en local** (`npm run dev` + `flutter run`), avec les
   tests : `cd backend && npm test` (la suite prouve entre autres que la
   secrétaire n'accède à aucune donnée financière — elle doit toujours passer).
2. `git commit` + `git push`.
3. **Mettre à jour un salon (serveur)** :
   ```bash
   ssh root@<VPS>
   cd <dossier-du-salon>
   git pull
   docker compose up -d --build     # les migrations tournent au démarrage
   ```
   Le schéma évolue uniquement par de **nouveaux fichiers** dans
   `backend/migrations/` (jamais en modifiant un fichier déjà appliqué).
4. **Mettre à jour l'app** :
   - Web : rebuild + recopier `build/web` → le salon recharge la page, c'est tout.
   - Android : incrémentez la version dans `pubspec.yaml`
     (`version: 1.0.1+2` → nom+numéro de build), rebuild l'APK **avec le même
     keystore et le même appId**, renvoyez le fichier. Le salon l'installe
     par-dessus : les données sont conservées.

**Sauvegardes (à faire avant toute mise à jour)** :
```bash
docker compose exec db pg_dump -U couture couture_mali > backup_$(date +%F).sql
```
Sauvegardez aussi le volume `uploads_data` (photos) et **le keystore**.

**Ordre de déploiement** : serveur d'abord (l'API reste compatible avec
l'ancienne app), l'app ensuite.
