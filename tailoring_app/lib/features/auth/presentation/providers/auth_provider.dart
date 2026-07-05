import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';
import '../../data/auth_repository.dart';
import '../../domain/entities/app_user.dart';

enum AuthStatus { uninitialized, authenticated, unauthenticated }

/// Centralised auth state: restores the JWT session on boot, exposes the
/// role (read from the server, never from local guesses) to the router
/// and the home grid (Finances is absent for the secretary).
class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthRepository? repository})
      : _repo = repository ?? AuthRepository() {
    // A 401 anywhere in the app drops the session → router goes to /login.
    ApiClient.instance.onSessionExpired = _onSessionExpired;
    _restore();
  }

  final AuthRepository _repo;

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

  Future<void> _restore() async {
    try {
      _user = await _repo.restoreSession();
      _status =
          _user != null ? AuthStatus.authenticated : AuthStatus.unauthenticated;
    } catch (_) {
      // Server unreachable at boot: fall back to login (it will show the
      // connection error on submit).
      _user = null;
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  void _onSessionExpired() {
    if (_status == AuthStatus.authenticated) {
      _user = null;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  Future<bool> signIn(String username, String password) async {
    _setBusy(true);
    try {
      _user = await _repo.signIn(username: username, password: password);
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
}
