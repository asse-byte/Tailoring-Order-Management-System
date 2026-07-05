import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/orders_repository.dart';
import '../../domain/entities/order.dart';

/// Customer-facing orders state. Subscribes to /orders where customerId == uid.
class CustomerOrdersProvider extends ChangeNotifier {
  CustomerOrdersProvider({
    required String customerId,
    OrdersRepository? repository,
  })  : _customerId = customerId,
        _repo = repository ?? OrdersRepository() {
    _start();
  }

  final String _customerId;
  final OrdersRepository _repo;

  StreamSubscription<List<TailoringOrder>>? _sub;

  List<TailoringOrder> _orders = <TailoringOrder>[];
  bool _loading = true;
  String? _error;

  List<TailoringOrder> get orders => _orders;
  bool get loading => _loading;
  String? get error => _error;

  void _start() {
    _sub = _repo.watchCustomerOrders(_customerId).listen(
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

  List<TailoringOrder> filterByStatus(String? status) {
    if (status == null || status.isEmpty) return _orders;
    return _orders.where((o) => o.status == status).toList(growable: false);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
