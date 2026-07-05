import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/data/mock_database.dart';
import '../domain/entities/app_user.dart';

/// Auth-related failure with a user-friendly message.
class AuthFailure implements Exception {
  AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Repository wrapping FirebaseAuth + Firestore user documents.
class AuthRepository {
  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth,
        _firestore = firestore;

  final FirebaseAuth? _auth;
  final FirebaseFirestore? _firestore;

  FirebaseAuth get auth => _auth ?? FirebaseAuth.instance;
  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      firestore.collection(AppConstants.usersCollection);

  // ---- Streams / getters ----

  Stream<User?> authStateChanges() {
    if (MockDatabase.useMock) {
      return MockDatabase.instance.authStateChangesStream;
    }
    return auth.authStateChanges();
  }

  User? get currentFirebaseUser {
    if (MockDatabase.useMock) {
      final user = MockDatabase.instance.currentUser;
      return user == null ? null : MockUser(user.id, user.email);
    }
    return auth.currentUser;
  }

  /// Fetch the user profile document for the given uid.
  Future<AppUser?> fetchUser(String uid) async {
    if (MockDatabase.useMock) {
      return MockDatabase.instance.getCustomer(uid) ?? 
          (uid == 'admin_uid' ? await MockDatabase.instance.seedAdmin() : null);
    }
    final DocumentSnapshot<Map<String, dynamic>> doc =
        await _usersRef.doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromMap(doc.id, doc.data()!);
  }

  // ---- Sign in ----

  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    if (MockDatabase.useMock) {
      try {
        return await MockDatabase.instance.signIn(email, password);
      } catch (e) {
        throw AuthFailure(e.toString().replaceAll('Exception: ', ''));
      }
    }
    try {
      final UserCredential cred = await auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final String uid = cred.user!.uid;
      final AppUser? profile = await fetchUser(uid);
      if (profile == null) {
        throw AuthFailure(
          'No profile found for this account. Please contact support.',
        );
      }
      return profile;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_mapAuthError(e));
    }
  }

  // ---- One-time admin seed ----

  /// Creates the seed admin user. Idempotent: if the email already exists
  /// it just signs in with the seed credentials and ensures the Firestore
  /// doc has role=admin.
  Future<AppUser> seedAdmin() async {
    if (MockDatabase.useMock) {
      return MockDatabase.instance.seedAdmin();
    }
    const String email = AppConstants.seedAdminEmail;
    const String password = AppConstants.seedAdminPassword;
    const String name = AppConstants.seedAdminName;

    try {
      final UserCredential cred = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final String uid = cred.user!.uid;
      await cred.user!.updateDisplayName(name);

      final AppUser admin = AppUser(
        id: uid,
        name: name,
        email: email,
        phone: '',
        role: AppConstants.roleAdmin,
      );
      await _usersRef.doc(uid).set(admin.toMap());
      return admin;
    } on FirebaseAuthException catch (e) {
      // Already created — sign in instead and reconcile the Firestore doc.
      if (e.code == 'email-already-in-use') {
        final UserCredential cred = await auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        final String uid = cred.user!.uid;
        AppUser? existing = await fetchUser(uid);
        existing ??= AppUser(
          id: uid,
          name: name,
          email: email,
          phone: '',
          role: AppConstants.roleAdmin,
        );
        if (existing.role != AppConstants.roleAdmin) {
          existing = existing.copyWith(role: AppConstants.roleAdmin);
        }
        await _usersRef.doc(uid).set(existing.toMap(), SetOptions(merge: true));
        return existing;
      }
      throw AuthFailure(_mapAuthError(e));
    }
  }

  // ---- Password reset / sign out / token ----

  Future<void> sendPasswordReset(String email) async {
    if (MockDatabase.useMock) {
      return;
    }
    try {
      await auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_mapAuthError(e));
    }
  }

  Future<void> signOut() async {
    if (MockDatabase.useMock) {
      MockDatabase.instance.currentUser = null;
      return;
    }
    await auth.signOut();
  }

  Future<void> updateFcmToken(String uid, String token) async {
    if (MockDatabase.useMock) {
      return;
    }
    await _usersRef.doc(uid).set(
      <String, dynamic>{'fcmToken': token},
      SetOptions(merge: true),
    );
  }

  /// Reauthenticates with the current password, then updates to a new one.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (MockDatabase.useMock) {
      try {
        await MockDatabase.instance.changePassword(currentPassword, newPassword);
        return;
      } catch (e) {
        throw AuthFailure(e.toString().replaceAll('Exception: ', ''));
      }
    }
    final User? user = auth.currentUser;
    if (user == null || user.email == null) {
      throw AuthFailure('You must be signed in to change your password.');
    }
    try {
      final AuthCredential cred = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_mapAuthError(e));
    }
  }

  // ---- Helpers ----

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Please choose a stronger password (at least 6 characters).';
      case 'too-many-requests':
        return 'Too many attempts. Please try again in a moment.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}
