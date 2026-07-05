import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/order.dart';
import '../providers/admin_orders_provider.dart';
import '../providers/admin_tab_controller.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<AdminOrdersProvider>();
    final auth = context.watch<AuthProvider>();
    final tab = context.read<AdminTabController>();
    final loc = context.loc;
    final isFr = loc.locale.languageCode == 'fr';

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.dashboard),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future<void>.delayed(const Duration(milliseconds: 400));
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: <Widget>[
            Text(
              isFr
                  ? 'Bonjour, ${auth.user?.name.split(' ').first ?? 'Admin'}'
                  : 'Hi, ${auth.user?.name.split(' ').first ?? 'Admin'}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              isFr ? "Aujourd'hui en un coup d'œil" : "Today's at a glance",
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 20),
            if (orders.loading)
              const _SummarySkeleton()
            else
              _SummaryGrid(provider: orders),
            const SizedBox(height: 24),
            SectionHeader(title: loc.quickActions),
            const SizedBox(height: 12),
            _QuickActions(
              onAddOrder: () => context.push('/admin/walk-in'),
              onAllOrders: () => tab.goTo(1),
              onCustomers: () => tab.goTo(2),
            ),
            const SizedBox(height: 24),
            SectionHeader(
              title: loc.recentActivity,
              action: TextButton(
                onPressed: () => tab.goTo(1),
                child: Text(isFr ? 'Voir tout' : 'View all'),
              ),
            ),
            const SizedBox(height: 12),
            _RecentActivity(provider: orders),
          ],
        ),
      ),
    );
  }
}

// ---------- Summary cards ----------

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.provider});
  final AdminOrdersProvider provider;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final List<({String label, String value, IconData icon, Color color})>
        cards = <({String label, String value, IconData icon, Color color})>[
      (
        label: loc.totalOrders,
        value: provider.totalToday.toString(),
        icon: Icons.today_outlined,
        color: AppColors.primary,
      ),
      (
        label: loc.pendingCount,
        value: provider.pendingCount.toString(),
        icon: Icons.schedule_rounded,
        color: AppColors.statusPending,
      ),
      (
        label: loc.inProgressCount,
        value: provider.inProgressCount.toString(),
        icon: Icons.handyman_outlined,
        color: AppColors.statusInProgress,
      ),
      (
        label: loc.completedCount,
        value: provider.completedCount.toString(),
        icon: Icons.check_circle_outline,
        color: AppColors.statusCompleted,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: cards.map((c) => _SummaryCard(data: c)).toList(growable: false),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.data});
  final ({String label, String value, IconData icon, Color color}) data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(data.icon, color: data.color, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(data.value,
                  style: Theme.of(context).textTheme.displayMedium),
              Text(data.label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummarySkeleton extends StatelessWidget {
  const _SummarySkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: List<Widget>.generate(
        4,
        (_) => LoadingShimmer.box(
            height: double.infinity, borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

// ---------- Quick actions ----------

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onAddOrder,
    required this.onAllOrders,
    required this.onCustomers,
  });

  final VoidCallback onAddOrder;
  final VoidCallback onAllOrders;
  final VoidCallback onCustomers;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final List<({String label, IconData icon, VoidCallback onTap, Color color})>
        items =
        <({String label, IconData icon, VoidCallback onTap, Color color})>[
      (
        label: loc.addOrder,
        icon: Icons.person_add_alt_1_outlined,
        onTap: onAddOrder,
        color: AppColors.primary,
      ),
      (
        label: loc.viewAllOrders,
        icon: Icons.receipt_long_outlined,
        onTap: onAllOrders,
        color: AppColors.statusInProgress,
      ),
      (
        label: loc.viewCustomers,
        icon: Icons.people_outline_rounded,
        onTap: onCustomers,
        color: AppColors.accentDark,
      ),
    ];
    return Row(
      children: <Widget>[
        for (int i = 0; i < items.length; i++) ...<Widget>[
          Expanded(child: _QuickActionTile(data: items[i])),
          if (i != items.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.data});
  final ({String label, IconData icon, VoidCallback onTap, Color color}) data;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: data.onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                height: 32,
                width: 32,
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(data.icon, color: data.color, size: 18),
              ),
              const SizedBox(height: 10),
              Text(data.label, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- Recent activity ----------

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({required this.provider});
  final AdminOrdersProvider provider;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final isFr = loc.locale.languageCode == 'fr';
    if (provider.loading) {
      return Column(
        children: List<Widget>.generate(
          3,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: LoadingShimmer.orderCard(),
          ),
        ),
      );
    }
    final List<TailoringOrder> recent = provider.recent();
    if (recent.isEmpty) {
      return EmptyState(
        title: isFr ? 'Aucune activité' : 'No activity yet',
        message: isFr
            ? 'Les mises à jour récentes apparaîtront ici.'
            : 'Recent order updates will show up here.',
        icon: Icons.history_rounded,
      );
    }
    return Column(
      children: recent
          .map((o) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ActivityRow(order: o),
              ))
          .toList(growable: false),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.order});
  final TailoringOrder order;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final isFr = loc.locale.languageCode == 'fr';
    return Material(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/admin/order/${order.id}'),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${order.customerName} · ${loc.garmentName(order.garmentType)}',
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isFr
                          ? 'Mis à jour ${DateFormatter.relative(order.updatedAt ?? order.createdAt ?? DateTime.now(), locale: 'fr')}'
                          : 'Updated ${DateFormatter.relative(order.updatedAt ?? order.createdAt ?? DateTime.now(), locale: 'en')}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(status: order.status, compact: true),
            ],
          ),
        ),
      ),
    );
  }
}
