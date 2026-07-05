/// Centralised user-facing strings. Structured for future i18n extension.
class AppStrings {
  AppStrings._();

  // App
  static const String appName = 'RAYAN COUTURE';
  static const String tagline = 'Order. Track. Tailored.';

  // Auth
  static const String login = 'Sign in';
  static const String register = 'Create account';
  static const String email = 'Email';
  static const String password = 'Password';
  static const String confirmPassword = 'Confirm password';
  static const String forgotPassword = 'Forgot password?';
  static const String dontHaveAccount = "Don't have an account?";
  static const String alreadyHaveAccount = 'Already have an account?';
  static const String resetPassword = 'Reset password';
  static const String resetEmailSent = 'Password reset email sent.';
  static const String signOut = 'Sign out';
  static const String adminSetup = 'Admin Setup';
  static const String adminSetupHint =
      'One-time seed of the shop owner account.';

  // Order statuses (display)
  static const String statusPending = 'Pending';
  static const String statusInProgress = 'In Progress';
  static const String statusCompleted = 'Completed';
  static const String statusCancelled = 'Cancelled';

  // Generic
  static const String save = 'Save';
  static const String cancel = 'Cancel';
  static const String submit = 'Submit';
  static const String retry = 'Retry';
  static const String offlineBanner = 'You are offline — showing cached data.';
  static const String somethingWentWrong = 'Something went wrong.';
  static const String requiredField = 'Required';

  // Customer
  static const String myOrders = 'My Orders';
  static const String newOrder = 'New Order';
  static const String profile = 'Profile';
  static const String notifications = 'Notifications';

  // Admin
  static const String dashboard = 'Dashboard';
  static const String orders = 'Orders';
  static const String customers = 'Customers';
  static const String reports = 'Reports';
  static const String settings = 'Settings';
}
