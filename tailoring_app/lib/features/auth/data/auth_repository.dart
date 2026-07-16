import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../domain/entities/app_user.dart';

/// Auth-related failure with a user-friendly (French) message.
class AuthFailure implements Exception {
  AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// REST-backed auth: JWT in secure storage, role always taken from the
/// server response (which itself reads it from the database).
class AuthRepository {
  AuthRepository({ApiClient? client}) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  Future<AppUser> signIn({
    required String username,
    required String password,
  }) async {
    try {
      final dynamic res = await _api.post('/api/auth/login', body: {
        'username': username.trim(),
        'password': password,
      });
      await _api.setToken(res['token'] as String);
      return AppUser.fromApi(res['user'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  /// Restores the session from the stored token; null if none/expired.
  Future<AppUser?> restoreSession() async {
    if (await _api.token == null) return null;
    try {
      final dynamic res = await _api.get('/api/auth/me');
      return AppUser.fromApi(res['user'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 401) return null;
      rethrow; // network error: caller decides (keeps splash logic simple)
    }
  }

  Future<void> signOut() => _api.setToken(null);

  Future<void> changePassword({
    required String currentPassword,
    String? newPassword,
    String? newUsername,
  }) async {
    try {
      await _api.post('/api/auth/change-password', body: {
        'current_password': currentPassword,
        if (newPassword != null && newPassword.isNotEmpty) 'new_password': newPassword,
        if (newUsername != null && newUsername.isNotEmpty) 'new_username': newUsername,
      });
    } on ApiException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  /// FCM is disabled until push is re-introduced on the REST backend.
  Future<void> updateFcmToken(String uid, String token) async {}

  /// Kept for AppConstants compatibility — roles come from the server.
  static String normalizeRole(String apiRole) {
    switch (apiRole) {
      case 'MANAGER':
        return AppConstants.roleAdmin;
      case 'SECRETARY':
        return AppConstants.roleSecretary;
      default:
        return AppConstants.roleSecretary; // least privilege
    }
  }
}
