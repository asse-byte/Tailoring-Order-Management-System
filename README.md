# Couture Mali - Tailoring Order Management System

نظام إدارة محل خياطة متكامل وعالي الأداء يدعم اللغتين الفرنسية والإنجليزية، ومصمم خصيصاً لتلبية متطلبات إدارة العملاء، المنتجات، العمال والأجور، والمالية.

An intuitive, high-performance tailoring order management application supporting French and English, built with role-based access control and local persistence support.

---

## 🚀 طريقة التشغيل / How to Run the App

لتشغيل التطبيق محلياً على جهازك، اتبع الخطوات التالية:
To run the application locally on your machine, follow these steps:

### 1. الانتقال إلى مجلد التطبيق / Navigate to the App Folder
افتح مبدل الأوامر (Terminal / Command Prompt) وانتقل لمجلد التطبيق:
```bash
cd tailoring_app
```

### 2. تنزيل المكتبات / Fetch Dependencies
تأكد من تنزيل جميع حزم ومكتبات Flutter المطلوبة:
```bash
flutter pub get
```

### 3. تشغيل التطبيق / Run the Application
يمكنك تشغيل التطبيق مباشرة على المتصفح (Chrome) باستخدام الأمر التالي:
```bash
flutter run -d chrome
```
أو تشغيل خادم الويب المحلي لتجربته على أي متصفح:
```bash
flutter run -d web-server --web-port=8080 --web-hostname=localhost
```
ثم افتح الرابط التالي في المتصفح:
```text
http://localhost:8080/
```

---

## 🔑 بيانات الدخول الافتراضية / Default Login Credentials

تم إعداد حسابات تجريبية مسبقاً لتجربة النظام مباشرة:
Pre-seeded accounts are available to immediately test the application roles:

| الدور / Role | البريد الإلكتروني / Email | كلمة المرور / Password | الصلاحيات والخصائص / Access & Features |
| :--- | :--- | :--- | :--- |
| **المدير / Admin** | `admin@tailor.app` | `Admin@1234` | صلاحيات كاملة (رؤية الأرباح والمصاريف، حساب أجور العمال أسبوعياً، وإدارة المنتجات والطلبات). / Full access to all financial details, staff wage calculators, and shop settings. |
| **السكرتير / Secretary** | `secretary@tailor.app` | `Secretary@1234` | صلاحيات مقيدة (إخفاء شاشة المالية بالكامل وحظر تفاصيل أجور العمال والرواتب في قائمة الموظفين). / Restricted access: Finance module is completely hidden, and staff salaries/wage calculators are hidden in the Personnel screen. |

> 💡 **ملاحظة / Note**: إذا واجهتك أي مشكلة في تسجيل الدخول لأول مرة، يمكنك الضغط على زر **"Configuration Administrateur"** (تهيئة المدير) أسفل شاشة تسجيل الدخول لتهيئة وتفعيل الحساب تلقائياً بضغطة زر.
> If you have any login issues, simply click **"Configuration Administrateur"** at the bottom of the login screen to seed and login instantly.

---

## 🐳 Déploiement et Production / Deployment & Production

### 1. Déploiement avec Docker Compose
Pour déployer l'application et la base de données PostgreSQL en production :

1. Copiez le fichier d'exemple des variables d'environnement à la racine du projet :
   ```bash
   cp .env.example .env
   ```
2. Modifiez le fichier `.env` avec des valeurs sécurisées (mot de passe de base de données et clé secrète JWT).
3. Lancez les services Docker en arrière-plan :
   ```bash
   docker compose up -d --build
   ```
4. Initialisez la base de données avec les comptes opérationnels par défaut (uniquement lors de la première installation) :
   ```bash
   docker compose exec api node scripts/seed.js
   ```

### 2. Sauvegarde et Restauration de la Base de Données

#### Sauvegarde (Backup)
Pour exporter l'ensemble des données de la base de données dans un fichier de sauvegarde SQL :
```bash
docker compose exec db pg_dump -U couture -d couture_mali > backup.sql
```

#### Restauration (Restore)
Pour restaurer la base de données à partir d'un fichier de sauvegarde SQL :
```bash
docker compose exec -T db psql -U couture -d couture_mali < backup.sql
```
