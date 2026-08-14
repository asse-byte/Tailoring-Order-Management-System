import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../reports/data/reports_repository.dart';
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
      // Both roles: the secretary manages the monthly-staff roster (the screen
      // hides all salary/payment data for her).
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
      // Manager only: supplier debts and wholesale orders are money (totals,
      // amounts paid, outstanding balance), so they fall under the secretary's
      // financial isolation. The API returns 403 for her on both.
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
      // Both roles: the secretary gets a reduced settings page (her account +
      // read-only shop identity; no shop branding, no financial settings).
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
                        errorWidget: (_, __, ___) => const CircleAvatar(
                          backgroundColor: AppColors.primary,
                          child: Icon(Icons.storefront_rounded, size: 18, color: Colors.white),
                        ),
                      )
                    : const CircleAvatar(
                        backgroundColor: AppColors.primary,
                        child: Icon(Icons.storefront_rounded, size: 18, color: Colors.white),
                      ),
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
              // Fewer columns → larger tiles (owner asked for bigger boxes).
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
                      // Live KPI tiles. Manager only: they carry the day's
                      // cash and the outstanding client debt, which rule 1
                      // keeps away from the secretary (the endpoint is
                      // manager-only server-side too).
                      if (!isSec) const _KpiStrip(),
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

/// Compact KPI row above the module grid: today's activity, the production
/// pipeline, and what clients still owe.
///
/// Loads once and fails SILENTLY: the dashboard is the app's front door, so a
/// KPI request that errors (offline, server restarting) must never replace the
/// module grid with an error screen — the strip simply does not appear.
class _KpiStrip extends StatefulWidget {
  const _KpiStrip();

  @override
  State<_KpiStrip> createState() => _KpiStripState();
}

class _KpiStripState extends State<_KpiStrip> {
  DashboardKpis? _kpis;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final DashboardKpis k = await ReportsRepository().dashboard();
      if (mounted) setState(() => _kpis = k);
    } catch (_) {
      // Silent by design — see the class comment.
    }
  }

  @override
  Widget build(BuildContext context) {
    final DashboardKpis? k = _kpis;
    if (k == null) return const SizedBox.shrink();

    return SizedBox(
      height: 92,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: <Widget>[
          _KpiTile(
            label: 'Encaissé aujourd\'hui',
            value: formatFcfa(k.paymentsToday),
            sub: '${k.ordersToday} commande${k.ordersToday > 1 ? 's' : ''}',
            icon: Icons.payments_rounded,
            color: AppColors.success,
          ),
          _KpiTile(
            label: 'En production',
            value: '${k.enCours}',
            sub: '${k.enAttente} en attente',
            icon: Icons.content_cut_rounded,
            color: AppColors.primary,
          ),
          _KpiTile(
            label: 'Prêtes à retirer',
            value: '${k.termine}',
            sub: 'à prévenir',
            icon: Icons.inventory_2_rounded,
            color: AppColors.warning,
          ),
          _KpiTile(
            label: 'Impayés',
            value: formatFcfa(k.debtTotal),
            sub: '${k.debtClients} client${k.debtClients > 1 ? 's' : ''}',
            icon: Icons.account_balance_wallet_rounded,
            color: AppColors.error,
            onTap: () => context.push('/admin/unpaid-orders'),
          ),
        ],
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final String sub;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 172,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w900, color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                sub,
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
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
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(item.icon, color: AppColors.accent, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
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
