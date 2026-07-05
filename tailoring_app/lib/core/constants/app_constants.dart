/// App-wide constants (collection names, hardcoded admin creds, etc.).
class AppConstants {
  AppConstants._();

  // Firestore collections
  static const String usersCollection = 'users';
  static const String measurementsCollection = 'measurements';
  static const String ordersCollection = 'orders';
  static const String notificationsCollection = 'notifications';

  // Firebase Storage paths
  static const String profilePhotosPath = 'profile_photos';
  static const String fabricPhotosPath = 'fabric_photos';
  static const String stylePhotosPath = 'style_photos';

  // SQLite
  static const String localDbName = 'tailoring_app.db';
  static const int localDbVersion = 1;

  // Roles
  static const String roleCustomer = 'customer';
  static const String roleAdmin = 'admin';
  static const String roleSecretary = 'secretary';

  // Order status keys (Firestore-stored values)
  static const String statusPending = 'pending';
  static const String statusInProgress = 'in_progress';
  static const String statusCompleted = 'completed';
  static const String statusCancelled = 'cancelled';

  // -------- Initial admin seed (used by the one-time Admin Setup screen) --------
  // After first login the admin should change these from the Settings screen.
  static const String seedAdminEmail = 'admin@tailor.app';
  static const String seedAdminPassword = 'Admin@1234';
  static const String seedAdminName = 'Shop Admin';

  // Onboarding flag
  static const String prefsKeyOnboardingDone = 'onboarding_done';
  static const String prefsKeyAdminSeeded = 'admin_seeded';

  // Notifications channel
  static const String fcmChannelId = 'tailoring_orders_channel';
  static const String fcmChannelName = 'Tailoring Orders';
  static const String fcmChannelDescription =
      'Notifications about your tailoring orders and shop announcements.';
}
