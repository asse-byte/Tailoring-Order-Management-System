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

    // Unified brand identity: every tile shares the same Deep Teal look so the
    // grid reads as one elegant system. Only the icon distinguishes a module.
    // Owner-requested tile order:
    // client · command · rendez-vous · tailleurs · staff · finance ·
    // pret-à-porter · produits · historique · paramètres.
    final List<_DashboardItem> allItems = [
      _DashboardItem(
        title: context.loc.clients,
        icon: Icons.people_rounded,
        route: '/admin/customers',
      ),
      _DashboardItem(
        title: context.loc.command,
        icon: Icons.receipt_long_rounded,
        route: '/admin/orders',
      ),
      _DashboardItem(
        title: context.loc.appointments,
        icon: Icons.event_rounded,
        route: '/admin/appointments',
      ),
      const _DashboardItem(
        title: 'Tailleurs',
        icon: Icons.content_cut_rounded,
        route: '/admin/staff',
      ),
      if (!isSec)
        const _DashboardItem(
          title: 'Staff',
          icon: Icons.badge_rounded,
          route: '/admin/monthly-staff',
        ),
      if (!isSec)
        _DashboardItem(
          title: context.loc.finance,
          icon: Icons.account_balance_wallet_rounded,
          route: '/admin/finance',
        ),
      _DashboardItem(
        title: context.loc.readyToWear,
        icon: Icons.checkroom_rounded,
        route: '/admin/ready-to-wear',
      ),
      _DashboardItem(
        title: context.loc.products,
        icon: Icons.shopping_bag_rounded,
        route: '/admin/products',
      ),
      _DashboardItem(
        title: context.loc.history,
        icon: Icons.history_rounded,
        route: '/admin/history',
      ),
      if (!isSec)
        _DashboardItem(
          title: context.loc.settings,
          icon: Icons.settings_rounded,
          route: '/admin/settings',
        ),
    ];

    final shopSettings = context.watch<ShopSettingsProvider>();
    final shopName = shopSettings.shopName;
    final logoUrl = shopSettings.logoUrl;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
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
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                shopName,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: AppColors.textPrimary,
                ),
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
              final int columns = maxW >= 1000
                  ? 5
                  : maxW >= 760
                      ? 4
                      : maxW >= 520
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
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 1.2,
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
  final String route;

  const _DashboardItem({
    required this.title,
    required this.icon,
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
      shadowColor: AppColors.primary.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(item.route),
        splashColor: Colors.white.withValues(alpha: 0.15),
        highlightColor: Colors.white.withValues(alpha: 0.06),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.primaryDark,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(item.icon, color: AppColors.accent, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
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
