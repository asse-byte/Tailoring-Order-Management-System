import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isSec = auth.isSecretary;

    // Define items list. Each item has title, icon, color, route.
    final List<_DashboardItem> allItems = [
      _DashboardItem(
        title: context.loc.clients,
        icon: Icons.people_rounded,
        color: const Color(0xFF6C63FF),
        route: '/admin/customers',
      ),
      _DashboardItem(
        title: context.loc.products,
        icon: Icons.shopping_bag_rounded,
        color: const Color(0xFFFF6584),
        route: '/admin/products',
      ),
      _DashboardItem(
        title: context.loc.staff,
        icon: Icons.badge_rounded,
        color: const Color(0xFF4E9F3D),
        route: '/admin/staff',
      ),
      if (!isSec)
        _DashboardItem(
          title: context.loc.finance,
          icon: Icons.account_balance_wallet_rounded,
          color: const Color(0xFFFFB319),
          route: '/admin/finance',
        ),
      _DashboardItem(
        title: context.loc.readyToWear,
        icon: Icons.checkroom_rounded,
        color: const Color(0xFF00B4D8),
        route: '/admin/ready-to-wear',
      ),
      _DashboardItem(
        title: context.loc.command,
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFF7209B7),
        route: '/admin/orders',
      ),
      _DashboardItem(
        title: context.loc.appointments,
        icon: Icons.event_rounded,
        color: const Color(0xFFF72585),
        route: '/admin/appointments',
      ),
      _DashboardItem(
        title: context.loc.history,
        icon: Icons.history_rounded,
        color: const Color(0xFF3F37C9),
        route: '/admin/history',
      ),
      _DashboardItem(
        title: context.loc.settings,
        icon: Icons.settings_rounded,
        color: const Color(0xFF4895EF),
        route: '/admin/settings',
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Couture Mali',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () {
              context.read<AuthProvider>().signOut();
            },
          )
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${context.loc.welcomeBack}, ${auth.user?.name ?? ""}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isSec ? 'Secretary Dashboard' : 'Administrator Dashboard',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.15,
                ),
                itemCount: allItems.length,
                itemBuilder: (context, index) {
                  final item = allItems[index];
                  return _DashboardCard(item: item);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardItem {
  final String title;
  final IconData icon;
  final Color color;
  final String route;

  const _DashboardItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.route,
  });
}

class _DashboardCard extends StatelessWidget {
  final _DashboardItem item;

  const _DashboardCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shadowColor: item.color.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(item.route),
        splashColor: item.color.withOpacity(0.1),
        highlightColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                item.color.withOpacity(0.08),
                item.color.withOpacity(0.02),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  item.icon,
                  color: item.color,
                  size: 28,
                ),
              ),
              Text(
                item.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
