import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/constants/app_constants.dart';
import '../../data/orders_repository.dart';
import '../../domain/entities/order.dart';

/// Admin-facing orders state. Streams ALL orders (admin Firestore rules required).
class AdminOrdersProvider extends ChangeNotifier {
  AdminOrdersProvider({OrdersRepository? repository})
      : _repo = repository ?? OrdersRepository() {
    _start();
  }

  final OrdersRepository _repo;
  StreamSubscription<List<TailoringOrder>>? _sub;

  List<TailoringOrder> _orders = <TailoringOrder>[];
  bool _loading = true;
  String? _error;

  // Filters
  String? _statusFilter;
  DateTime? _from;
  DateTime? _to;
  String _query = '';

  List<TailoringOrder> get orders => _orders;
  bool get loading => _loading;
  String? get error => _error;
  String? get statusFilter => _statusFilter;
  DateTime? get from => _from;
  DateTime? get to => _to;
  String get query => _query;

  void _start() {
    _sub = _repo.watchAllOrders().listen(
      (data) {
        _orders = data;
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

  // ---------- Filters ----------

  void setStatusFilter(String? status) {
    _statusFilter = status;
    notifyListeners();
  }

  void setDateRange(DateTime? from, DateTime? to) {
    _from = from;
    _to = to;
    notifyListeners();
  }

  void setQuery(String value) {
    _query = value.trim().toLowerCase();
    notifyListeners();
  }

  void clearFilters() {
    _statusFilter = null;
    _from = null;
    _to = null;
    _query = '';
    notifyListeners();
  }

  List<TailoringOrder> get filtered {
    return _orders.where((o) {
      if (_statusFilter != null && o.status != _statusFilter) return false;
      if (_from != null &&
          o.createdAt != null &&
          o.createdAt!.isBefore(_from!)) {
        return false;
      }
      if (_to != null && o.createdAt != null) {
        final DateTime endOfDay =
            DateTime(_to!.year, _to!.month, _to!.day, 23, 59, 59);
        if (o.createdAt!.isAfter(endOfDay)) return false;
      }
      if (_query.isNotEmpty) {
        final String hay =
            '${o.customerName} ${o.id} ${o.garmentType}'.toLowerCase();
        if (!hay.contains(_query)) return false;
      }
      return true;
    }).toList(growable: false);
  }

  // ---------- Dashboard helpers ----------

  int get totalToday {
    final DateTime now = DateTime.now();
    final DateTime start = DateTime(now.year, now.month, now.day);
    return _orders.where((o) {
      return o.createdAt != null && o.createdAt!.isAfter(start);
    }).length;
  }

  int countByStatus(String status) =>
      _orders.where((o) => o.status == status).length;

  int get pendingCount => countByStatus(AppConstants.statusPending);
  int get inProgressCount => countByStatus(AppConstants.statusInProgress);
  int get completedCount => countByStatus(AppConstants.statusCompleted);
  int get cancelledCount => countByStatus(AppConstants.statusCancelled);

  /// Recent N orders sorted by `updatedAt` (falls back to createdAt).
  List<TailoringOrder> recent({int limit = 5}) {
    final List<TailoringOrder> sorted = <TailoringOrder>[..._orders]
      ..sort((a, b) {
        final DateTime aT = a.updatedAt ?? a.createdAt ?? DateTime(1970);
        final DateTime bT = b.updatedAt ?? b.createdAt ?? DateTime(1970);
        return bT.compareTo(aT);
      });
    return sorted.take(limit).toList(growable: false);
  }

  /// Total revenue from completed orders.
  double get totalRevenue {
    double sum = 0;
    for (final o in _orders) {
      if (o.status == AppConstants.statusCompleted && o.price != null) {
        sum += o.price!;
      }
    }
    return sum;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
