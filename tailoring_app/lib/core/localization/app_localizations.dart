import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      // General
      'appName': 'Tailoring Studio',
      'tagline': 'Order. Track. Tailored.',
      'save': 'Save',
      'cancel': 'Cancel',
      'submit': 'Submit',
      'retry': 'Retry',
      'offlineBanner': 'You are offline — showing cached data.',
      'somethingWentWrong': 'Something went wrong.',
      'requiredField': 'Required',
      'loading': 'Loading...',
      'all': 'All',
      'search': 'Search',
      'yes': 'Yes',
      'no': 'No',

      // Validation
      'validationRequired': 'This field is required',
      'validationEmail': 'Enter a valid email address',
      'validationPassword': 'Password must be at least 6 characters',
      'validationConfirmPassword': 'Passwords do not match',
      'validationPhone': 'Enter a valid phone number',
      'validationPositiveNumber': 'Enter a positive number',

      // Onboarding
      'skip': 'Skip',
      'next': 'Next',
      'getStarted': 'Get started',
      'alreadyHaveAccountOnb': 'I already have an account',
      'onbTitle1': 'Order in seconds',
      'onbDesc1':
          'Pick a garment, share fabric and style references, and place your order from your phone.',
      'onbTitle2': 'Track every stitch',
      'onbDesc2':
          'Watch your order move from Pending to In Progress to Completed in real time.',
      'onbTitle3': 'Never miss a pickup',
      'onbDesc3':
          'Get notified the moment your order is ready — no more guessing or phone tag.',

      // Auth
      'login': 'Sign in',
      'register': 'Create account',
      'email': 'Email',
      'password': 'Password',
      'confirmPassword': 'Confirm password',
      'forgotPassword': 'Forgot password?',
      'forgotPasswordSubtitle':
          'Enter the email associated with your account and we’ll send you a reset link.',
      'sendResetLink': 'Send reset link',
      'dontHaveAccount': "Don't have an account?",
      'alreadyHaveAccount': 'Already have an account?',
      'resetPassword': 'Reset password',
      'resetEmailSent': 'Password reset email sent.',
      'signOut': 'Sign out',
      'adminSetup': 'Admin Setup',
      'adminSetupHint': 'One-time seed of the shop owner account.',
      'welcomeBack': 'Welcome back',
      'signInSubtitle':
          'Sign in to track your orders and manage your tailoring.',
      'adminSetupTitle': 'Set up the shop owner account',
      'adminSetupBtn': 'Create admin & sign in',
      'backToSignIn': 'Back to sign in',
      'changePassword': 'Change Password',
      'oldPassword': 'Current Password',
      'newPassword': 'New Password',
      'passwordChangedSuccess': 'Password updated successfully.',
      'updatePasswordTitle': 'Update your password',
      'changePasswordSub':
          'You’ll be reauthenticated before the change is applied.',
      'confirmNewPassword': 'Confirm new password',
      'updatePasswordBtn': 'Update password',
      'adminSetupReady': 'Admin account is ready. Welcome!',
      'changePasswordPrompt':
          'Change this password immediately after first login.',

      // Navigation / Tabs
      'myOrders': 'My Orders',
      'newOrder': 'New Order',
      'profile': 'Profile',
      'notifications': 'Notifications',
      'dashboard': 'Dashboard',
      'orders': 'Orders',
      'customers': 'Customers',
      'reports': 'Reports',
      'settings': 'Settings',

      // Customer Dashboard & Profile
      'signOutConfirmTitle': 'Sign out?',
      'signOutConfirmCustomer':
          'You will need to sign in again to view your orders.',
      'signOutConfirmAdmin': 'You will need to sign back in to manage orders.',
      'fullName': 'Full name',
      'phone': 'Phone',
      'bodyMeasurements': 'Body measurements',
      'measurementsSubtitle': 'In inches. Leave blank if you’re not sure.',
      'notes': 'Notes',
      'notesHint': 'e.g. preferred fit, body type notes',
      'saveChanges': 'Save changes',
      'profileSaved': 'Profile saved.',
      'profileSaveFailed': 'Save failed.',
      'chest': 'Chest',
      'waist': 'Waist',
      'hips': 'Hips',
      'shoulder': 'Shoulder',
      'sleeve': 'Sleeve',
      'height': 'Height',

      // Customer Order Flow
      'newOrderTitle': 'New Order',
      'garmentType': 'Garment Type',
      'selectGarment': 'Select garment type',
      'fabricDescription': 'Fabric Description',
      'fabricDescHint': 'Describe the fabric (color, pattern, material, etc.)',
      'fabricPhoto': 'Fabric Photo',
      'stylePhoto': 'Style Reference Photo',
      'uploadPhoto': 'Upload photo',
      'deliveryDate': 'Desired Delivery Date',
      'specialInstructions': 'Special Instructions / Notes',
      'specialInstructionsHint':
          'Describe the cut, custom neck design, pockets, etc.',
      'submitOrder': 'Submit Order',
      'imageSourceTitle': 'Select Image Source',
      'camera': 'Camera',
      'gallery': 'Gallery',
      'orderSuccess': 'Order placed successfully!',
      'orderSuccessOffline':
          'Offline — Order queued. It will sync when online.',
      'orderLoadError': 'Could not load orders',
      'noOrdersYet': 'No orders yet',
      'placeFirstOrder': 'Place your first order',
      'noOrdersYetDesc':
          'Place your first order — pick a garment, share fabric details, and we’ll handle the rest.',
      'noFilterResults': 'Nothing matches this filter',
      'noFilterResultsDesc':
          'Try a different status filter to see more orders.',
      'addMeasurementsFirst': 'Please add your measurements in Profile first.',
      'profileMeasurementsWarning':
          'Add your measurements in Profile so the tailor knows your sizes.',
      'selectDate': 'Select a date',
      'choose': 'Choose',
      'fabricPhotoOptional': 'Fabric photo (optional)',
      'stylePhotoOptional': 'Style reference photo (optional)',
      'specialInstructionsOptional': 'Special instructions (optional)',
      'kurta': 'Kurta',
      'blouse': 'Blouse',
      'skirt': 'Skirt',
      'walkIn': 'Walk-in',
      'existing': 'Existing',
      'change': 'Change',
      'joined': 'Joined',
      'customerNotFound': 'Customer not found',
      'customerNotFoundDesc': 'This account may have been deleted.',
      'measurementsSaved': 'Measurements saved successfully',
      'orderHistory': 'Order History',
      'noOrdersCustomerDesc':
          'When this customer places an order — or you create one for them — it will appear here.',

      // Order Details
      'orderDetailTitle': 'Order Details',
      'status': 'Status',
      'price': 'Price',
      'notAssigned': 'Not assigned',
      'adminNotes': 'Admin Notes',
      'noAdminNotes': 'No notes from administration.',
      'statusHistory': 'Status History',
      'changedBy': 'Changed by',

      // Garment Types
      'dress': 'Dress',
      'suit': 'Suit',
      'abaya': 'Abaya',
      'shirt': 'Shirt',
      'trousers': 'Trousers',
      'custom': 'Custom',

      // Statuses
      'statusPending': 'Pending',
      'statusInProgress': 'In Progress',
      'statusCompleted': 'Completed',
      'statusCancelled': 'Cancelled',

      // Admin Dashboard
      'adminDashboard': 'Admin Dashboard',
      'totalOrders': 'Orders Today',
      'pendingCount': 'Pending',
      'inProgressCount': 'In Progress',
      'completedCount': 'Completed',
      'recentActivity': 'Recent Activity',
      'quickActions': 'Quick Actions',
      'addOrder': 'Add Order',
      'viewAllOrders': 'View All Orders',
      'viewCustomers': 'View Customers',

      // Admin Settings & Broadcast
      'broadcastNotification': 'Broadcast notification',
      'broadcastSubtitle': 'Send an in-app message to one or all customers.',
      'reportsExports': 'Reports & exports',
      'reportsSubtitle': 'Revenue, status breakdown, top garments. Export PDF.',
      'changePasswordSubtitle': 'Update the admin account password.',
      'sendBroadcast': 'Send Broadcast Notification',
      'notificationTitle': 'Notification Title',
      'notificationBody': 'Notification Message',
      'titleRequired': 'Title is required',
      'messageRequired': 'Message is required',
      'recipient': 'Recipient',
      'allCustomers': 'All customers',
      'specificCustomer': 'Specific customer',
      'selectRecipient': 'Select customer',
      'sendNotificationBtn': 'Send Notification',
      'notificationSentSuccess': 'Notification sent successfully',
      'inAppNotifications': 'In-App Notifications',
      'noNotificationsYet': 'No notifications yet',

      // Admin Order details actions
      'adminActions': 'Admin Actions',
      'updateStatus': 'Update Status',
      'assignPrice': 'Assign Price',
      'addAdminNotes': 'Add Admin Notes',
      'updateStatusTitle': 'Update Order Status',
      'selectStatus': 'Select status',
      'updateBtn': 'Update',
      'statusUpdatedSuccess': 'Order status updated successfully',
      'assignPriceTitle': 'Assign Price',
      'priceLabel': 'Price (\$)',
      'priceRequired': 'Price must be a valid number',
      'priceAssignedSuccess': 'Price assigned successfully',
      'addAdminNotesTitle': 'Add Admin Notes',
      'notesLabel': 'Notes',
      'notesSavedSuccess': 'Admin notes saved successfully',

      // Customer detail / manual walk-in
      'customerDetail': 'Customer Detail',
      'savedMeasurements': 'Saved Measurements',
      'editMeasurements': 'Edit measurements',
      'noMeasurementsSaved': 'No measurements saved yet.',
      'walkInOrder': 'Walk-in Order',
      'walkInSubtitle': 'Create order for a walk-in customer',
      'customer': 'Customer',
      'selectExistingCustomer': 'Select Existing Customer',
      'createNewCustomer': 'Create New Customer',
      'deliveryDateRequired': 'Please select a delivery date',
      'customerCreatedSuccess': 'Customer profile created',
      'walkInSuccess': 'Walk-in order created successfully!',
      'noCustomersFound': 'No customers found',
      'totalRevenue': 'Total Revenue',
      'ordersBreakdown': 'Orders by Status',
      'ordersOverTime': 'Orders Over Time',
      'mostOrderedGarmentsTitle': 'Most Ordered Garment Types',
      'pdfExported': 'Summary PDF exported successfully',
      'language': 'Language',
      'themeMode': 'Theme Mode',

      // Languages
      'english': 'English',
      'french': 'French',
      'systemTheme': 'System Default',
      'lightTheme': 'Light Mode',
      'darkTheme': 'Dark Mode',
      'customerName': 'Customer Name',
      'searchCustomer': 'Search by name or phone...',
      'walkInTitle': 'Walk-in Order',
      'clients': 'Clients',
      'products': 'Products',
      'staff': 'Staff',
      'finance': 'Finance',
      'readyToWear': 'Ready to Wear',
      'command': 'Orders',
      'appointments': 'Appointments',
      'history': 'History',
    },
    'fr': {
      // General
      'appName': 'Studio de Couture',
      'tagline': 'Commander. Suivre. Personnalisé.',
      'save': 'Enregistrer',
      'cancel': 'Annuler',
      'submit': 'Soumettre',
      'retry': 'Réessayer',
      'offlineBanner': 'Vous êtes hors ligne — affichage des données locales.',
      'somethingWentWrong': 'Une erreur est survenue.',
      'requiredField': 'Requis',
      'loading': 'Chargement...',
      'all': 'Tout',
      'search': 'Rechercher',
      'yes': 'Oui',
      'no': 'Non',

      // Validation
      'validationRequired': 'Ce champ est requis',
      'validationEmail': 'Entrez une adresse e-mail valide',
      'validationPassword':
          'Le mot de passe doit comporter au moins 6 caractères',
      'validationConfirmPassword': 'Les mots de passe ne correspondent pas',
      'validationPhone': 'Entrez un numéro de téléphone valide',
      'validationPositiveNumber': 'Entrez un nombre positif',

      // Onboarding
      'skip': 'Passer',
      'next': 'Suivant',
      'getStarted': 'Commencer',
      'alreadyHaveAccountOnb': 'J\'ai déjà un compte',
      'onbTitle1': 'Commander en quelques secondes',
      'onbDesc1':
          'Choisissez un vêtement, partagez des références de tissus et de styles, et commandez depuis votre téléphone.',
      'onbTitle2': 'Suivre chaque étape',
      'onbDesc2':
          'Suivez l\'évolution de votre commande de En attente à En cours puis Terminé en temps réel.',
      'onbTitle3': 'Ne ratez aucun retrait',
      'onbDesc3':
          'Soyez notifié dès que votre commande est prête — plus de devinettes ni d\'appels.',

      // Auth
      'login': 'Se connecter',
      'register': 'Créer un compte',
      'email': 'E-mail',
      'password': 'Mot de passe',
      'confirmPassword': 'Confirmer le mot de passe',
      'forgotPassword': 'Mot de passe oublié ?',
      'forgotPasswordSubtitle':
          'Entrez l\'e-mail associé à votre compte et nous vous enverrons un lien de réinitialisation.',
      'sendResetLink': 'Envoyer le lien de réinitialisation',
      'dontHaveAccount': 'Vous n\'avez pas de compte ?',
      'alreadyHaveAccount': 'Vous avez déjà un compte ?',
      'resetPassword': 'Réinitialiser le mot de passe',
      'resetEmailSent': 'E-mail de réinitialisation envoyé.',
      'signOut': 'Se déconnecter',
      'adminSetup': 'Configuration Administrateur',
      'adminSetupHint':
          'Configuration unique du compte du propriétaire de la boutique.',
      'welcomeBack': 'Bon retour',
      'signInSubtitle':
          'Connectez-vous pour suivre vos commandes et gérer vos vêtements.',
      'adminSetupTitle': 'Configurer le compte administrateur',
      'adminSetupBtn': 'Créer l\'administrateur & se connecter',
      'backToSignIn': 'Retour à la connexion',
      'changePassword': 'Changer le mot de passe',
      'oldPassword': 'Mot de passe actuel',
      'newPassword': 'Nouveau mot de passe',
      'passwordChangedSuccess': 'Mot de passe mis à jour avec succès.',
      'updatePasswordTitle': 'Mettre à jour votre mot de passe',
      'changePasswordSub':
          'Vous serez réauthentifié avant que le changement ne soit appliqué.',
      'confirmNewPassword': 'Confirmer le nouveau mot de passe',
      'updatePasswordBtn': 'Mettre à jour le mot de passe',
      'adminSetupReady': 'Le compte admin est prêt. Bienvenue !',
      'changePasswordPrompt':
          'Changez ce mot de passe immédiatement après votre première connexion.',

      // Navigation / Tabs
      'myOrders': 'Mes Commandes',
      'newOrder': 'Nouvelle Commande',
      'profile': 'Profil',
      'notifications': 'Notifications',
      'dashboard': 'Tableau de bord',
      'orders': 'Commandes',
      'customers': 'Clients',
      'reports': 'Rapports',
      'settings': 'Paramètres',

      // Customer Dashboard & Profile
      'signOutConfirmTitle': 'Se déconnecter ?',
      'signOutConfirmCustomer':
          'Vous devrez vous reconnecter pour voir vos commandes.',
      'signOutConfirmAdmin':
          'Vous devrez vous reconnecter pour gérer les commandes.',
      'fullName': 'Nom complet',
      'phone': 'Téléphone',
      'bodyMeasurements': 'Mesures corporelles',
      'measurementsSubtitle':
          'En pouces. Laissez vide si vous n\'êtes pas sûr.',
      'notes': 'Notes',
      'notesHint': 'ex: coupe préférée, notes sur la morphologie',
      'saveChanges': 'Enregistrer les modifications',
      'profileSaved': 'Profil enregistré.',
      'profileSaveFailed': 'Échec de l\'enregistrement.',
      'chest': 'Poitrine',
      'waist': 'Taille (ceinture)',
      'hips': 'Hanches',
      'shoulder': 'Épaules',
      'sleeve': 'Manche',
      'height': 'Hauteur',

      // Customer Order Flow
      'newOrderTitle': 'Nouvelle Commande',
      'garmentType': 'Type de vêtement',
      'selectGarment': 'Sélectionner le type',
      'fabricDescription': 'Description du tissu',
      'fabricDescHint': 'Décrivez le tissu (couleur, motif, matière, etc.)',
      'fabricPhoto': 'Photo du tissu',
      'stylePhoto': 'Photo de référence du style',
      'uploadPhoto': 'Télécharger la photo',
      'deliveryDate': 'Date de livraison souhaitée',
      'specialInstructions': 'Instructions spéciales / Notes',
      'specialInstructionsHint':
          'Décrivez la coupe, le col personnalisé, les poches, etc.',
      'submitOrder': 'Soumettre la commande',
      'imageSourceTitle': 'Sélectionner la source',
      'camera': 'Appareil photo',
      'gallery': 'Galerie',
      'orderSuccess': 'Commande passée avec succès !',
      'orderSuccessOffline':
          'Hors ligne — Commande en attente. Elle sera synchronisée dès la connexion rétablie.',
      'orderLoadError': 'Impossible de charger les commandes',
      'noOrdersYet': 'Aucune commande pour le moment',
      'placeFirstOrder': 'Passer votre première commande',
      'noOrdersYetDesc':
          'Passez votre première commande — choisissez un vêtement, partagez les détails du tissu, nous faisons le reste.',
      'noFilterResults': 'Aucun résultat pour ce filtre',
      'noFilterResultsDesc':
          'Essayez un autre filtre pour voir plus de commandes.',
      'addMeasurementsFirst':
          'Veuillez d\'abord ajouter vos mesures dans votre Profil.',
      'profileMeasurementsWarning':
          'Ajoutez vos mesures dans votre Profil pour que le tailleur connaisse vos tailles.',
      'selectDate': 'Choisir une date',
      'choose': 'Choisir',
      'fabricPhotoOptional': 'Photo du tissu (optionnel)',
      'stylePhotoOptional': 'Photo de référence du style (optionnel)',
      'specialInstructionsOptional': 'Instructions spéciales (optionnel)',
      'kurta': 'Kurta',
      'blouse': 'Chemisier',
      'skirt': 'Jupe',
      'walkIn': 'Sur place',
      'existing': 'Existant',
      'change': 'Changer',
      'joined': 'Inscrit le',
      'customerNotFound': 'Client introuvable',
      'customerNotFoundDesc': 'Ce compte a peut-être été supprimé.',
      'measurementsSaved': 'Mesures enregistrées avec succès',
      'orderHistory': 'Historique des commandes',
      'noOrdersCustomerDesc':
          'Lorsque ce client passera une commande — ou que vous en créerez une — elle apparaîtra ici.',

      // Order Details
      'orderDetailTitle': 'Détails de la commande',
      'status': 'Statut',
      'price': 'Prix',
      'notAssigned': 'Non assigné',
      'adminNotes': 'Notes de l\'administrateur',
      'noAdminNotes': 'Aucune note de l\'administration.',
      'statusHistory': 'Historique des statuts',
      'changedBy': 'Modifié par',

      // Garment Types
      'dress': 'Robe',
      'suit': 'Costume',
      'abaya': 'Abaya',
      'shirt': 'Chemise',
      'trousers': 'Pantalon',
      'custom': 'Sur mesure',

      // Statuses
      'statusPending': 'En attente',
      'statusInProgress': 'En cours',
      'statusCompleted': 'Terminé',
      'statusCancelled': 'Annulé',

      // Admin Dashboard
      'adminDashboard': 'Tableau de bord Admin',
      'totalOrders': 'Commandes aujourd\'hui',
      'pendingCount': 'En attente',
      'inProgressCount': 'En cours',
      'completedCount': 'Terminé',
      'recentActivity': 'Activité récente',
      'quickActions': 'Actions rapides',
      'addOrder': 'Ajouter commande',
      'viewAllOrders': 'Voir les commandes',
      'viewCustomers': 'Voir les clients',

      // Admin Settings & Broadcast
      'broadcastNotification': 'Diffuser une notification',
      'broadcastSubtitle': 'Envoyer un message à un ou tous les clients.',
      'reportsExports': 'Rapports & exports',
      'reportsSubtitle':
          'Chiffre d\'affaires, répartition, vêtements. Export PDF.',
      'changePasswordSubtitle': 'Modifier le mot de passe administrateur.',
      'sendBroadcast': 'Envoyer une notification générale',
      'notificationTitle': 'Titre de la notification',
      'notificationBody': 'Message de la notification',
      'titleRequired': 'Le titre est requis',
      'messageRequired': 'Le message est requis',
      'recipient': 'Destinataire',
      'allCustomers': 'Tous les clients',
      'specificCustomer': 'Client spécifique',
      'selectRecipient': 'Sélectionner un client',
      'sendNotificationBtn': 'Envoyer la notification',
      'notificationSentSuccess': 'Notification envoyée avec succès',
      'inAppNotifications': 'Notifications in-app',
      'noNotificationsYet': 'Aucune notification',

      // Admin Order details actions
      'adminActions': 'Actions Administrateur',
      'updateStatus': 'Modifier le statut',
      'assignPrice': 'Assigner un prix',
      'addAdminNotes': 'Ajouter des notes admin',
      'updateStatusTitle': 'Modifier le statut de la commande',
      'selectStatus': 'Sélectionner le statut',
      'updateBtn': 'Mettre à jour',
      'statusUpdatedSuccess': 'Statut mis à jour avec succès',
      'assignPriceTitle': 'Assigner un prix',
      'priceLabel': 'Prix (€)',
      'priceRequired': 'Le prix doit être un nombre valide',
      'priceAssignedSuccess': 'Prix assigné avec succès',
      'addAdminNotesTitle': 'Ajouter des notes admin',
      'notesLabel': 'Notes',
      'notesSavedSuccess': 'Notes enregistrées avec succès',

      // Customer detail / manual walk-in
      'customerDetail': 'Détail du client',
      'savedMeasurements': 'Mesures enregistrées',
      'editMeasurements': 'Modifier les mesures',
      'noMeasurementsSaved': 'Aucune mesure enregistrée.',
      'walkInOrder': 'Commande physique',
      'walkInSubtitle': 'Créer une commande sur place pour un client',
      'customer': 'Client',
      'selectExistingCustomer': 'Sélectionner un client existant',
      'createNewCustomer': 'Créer un nouveau client',
      'deliveryDateRequired': 'Veuillez choisir une date de livraison',
      'customerCreatedSuccess': 'Profil client créé',
      'walkInSuccess': 'Commande client créée avec succès !',
      'noCustomersFound': 'Aucun client trouvé',
      'totalRevenue': 'Revenu Total',
      'ordersBreakdown': 'Commandes par Statut',
      'ordersOverTime': 'Commandes au fil du temps',
      'mostOrderedGarmentsTitle': 'Types de vêtements les plus commandés',
      'pdfExported': 'PDF de synthèse exporté avec succès',
      'language': 'Langue',
      'themeMode': 'Mode de thème',

      // Languages
      'english': 'English',
      'french': 'Français',
      'systemTheme': 'Thème système',
      'lightTheme': 'Mode clair',
      'darkTheme': 'Mode sombre',
      'customerName': 'Nom du client',
      'searchCustomer': 'Rechercher par nom ou téléphone...',
      'walkInTitle': 'Commande client physique',
      'clients': 'Clients',
      'products': 'Produits',
      'staff': 'Personnel',
      'finance': 'Finance',
      'readyToWear': 'Prêt-à-porter',
      'command': 'Commandes',
      'appointments': 'Rendez-vous',
      'history': 'Historiques',
    }
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }

  // Getters
  String get appName => translate('appName');
  String get tagline => translate('tagline');
  String get save => translate('save');
  String get cancel => translate('cancel');
  String get submit => translate('submit');
  String get retry => translate('retry');
  String get offlineBanner => translate('offlineBanner');
  String get somethingWentWrong => translate('somethingWentWrong');
  String get requiredField => translate('requiredField');
  String get loading => translate('loading');
  String get all => translate('all');
  String get search => translate('search');
  String get yes => translate('yes');
  String get no => translate('no');

  // Validation
  String get validationRequired => translate('validationRequired');
  String get validationEmail => translate('validationEmail');
  String get validationPassword => translate('validationPassword');
  String get validationConfirmPassword =>
      translate('validationConfirmPassword');
  String get validationPhone => translate('validationPhone');
  String get validationPositiveNumber => translate('validationPositiveNumber');

  // Onboarding
  String get skip => translate('skip');
  String get next => translate('next');
  String get getStarted => translate('getStarted');
  String get alreadyHaveAccountOnb => translate('alreadyHaveAccountOnb');
  String get onbTitle1 => translate('onbTitle1');
  String get onbDesc1 => translate('onbDesc1');
  String get onbTitle2 => translate('onbTitle2');
  String get onbDesc2 => translate('onbDesc2');
  String get onbTitle3 => translate('onbTitle3');
  String get onbDesc3 => translate('onbDesc3');

  // Auth
  String get login => translate('login');
  String get register => translate('register');
  String get email => translate('email');
  String get password => translate('password');
  String get confirmPassword => translate('confirmPassword');
  String get forgotPassword => translate('forgotPassword');
  String get forgotPasswordSubtitle => translate('forgotPasswordSubtitle');
  String get sendResetLink => translate('sendResetLink');
  String get dontHaveAccount => translate('dontHaveAccount');
  String get alreadyHaveAccount => translate('alreadyHaveAccount');
  String get resetPassword => translate('resetPassword');
  String get resetEmailSent => translate('resetEmailSent');
  String get signOut => translate('signOut');
  String get adminSetup => translate('adminSetup');
  String get adminSetupHint => translate('adminSetupHint');
  String get welcomeBack => translate('welcomeBack');
  String get signInSubtitle => translate('signInSubtitle');
  String get adminSetupTitle => translate('adminSetupTitle');
  String get adminSetupBtn => translate('adminSetupBtn');
  String get backToSignIn => translate('backToSignIn');
  String get changePassword => translate('changePassword');
  String get oldPassword => translate('oldPassword');
  String get newPassword => translate('newPassword');
  String get passwordChangedSuccess => translate('passwordChangedSuccess');
  String get updatePasswordTitle => translate('updatePasswordTitle');
  String get changePasswordSub => translate('changePasswordSub');
  String get confirmNewPassword => translate('confirmNewPassword');
  String get updatePasswordBtn => translate('updatePasswordBtn');
  String get adminSetupReady => translate('adminSetupReady');
  String get changePasswordPrompt => translate('changePasswordPrompt');

  // Navigation / Tabs
  String get myOrders => translate('myOrders');
  String get newOrder => translate('newOrder');
  String get profile => translate('profile');
  String get notifications => translate('notifications');
  String get dashboard => translate('dashboard');
  String get orders => translate('orders');
  String get customers => translate('customers');
  String get reports => translate('reports');
  String get settings => translate('settings');

  // Customer Dashboard & Profile
  String get signOutConfirmTitle => translate('signOutConfirmTitle');
  String get signOutConfirmCustomer => translate('signOutConfirmCustomer');
  String get signOutConfirmAdmin => translate('signOutConfirmAdmin');
  String get fullName => translate('fullName');
  String get phone => translate('phone');
  String get bodyMeasurements => translate('bodyMeasurements');
  String get measurementsSubtitle => translate('measurementsSubtitle');
  String get notes => translate('notes');
  String get notesHint => translate('notesHint');
  String get saveChanges => translate('saveChanges');
  String get profileSaved => translate('profileSaved');
  String get profileSaveFailed => translate('profileSaveFailed');
  String get chest => translate('chest');
  String get waist => translate('waist');
  String get hips => translate('hips');
  String get shoulder => translate('shoulder');
  String get sleeve => translate('sleeve');
  String get height => translate('height');

  // Customer Order Flow
  String get newOrderTitle => translate('newOrderTitle');
  String get garmentType => translate('garmentType');
  String get selectGarment => translate('selectGarment');
  String get fabricDescription => translate('fabricDescription');
  String get fabricDescHint => translate('fabricDescHint');
  String get fabricPhoto => translate('fabricPhoto');
  String get stylePhoto => translate('stylePhoto');
  String get uploadPhoto => translate('uploadPhoto');
  String get deliveryDate => translate('deliveryDate');
  String get specialInstructions => translate('specialInstructions');
  String get specialInstructionsHint => translate('specialInstructionsHint');
  String get submitOrder => translate('submitOrder');
  String get imageSourceTitle => translate('imageSourceTitle');
  String get camera => translate('camera');
  String get gallery => translate('gallery');
  String get orderSuccess => translate('orderSuccess');
  String get orderSuccessOffline => translate('orderSuccessOffline');
  String get orderLoadError => translate('orderLoadError');
  String get noOrdersYet => translate('noOrdersYet');
  String get placeFirstOrder => translate('placeFirstOrder');
  String get noOrdersYetDesc => translate('noOrdersYetDesc');
  String get noFilterResults => translate('noFilterResults');
  String get noFilterResultsDesc => translate('noFilterResultsDesc');
  String get addMeasurementsFirst => translate('addMeasurementsFirst');
  String get profileMeasurementsWarning =>
      translate('profileMeasurementsWarning');
  String get selectDate => translate('selectDate');
  String get choose => translate('choose');
  String get fabricPhotoOptional => translate('fabricPhotoOptional');
  String get stylePhotoOptional => translate('stylePhotoOptional');
  String get specialInstructionsOptional =>
      translate('specialInstructionsOptional');
  String get kurta => translate('kurta');
  String get blouse => translate('blouse');
  String get skirt => translate('skirt');
  String get walkIn => translate('walkIn');
  String get existing => translate('existing');
  String get change => translate('change');
  String get joined => translate('joined');
  String get customerNotFound => translate('customerNotFound');
  String get customerNotFoundDesc => translate('customerNotFoundDesc');
  String get measurementsSaved => translate('measurementsSaved');
  String get orderHistory => translate('orderHistory');
  String get noOrdersCustomerDesc => translate('noOrdersCustomerDesc');

  String garmentName(String g) {
    switch (g.toLowerCase()) {
      case 'dress':
        return translate('dress');
      case 'suit':
        return translate('suit');
      case 'abaya':
        return translate('abaya');
      case 'shirt':
        return translate('shirt');
      case 'trousers':
        return translate('trousers');
      case 'custom':
        return translate('custom');
      case 'kurta':
        return translate('kurta');
      case 'blouse':
        return translate('blouse');
      case 'skirt':
        return translate('skirt');
      default:
        return g;
    }
  }

  // Order Details
  String get orderDetailTitle => translate('orderDetailTitle');
  String get status => translate('status');
  String get price => translate('price');
  String get notAssigned => translate('notAssigned');
  String get adminNotes => translate('adminNotes');
  String get noAdminNotes => translate('noAdminNotes');
  String get statusHistory => translate('statusHistory');
  String get changedBy => translate('changedBy');

  // Garment Types
  String get dress => translate('dress');
  String get suit => translate('suit');
  String get abaya => translate('abaya');
  String get shirt => translate('shirt');
  String get trousers => translate('trousers');
  String get custom => translate('custom');

  // Statuses
  String get statusPending => translate('statusPending');
  String get statusInProgress => translate('statusInProgress');
  String get statusCompleted => translate('statusCompleted');
  String get statusCancelled => translate('statusCancelled');

  // Admin Dashboard
  String get adminDashboard => translate('adminDashboard');
  String get totalOrders => translate('totalOrders');
  String get pendingCount => translate('pendingCount');
  String get inProgressCount => translate('inProgressCount');
  String get completedCount => translate('completedCount');
  String get recentActivity => translate('recentActivity');
  String get quickActions => translate('quickActions');
  String get addOrder => translate('addOrder');
  String get viewAllOrders => translate('viewAllOrders');
  String get viewCustomers => translate('viewCustomers');

  // Admin Settings & Broadcast
  String get broadcastNotification => translate('broadcastNotification');
  String get broadcastSubtitle => translate('broadcastSubtitle');
  String get reportsExports => translate('reportsExports');
  String get reportsSubtitle => translate('reportsSubtitle');
  String get changePasswordSubtitle => translate('changePasswordSubtitle');
  String get sendBroadcast => translate('sendBroadcast');
  String get notificationTitle => translate('notificationTitle');
  String get notificationBody => translate('notificationBody');
  String get titleRequired => translate('titleRequired');
  String get messageRequired => translate('messageRequired');
  String get recipient => translate('recipient');
  String get allCustomers => translate('allCustomers');
  String get specificCustomer => translate('specificCustomer');
  String get selectRecipient => translate('selectRecipient');
  String get sendNotificationBtn => translate('sendNotificationBtn');
  String get notificationSentSuccess => translate('notificationSentSuccess');
  String get inAppNotifications => translate('inAppNotifications');
  String get noNotificationsYet => translate('noNotificationsYet');

  // Admin Order details actions
  String get adminActions => translate('adminActions');
  String get updateStatus => translate('updateStatus');
  String get assignPrice => translate('assignPrice');
  String get addAdminNotes => translate('addAdminNotes');
  String get updateStatusTitle => translate('updateStatusTitle');
  String get selectStatus => translate('selectStatus');
  String get updateBtn => translate('updateBtn');
  String get statusUpdatedSuccess => translate('statusUpdatedSuccess');
  String get assignPriceTitle => translate('assignPriceTitle');
  String get priceLabel => translate('priceLabel');
  String get priceRequired => translate('priceRequired');
  String get priceAssignedSuccess => translate('priceAssignedSuccess');
  String get addAdminNotesTitle => translate('addAdminNotesTitle');
  String get notesLabel => translate('notesLabel');
  String get notesSavedSuccess => translate('notesSavedSuccess');

  // Customer detail / manual walk-in
  String get customerDetail => translate('customerDetail');
  String get savedMeasurements => translate('savedMeasurements');
  String get editMeasurements => translate('editMeasurements');
  String get noMeasurementsSaved => translate('noMeasurementsSaved');
  String get walkInOrder => translate('walkInOrder');
  String get walkInSubtitle => translate('walkInSubtitle');
  String get customer => translate('customer');
  String get selectExistingCustomer => translate('selectExistingCustomer');
  String get createNewCustomer => translate('createNewCustomer');
  String get deliveryDateRequired => translate('deliveryDateRequired');
  String get customerCreatedSuccess => translate('customerCreatedSuccess');
  String get walkInSuccess => translate('walkInSuccess');
  String get noCustomersFound => translate('noCustomersFound');
  String get totalRevenue => translate('totalRevenue');
  String get ordersBreakdown => translate('ordersBreakdown');
  String get ordersOverTime => translate('ordersOverTime');
  String get mostOrderedGarmentsTitle => translate('mostOrderedGarmentsTitle');
  String get pdfExported => translate('pdfExported');
  String get language => translate('language');
  String get themeMode => translate('themeMode');

  // Languages
  String get english => translate('english');
  String get french => translate('french');
  String get systemTheme => translate('systemTheme');
  String get lightTheme => translate('lightTheme');
  String get darkTheme => translate('darkTheme');
  String get customerName => translate('customerName');
  String get searchCustomer => translate('searchCustomer');
  String get walkInTitle => translate('walkInTitle');
  String get clients => translate('clients');
  String get products => translate('products');
  String get staff => translate('staff');
  String get finance => translate('finance');
  String get readyToWear => translate('readyToWear');
  String get command => translate('command');
  String get appointments => translate('appointments');
  String get history => translate('history');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'fr'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension LocalizationsContext on BuildContext {
  AppLocalizations get loc => AppLocalizations.of(this)!;
}
