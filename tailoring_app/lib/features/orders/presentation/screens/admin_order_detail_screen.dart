import 'package:flutter/material.dart';

import '../../domain/entities/order.dart';
import '../widgets/admin_order_actions.dart';
import 'order_detail_screen.dart';

/// Admin-side order detail = shared OrderDetailScreen + admin action panel.
class AdminOrderDetailScreen extends StatelessWidget {
  const AdminOrderDetailScreen({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context) {
    return OrderDetailScreen(
      orderId: orderId,
      adminActions: (BuildContext c, TailoringOrder o) =>
          AdminOrderActions(order: o),
    );
  }
}
