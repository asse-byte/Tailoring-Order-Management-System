import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../auth/domain/entities/app_user.dart';
import '../../data/customers_repository.dart';

/// Streams all registered customers (role == 'customer') for the admin view.
class AdminCustomersProvider extends ChangeNotifier {
  AdminCustomersProvider({CustomersRepository? repository})
      : _repo = repository ?? CustomersRepository() {
    _start();
  }

  final CustomersRepository _repo;
  StreamSubscription<List<AppUser>>? _sub;

  List<AppUser> _customers = <AppUser>[];
  bool _loading = true;
  String? _error;
  String _query = '';

  List<AppUser> get customers => _customers;
  bool get loading => _loading;
  String? get error => _error;
  String get query => _query;

  void _start() {
    _sub = _repo.watchCustomers().listen(
      (data) {
        // Sort by name (case-insensitive) for predictable order.
        final List<AppUser> sorted = <AppUser>[
          ...data
        ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        _customers = sorted;
        _loading = false;
        _error = null;
        notifyListeners();
      },
      onError: (Object e) {
        _error = e.toString();
        _loading = false;
        notifyListeners();
      },
    );
  }

  void setQuery(String q) {
    _query = q.trim().toLowerCase();
    notifyListeners();
  }

  List<AppUser> get filtered {
    if (_query.isEmpty) return _customers;
    return _customers
        .where((u) =>
            u.name.toLowerCase().contains(_query) ||
            u.phone.toLowerCase().contains(_query) ||
            u.email.toLowerCase().contains(_query))
        .toList(growable: false);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
