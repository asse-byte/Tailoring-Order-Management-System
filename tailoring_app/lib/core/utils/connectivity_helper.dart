import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Tiny wrapper around `connectivity_plus` so the rest of the app can
/// listen via a single ValueNotifier and use a simple `isOnline` getter.
class ConnectivityHelper {
  ConnectivityHelper._internal();
  static final ConnectivityHelper instance = ConnectivityHelper._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;

  final ValueNotifier<bool> online = ValueNotifier<bool>(true);

  Future<void> init() async {
    final List<ConnectivityResult> initial =
        await _connectivity.checkConnectivity();
    online.value = _isOnline(initial);

    _sub ??= _connectivity.onConnectivityChanged.listen((results) {
      online.value = _isOnline(results);
    });
  }

  bool _isOnline(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }

  bool get isOnline => online.value;

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }
}
