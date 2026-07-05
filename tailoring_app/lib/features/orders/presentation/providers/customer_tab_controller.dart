import 'package:flutter/foundation.dart';

/// Lightweight controller so the Orders/New tabs can request a jump
/// (e.g. FAB → switch to "New" tab, submit → switch back to "Orders").
class CustomerTabController extends ChangeNotifier {
  int _index = 0;
  int get index => _index;

  void goTo(int i) {
    if (i == _index) return;
    _index = i;
    notifyListeners();
  }
}
