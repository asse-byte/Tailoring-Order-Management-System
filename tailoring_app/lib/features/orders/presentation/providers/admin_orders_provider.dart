import 'package:flutter/foundation.dart';

import '../../data/orders_repository.dart';
import '../../domain/entities/order.dart';

/// Orders state shared by the list, history and detail screens.
/// Loads on demand (init / pull-to-refresh / after a mutation) — no
/// polling: the two operators work on the same counter.
class AdminOrdersProvider extends ChangeNotifier {
  AdminOrdersProvider({OrdersRepository? repository})
      : _repo = repository ?? OrdersRepository() {
    refresh();
  }

  final OrdersRepository _repo;

  List<TailoringOrder> _orders = <TailoringOrder>[];
  bool _loading = true;
  String? _error;

  // Filters (client-side, applied on the loaded page)
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

  Future<void> refresh() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _orders = await _repo.list(limit: 100);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
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
      final DateTime? ref = o.deliveredDate ?? o.createdAt;
      if (_from != null && ref != null && ref.isBefore(_from!)) return false;
      if (_to != null && ref != null) {
        final DateTime endOfDay =
            DateTime(_to!.year, _to!.month, _to!.day, 23, 59, 59);
        if (ref.isAfter(endOfDay)) return false;
      }
      if (_query.isNotEmpty) {
        final String hay =
            '${o.clientName} ${o.clientPhone} ${o.garmentType}'.toLowerCase();
        if (!hay.contains(_query)) return false;
      }
      return true;
    }).toList(growable: false);
  }
}
