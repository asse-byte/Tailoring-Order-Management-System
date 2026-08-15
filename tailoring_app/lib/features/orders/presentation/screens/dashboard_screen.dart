import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/context_colors.dart';
import '../../../../features/settings/presentation/providers/shop_settings_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isSec = auth.isSecretary;

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
      if (!isSec)
        const _DashboardItem(
          title: 'Grossistes & Fournisseurs',
          icon: Icons.storefront_rounded,
          route: '/admin/merchants',
        ),
      const _DashboardItem(
        title: 'Mon Album',
        icon: Icons.collections_rounded,
        route: '/admin/models-showcase',
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
      _DashboardItem(
        title: context.loc.settings,
        icon: Icons.settings_rounded,
        route: '/admin/settings',
      ),
    ];

    final shopSettings = context.watch<ShopSettingsProvider>();
    final shopName = shopSettings.shopName;
    final logoUrl = shopSettings.logoUrl;
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.transparent,
        elevation: isDark ? 0.5 : 0,
        title: Row(
          children: [
            Container(
              height: 36,
              width: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                  width: 1.5,
                ),
              ),
              child: ClipOval(
                child: (logoUrl != null && logoUrl.isNotEmpty)
                    ? Image.network(
                        logoUrl.startsWith('http')
                            ? logoUrl
                            : '${ApiClient.baseUrl}$logoUrl',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => CircleAvatar(
                          backgroundColor: shopSettings.themeColor,
                          child: const Icon(Icons.storefront_rounded, size: 18, color: Colors.white),
                        ),
                      )
                    : CircleAvatar(
                        backgroundColor: shopSettings.themeColor,
                        child: const Icon(Icons.storefront_rounded, size: 18, color: Colors.white),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                shopName,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: context.cTextPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout_rounded, color: context.cTextPrimary),
            tooltip: 'Déconnexion',
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
            colors: isDark
                ? [
                    AppColors.darkSurfaceAlt.withValues(alpha: 0.5),
                    AppColors.darkBackground,
                  ]
                : [
                    shopSettings.themeColor.withValues(alpha: 0.08),
                    AppColors.background,
                  ],
            stops: const [0.0, 0.4],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
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
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${context.loc.welcomeBack}, ${auth.user?.name ?? ""}',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: context.cTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isSec ? 'Espace Secrétariat' : 'Espace Gestion & Direction',
                              style: TextStyle(
                                fontSize: 13.5,
                                color: context.cTextSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: 1.08,
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

class _DashboardCard extends StatefulWidget {
  final _DashboardItem item;

  const _DashboardCard({required this.item});

  @override
  State<_DashboardCard> createState() => _DashboardCardState();
}

class _DashboardCardState extends State<_DashboardCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final shopSettings = context.watch<ShopSettingsProvider>();
    final brandColor = shopSettings.themeColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: Card(
          elevation: _isHovered ? (isDark ? 4 : 6) : (isDark ? 1 : 2),
          shadowColor: isDark
              ? Colors.black.withValues(alpha: 0.5)
              : brandColor.withValues(alpha: 0.25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: isDark
                  ? (_isHovered ? brandColor.withValues(alpha: 0.5) : AppColors.darkBorder)
                  : (_isHovered ? brandColor.withValues(alpha: 0.4) : AppColors.border),
              width: _isHovered ? 1.5 : 1.0,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push(widget.item.route),
            splashColor: brandColor.withValues(alpha: 0.12),
            highlightColor: brandColor.withValues(alpha: 0.05),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          AppColors.darkSurface,
                          AppColors.darkSurfaceAlt,
                        ]
                      : [
                          Colors.white,
                          brandColor.withValues(alpha: 0.03),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? brandColor.withValues(alpha: 0.22)
                          : brandColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      widget.item.icon,
                      color: isDark ? const Color(0xFFE2E8F0) : brandColor,
                      size: 28,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    widget.item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: context.cTextPrimary,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
