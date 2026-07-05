import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/notifications_repository.dart';
import '../../domain/entities/app_notification.dart';

class NotificationsProvider extends ChangeNotifier {
  NotificationsProvider({
    required String userId,
    NotificationsRepository? repository,
  })  : _uid = userId,
        _repo = repository ?? NotificationsRepository() {
    _start();
  }

  final String _uid;
  final NotificationsRepository _repo;

  StreamSubscription<List<AppNotification>>? _sub;
  List<AppNotification> _items = <AppNotification>[];
  bool _loading = true;
  String? _error;

  List<AppNotification> get items => _items;
  bool get loading => _loading;
  String? get error => _error;
  int get unreadCount => _items.where((n) => !n.isRead).length;

  void _start() {
    _sub = _repo.watchForUser(_uid).listen(
      (data) {
        _items = data;
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

  Future<void> markRead(String id) => _repo.markRead(id);
  Future<void> markAllRead() => _repo.markAllRead(_uid);
  Future<void> delete(String id) => _repo.delete(id);

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
