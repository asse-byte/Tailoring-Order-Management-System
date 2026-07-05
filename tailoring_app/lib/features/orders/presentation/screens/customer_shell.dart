import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../customers/presentation/providers/customer_profile_provider.dart';
import '../../../customers/presentation/screens/customer_profile_screen.dart';
import '../../../notifications/data/fcm_service.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../../notifications/presentation/screens/customer_notifications_screen.dart';
import '../providers/customer_orders_provider.dart';
import '../providers/customer_tab_controller.dart';
import 'my_orders_screen.dart';
import 'place_order_screen.dart';

class CustomerShell extends StatelessWidget {
  const CustomerShell({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<CustomerOrdersProvider>(
          create: (_) => CustomerOrdersProvider(customerId: user.id),
        ),
        ChangeNotifierProvider<CustomerProfileProvider>(
          create: (_) => CustomerProfileProvider(userId: user.id),
        ),
        ChangeNotifierProvider<CustomerTabController>(
          create: (_) => CustomerTabController(),
        ),
        // Owns the unread badge counter; the Alerts screen creates its own
        // local provider for the list to keep things self-contained.
        ChangeNotifierProvider<NotificationsProvider>(
          create: (_) => NotificationsProvider(userId: user.id),
        ),
      ],
      child: const _CustomerShellBody(),
    );
  }
}

class _CustomerShellBody extends StatefulWidget {
  const _CustomerShellBody();

  @override
  State<_CustomerShellBody> createState() => _CustomerShellBodyState();
}

class _CustomerShellBodyState extends State<_CustomerShellBody> {
  @override
  void initState() {
    super.initState();
    FcmService.instance.tappedMessage.addListener(_onTap);
  }

  @override
  void dispose() {
    FcmService.instance.tappedMessage.removeListener(_onTap);
    super.dispose();
  }

  void _onTap() {
    final RemoteMessage? m = FcmService.instance.tappedMessage.value;
    final String? orderId = m?.data['orderId'] as String?;
    if (orderId != null && mounted) {
      // Switch to Alerts tab and open the order detail.
      context.read<CustomerTabController>().goTo(2);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/customer/order/$orderId');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tab = context.watch<CustomerTabController>();
    final notifs = context.watch<NotificationsProvider>();
    return Scaffold(
      body: IndexedStack(
        index: tab.index,
        children: const <Widget>[
          MyOrdersScreen(),
          PlaceOrderScreen(),
          CustomerNotificationsScreen(),
          CustomerProfileScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: tab.index,
        onTap: tab.goTo,
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: const Icon(Icons.receipt_long_outlined),
            activeIcon: const Icon(Icons.receipt_long),
            label: context.loc.orders,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.add_box_outlined),
            activeIcon: const Icon(Icons.add_box),
            label: context.loc.newOrder,
          ),
          BottomNavigationBarItem(
            icon: _UnreadBadge(
              count: notifs.unreadCount,
              child: const Icon(Icons.notifications_none_rounded),
            ),
            activeIcon: _UnreadBadge(
              count: notifs.unreadCount,
              child: const Icon(Icons.notifications_rounded),
            ),
            label: context.loc.notifications,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline_rounded),
            activeIcon: const Icon(Icons.person_rounded),
            label: context.loc.profile,
          ),
        ],
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count, required this.child});
  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        child,
        Positioned(
          right: -6,
          top: -2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFD23B3B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white, width: 1.4),
            ),
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            child: Text(
              count > 99 ? '99+' : '$count',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
