import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../auth/domain/entities/app_user.dart';
import '../../data/customers_repository.dart';
import '../../domain/entities/measurements.dart';

/// Owns the current user's profile + measurements stream.
class CustomerProfileProvider extends ChangeNotifier {
  CustomerProfileProvider({
    required String userId,
    CustomersRepository? repository,
  })  : _uid = userId,
        _repo = repository ?? CustomersRepository() {
    _start();
  }

  final String _uid;
  final CustomersRepository _repo;

  StreamSubscription<AppUser?>? _userSub;
  StreamSubscription<Measurements>? _mSub;

  AppUser? _user;
  Measurements _measurements = Measurements.empty('');
  bool _loading = true;
  bool _saving = false;
  String? _error;

  AppUser? get user => _user;
  Measurements get measurements => _measurements;
  bool get loading => _loading;
  bool get saving => _saving;
  String? get error => _error;

  void _start() {
    _measurements = Measurements.empty(_uid);
    _userSub = _repo.watchUser(_uid).listen((u) {
      _user = u;
      _loading = false;
      notifyListeners();
    });
    _mSub = _repo.watchMeasurements(_uid).listen((m) {
      _measurements = m;
      notifyListeners();
    });
  }

  Future<bool> saveProfile({
    required String name,
    required String phone,
    File? newPhoto,
  }) async {
    _setSaving(true);
    try {
      String? url;
      if (newPhoto != null) {
        url = await _repo.uploadProfilePhoto(uid: _uid, file: newPhoto);
      }
      await _repo.updateProfile(
        uid: _uid,
        name: name,
        phone: phone,
        profilePhotoUrl: url,
      );
      _error = null;
      return true;
    } catch (e) {
      _error = 'Could not save profile: $e';
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> saveMeasurements(Measurements m) async {
    _setSaving(true);
    try {
      await _repo.saveMeasurements(m);
      _error = null;
      return true;
    } catch (e) {
      _error = 'Could not save measurements: $e';
      return false;
    } finally {
      _setSaving(false);
    }
  }

  void _setSaving(bool v) {
    _saving = v;
    notifyListeners();
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _mSub?.cancel();
    super.dispose();
  }
}
