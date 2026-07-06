import '../../../../core/constants/app_constants.dart';

/// Represents a user document stored in /users/{uid}.
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.profilePhotoUrl,
    this.createdAt,
    this.fcmToken,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String role; // 'admin' (le Gérant) | 'secretary' (la Secrétaire)
  final String? profilePhotoUrl;
  final DateTime? createdAt;
  final String? fcmToken;

  bool get isAdmin => role == AppConstants.roleAdmin;
  bool get isSecretary => role == AppConstants.roleSecretary;

  AppUser copyWith({
    String? name,
    String? phone,
    String? profilePhotoUrl,
    String? fcmToken,
    String? role,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      email: email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      createdAt: createdAt,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'userId': id,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role,
        'profilePhotoUrl': profilePhotoUrl,
        'fcmToken': fcmToken,
        'createdAt': createdAt?.toIso8601String(),
      };

  /// From the REST API (`/api/auth/login`, `/api/auth/me`). Maps the
  /// server roles (MANAGER/SECRETARY) onto the app's constants.
  factory AppUser.fromApi(Map<String, dynamic> map) {
    final String apiRole = (map['role'] as String?) ?? '';
    return AppUser(
      id: map['id'] as String,
      name: (map['name'] as String?) ?? '',
      email: (map['username'] as String?) ?? '',
      phone: '',
      role: apiRole == 'MANAGER'
          ? AppConstants.roleAdmin
          : AppConstants.roleSecretary, // least privilege for anything else
    );
  }

  factory AppUser.fromMap(String id, Map<String, dynamic> map) {
    final dynamic ts = map['createdAt'];
    DateTime? created;
    if (ts is String) {
      created = DateTime.tryParse(ts);
    }

    return AppUser(
      id: id,
      name: (map['name'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      phone: (map['phone'] as String?) ?? '',
      // Least-privilege default: an unknown role never becomes admin.
      role: (map['role'] as String?) ?? AppConstants.roleSecretary,
      profilePhotoUrl: map['profilePhotoUrl'] as String?,
      createdAt: created,
      fcmToken: map['fcmToken'] as String?,
    );
  }
}
