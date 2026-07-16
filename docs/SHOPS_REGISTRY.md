# Registre central des salons (fleet registry)

Votre tableau de bord commercial + technique : **une ligne par salon**. Sans lui,
gérer plusieurs déploiements devient vite ingérable. Ouvrez
`shops-registry-template.csv` dans Excel ou Google Sheets et remplissez une ligne
à chaque nouveau salon.

> Ce fichier peut contenir des informations sensibles (domaines, ports, contacts,
> tarifs). Gardez la copie remplie **privée** — ne la committez pas telle quelle
> dans un dépôt public. Le fichier versionné ici est un *modèle* avec une ligne
> démo + une ligne d'exemple.

## Colonnes

| Colonne | Sens |
| --- | --- |
| `shop_name` | Nom commercial du salon (= `SHOP_NAME` dans son `.env`) |
| `folder` | Dossier sur le VPS, ex. `/srv/rayan-couture` |
| `api_port` | Port hôte unique du salon (`API_PORT` dans `.env` : 3001, 3002…) |
| `api_domain` | Sous-domaine de l'API, ex. `api.rayan.couturepro.app` |
| `app_domain` | Sous-domaine du web, ex. `app.rayan.couturepro.app` |
| `app_id` | `appId` Android (permanent — ne jamais changer après livraison) |
| `app_name` | Nom sous l'icône (`appName` dans `gradle.properties`) |
| `apk_version` | Version de l'APK livré (`pubspec.yaml`, ex. `1.0.0`) |
| `jwt_secret_set` | `yes` = un `JWT_SECRET` unique et fort a été mis dans le `.env` |
| `backup_ok` | `yes` = backup automatique activé **et** restauration testée une fois |
| `delivered_date` | Date de remise au client |
| `contact_name` / `contact_phone` | Le gérant à contacter |
| `monthly_fee_fcfa` | Abonnement mensuel convenu (hébergement + maintenance) |
| `last_update` | Date du dernier `update-all.sh` appliqué |
| `status` | `demo` / `à déployer` / `en production` / `suspendu` |
| `notes` | Tout le reste (particularités, promesses, incidents) |

## Règles d'or (chaque ligne doit les respecter avant `status = en production`)

1. `api_port` **unique** par salon (sinon collision Docker au 2ᵉ salon).
2. `jwt_secret_set = yes` avec un secret **différent** de tout autre salon.
3. `app_id` **jamais réutilisé ni modifié** une fois livré.
4. `backup_ok = yes` — sauvegarde active ET restauration testée au moins une fois.
5. Mots de passe des comptes **forts** (pas les identifiants faciles de la démo).

## Rappel — 3 fichiers hors dépôt à ne jamais perdre

- Le `.env` de chaque salon (secrets) — sauvegardé hors VPS.
- Le keystore `.jks` + son mot de passe — sur votre machine, copie chiffrée ailleurs.
- Ce registre rempli — votre mémoire de toute l'opération.
