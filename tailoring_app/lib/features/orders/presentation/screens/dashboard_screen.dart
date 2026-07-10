import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../features/settings/presentation/providers/shop_settings_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/network/api_client.dart';

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
      if (!isSec)
        _DashboardItem(
          title: context.loc.settings,
          icon: Icons.settings_rounded,
          color: const Color(0xFF4895EF),
          route: '/admin/settings',
        ),
    ];

    final shopSettings = context.watch<ShopSettingsProvider>();
    final shopName = shopSettings.shopName;
    final logoUrl = shopSettings.logoUrl;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Row(
          children: [
            Container(
              height: 32,
              width: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300, width: 1.5),
              ),
              child: ClipOval(
                child: logoUrl != null
                    ? CachedNetworkImage(
                        imageUrl: '${ApiClient.baseUrl}$logoUrl',
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Image.asset('assets/logo.jpeg', fit: BoxFit.cover),
                      )
                    : Image.asset('assets/logo.jpeg', fit: BoxFit.cover),
              ),
            ),
            Expanded(
              child: Text(
                shopName,
                style: const TextStyle(fontWeight: FontWeight.w900),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary.withValues(alpha: 0.10),
              AppColors.background,
              AppColors.background,
            ],
            stops: const [0.0, 0.35, 1.0],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Responsive: keep tiles ~compact (~170px) on any screen, and
              // cap content width on large desktops so it never stretches ugly.
              final double maxW = constraints.maxWidth;
              final int columns = maxW >= 1100
                  ? 5
                  : maxW >= 850
                      ? 4
                      : maxW >= 600
                          ? 3
                          : 2;
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${context.loc.welcomeBack}, ${auth.user?.name ?? ""}',
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isSec ? 'Secretary Dashboard' : 'Administrator Dashboard',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.05,
                          ),
                          itemCount: allItems.length,
                          itemBuilder: (context, index) {
                            return _DashboardCard(item: allItems[index]);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
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
      elevation: 0,
      shadowColor: item.color.withValues(alpha: 0.18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: item.color.withValues(alpha: 0.18)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(item.route),
        splashColor: item.color.withValues(alpha: 0.1),
        highlightColor: item.color.withValues(alpha: 0.04),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                item.color.withValues(alpha: 0.10),
                item.color.withValues(alpha: 0.02),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: item.color, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
