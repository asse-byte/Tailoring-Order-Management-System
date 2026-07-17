# Vendre l'app à un nouveau salon de couture — Guide de mise en service

**Modèle retenu : une instance isolée par salon.** Chaque salon a son propre
déploiement (Docker + base PostgreSQL dédiée). Aucune donnée n'est partagée
entre salons — isolation parfaite, et chaque salon se sent « fait pour lui »
(nom, logo, tarif, lien promo qui lui sont propres). C'est le modèle le plus
simple et le plus sûr tant qu'on reste sur un nombre raisonnable de salons.

> Pour passer plus tard à des centaines de salons sur un seul serveur, il
> faudrait le modèle multi-tenant (`shop_id` sur chaque table). Ce n'est **pas**
> le choix actuel — ne pas mélanger les deux.

---

## Ce qui rend chaque salon unique (tout est dynamique, zéro code à changer)

| Élément | Où le régler |
| --- | --- |
| Nom du salon (écran de login + factures) | `SHOP_NAME` au setup, puis Paramètres |
| Logo (login + PDF de facture) | Paramètres → upload, ou `tailoring_app/assets/logo.jpeg` avant de builder |
| Tarif à la pièce par défaut | `DEFAULT_PIECE_RATE`, puis Paramètres |
| Lien du groupe promo (facture/WhatsApp) | `PROMO_GROUP_LINK`, puis Paramètres |
| Comptes Gérant + Secrétaire | variables `SEED_*` |

Le logo de la facture suit cette priorité : logo uploadé → `assets/logo.jpeg`
groupé → placeholder « R ». Un salon a donc toujours un logo sur ses factures.

---

## Mettre en service un nouveau salon — AUTOMATISÉ (voie normale)

Deux commandes, c'est tout :

1. **Sur le VPS** (en root) — provisionne tout : port unique auto-détecté,
   secrets forts générés (JWT + DB + mots de passe des 2 comptes), clone,
   `.env`, Docker, `setup-shop`, bloc nginx, certificat HTTPS, cron de
   sauvegarde, et imprime la ligne CSV prête pour le registre :

   ```bash
   cd /srv/<un-salon-existant> && ./scripts/new-shop.sh
   ```

   Il pose 4-5 questions simples (nom, domaine…) et propose des défauts
   sensés partout. Il refuse de toucher un salon existant (dossier, port ou
   secret déjà pris ⇒ erreur). Test à blanc possible : `NEW_SHOP_DRY_RUN=1`.
   Suppression d'un salon de test : `./scripts/new-shop.sh --delete <slug>`.

2. **Sur votre machine de dev** — builde web + APK brandés pour ce salon en
   une commande (règle `gradle.properties`, builde, puis le RESTAURE) :

   ```powershell
   .\scripts\build-shop-app.ps1 -ShopSlug rayan-couture -AppId com.rayancouture.app `
       -AppName "Rayan Couture" -ApiUrl https://api.rayan-couture.<domaine>
   # sorties: dist\<slug>\web\  +  dist\<slug>\<slug>-v<version>.apk
   ```

   Puis copier la build web vers le VPS (`scp -r dist/<slug>/web/* root@…:/var/www/<slug>-web/`)
   et envoyer l'APK au client. Fin.

Après coup : coller la ligne CSV imprimée dans `docs/shops-registry-template.csv`,
tester une restauration (`./scripts/restore.sh backups/db_*.sql.gz`), et
configurer la copie hors-site dans `scripts/backup.sh`.

---

## Plan B — procédure MANUELLE (si le script échoue)

1. **Provisionner l'hébergement** : un déploiement Docker Compose + une base
   PostgreSQL vide dédiée à ce salon (même VPS si les ressources suffisent,
   sinon un petit droplet à part).

2. **Configurer `backend/.env`** pour ce salon (voir `backend/.env.example`) :
   ```
   DATABASE_URL=postgres://…/salon_diallo
   JWT_SECRET=<chaîne aléatoire longue, UNIQUE par salon>
   SEED_MANAGER_USERNAME=…      SEED_MANAGER_PASSWORD=…
   SEED_SECRETARY_USERNAME=…    SEED_SECRETARY_PASSWORD=…
   SHOP_NAME=Atelier Diallo
   DEFAULT_PIECE_RATE=1500
   PROMO_GROUP_LINK=https://chat.whatsapp.com/…
   ```
   > `JWT_SECRET` doit être différent pour chaque salon.

3. **Provisionner la base en une commande** :
   ```
   cd backend && npm run setup-shop
   ```
   Ceci enchaîne : migrations → création des 2 comptes → écriture de
   l'identité du salon (nom, tarif, lien promo). Idempotent : ré-exécutable
   sans risque (les comptes déjà créés ne sont pas dupliqués).

4. **Builder l'app** en pointant vers l'API de ce salon :
   ```
   cd tailoring_app && flutter build apk --dart-define=API_URL=https://api.salon-diallo.…
   ```
   (Déposer le logo dans `assets/logo.jpeg` avant le build, ou l'uploader
   ensuite depuis Paramètres.)

5. **Première connexion Gérant → Paramètres** : vérifier/ajuster nom, uploader
   le logo, régler le tarif par défaut. Le salon est opérationnel.

---

## Garanties conservées pour CHAQUE salon

- Isolation financière Gérant/Secrétaire (403 côté serveur, prouvé par les
  tests `backend/tests/`).
- Tables financières append-only + journaux de correction.
- Français, devise FCFA, nom/logo dynamiques.
