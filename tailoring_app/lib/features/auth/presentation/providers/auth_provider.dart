import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../data/auth_repository.dart';
import '../../domain/entities/app_user.dart';

enum AuthStatus { uninitialized, authenticated, unauthenticated }

/// Centralised auth state for the whole app.
class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthRepository? repository})
      : _repo = repository ?? AuthRepository() {
    _sub = _repo.authStateChanges().listen(_onAuthChanged);
  }

  final AuthRepository _repo;
  StreamSubscription<User?>? _sub;

  AuthStatus _status = AuthStatus.uninitialized;
  AppUser? _user;
  bool _busy = false;
  String? _error;

  AuthStatus get status => _status;
  AppUser? get user => _user;
  bool get busy => _busy;
  String? get error => _error;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isAdmin => _user?.isAdmin ?? false;
  bool get isSecretary => _user?.isSecretary ?? false;

  Future<void> _onAuthChanged(User? fbUser) async {
    if (fbUser == null) {
      _user = null;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    try {
      final AppUser? profile = await _repo.fetchUser(fbUser.uid);
      _user = profile;
      _status = profile != null
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated;
    } catch (_) {
      _status = AuthStatus.unauthenticated;
      _user = null;
    }
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) async {
    _setBusy(true);
    try {
      _user = await _repo.signIn(email: email, password: password);
      _status = AuthStatus.authenticated;
      _error = null;
      return true;
    } on AuthFailure catch (e) {
      _error = e.message;
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<bool> seedAdmin() async {
    _setBusy(true);
    try {
      _user = await _repo.seedAdmin();
      _status = AuthStatus.authenticated;
      _error = null;
      return true;
    } on AuthFailure catch (e) {
      _error = e.message;
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<bool> sendPasswordReset(String email) async {
    _setBusy(true);
    try {
      await _repo.sendPasswordReset(email);
      _error = null;
      return true;
    } on AuthFailure catch (e) {
      _error = e.message;
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> signOut() async {
    await _repo.signOut();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
