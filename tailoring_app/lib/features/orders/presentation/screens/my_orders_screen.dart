import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/language_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/connectivity_helper.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../../data/orders_sync_service.dart';
import '../providers/customer_orders_provider.dart';
import '../providers/customer_tab_controller.dart';
import '../widgets/order_card.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  String? _filter; // null = all

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<CustomerOrdersProvider>();
    final list = orders.filterByStatus(_filter);

    final List<({String? value, String label})> filters =
        <({String? value, String label})>[
      (value: null, label: context.loc.all),
      (value: AppConstants.statusPending, label: context.loc.statusPending),
      (
        value: AppConstants.statusInProgress,
        label: context.loc.statusInProgress
      ),
      (value: AppConstants.statusCompleted, label: context.loc.statusCompleted),
      (value: AppConstants.statusCancelled, label: context.loc.statusCancelled),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.myOrders),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: SizedBox(
            height: 56,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final f = filters[i];
                final bool selected = _filter == f.value;
                return ChoiceChip(
                  label: Text(f.label),
                  selected: selected,
                  onSelected: (_) => setState(() => _filter = f.value),
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                );
              },
            ),
          ),
        ),
      ),
      body: Column(
        children: <Widget>[
          const _OfflineBanner(),
          Expanded(child: _body(orders, list)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.read<CustomerTabController>().goTo(1),
        icon: const Icon(Icons.add_rounded),
        label: Text(context.loc.newOrder),
      ),
    );
  }

  Widget _body(CustomerOrdersProvider provider, List list) {
    if (provider.loading) return LoadingShimmer.list();
    if (provider.error != null) {
      return EmptyState(
        title: context.loc.orderLoadError,
        message: provider.error,
        icon: Icons.error_outline,
      );
    }
    if (list.isEmpty) {
      return EmptyState(
        title: provider.orders.isEmpty
            ? context.loc.noOrdersYet
            : context.loc.noFilterResults,
        message: provider.orders.isEmpty
            ? context.loc.noOrdersYetDesc
            : context.loc.noFilterResultsDesc,
        icon: Icons.inbox_outlined,
        actionLabel:
            provider.orders.isEmpty ? context.loc.placeFirstOrder : null,
        onAction: provider.orders.isEmpty
            ? () => context.read<CustomerTabController>().goTo(1)
            : null,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final order = list[i];
        return OrderCard(
          order: order,
          onTap: () => context.push('/customer/order/${order.id}'),
        );
      },
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return ValueListenableBuilder<bool>(
      valueListenable: ConnectivityHelper.instance.online,
      builder: (_, online, __) {
        return ValueListenableBuilder<int>(
          valueListenable: OrdersSyncService.instance.pendingCount,
          builder: (_, pending, __) {
            if (online && pending == 0) return const SizedBox.shrink();

            final bool offline = !online;
            final String message = offline
                ? (pending > 0
                    ? (lang.locale.languageCode == 'fr'
                        ? 'Hors ligne — $pending commande${pending == 1 ? '' : 's'} en attente de synchro.'
                        : 'You’re offline — $pending order${pending == 1 ? '' : 's'} queued for sync.')
                    : context.loc.offlineBanner)
                : (lang.locale.languageCode == 'fr'
                    ? 'Synchronisation de $pending commande${pending == 1 ? '' : 's'}…'
                    : 'Syncing $pending queued order${pending == 1 ? '' : 's'}…');

            final Color tint = offline ? AppColors.warning : AppColors.primary;
            final IconData icon =
                offline ? Icons.cloud_off_outlined : Icons.cloud_sync_outlined;

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: tint.withValues(alpha: 0.15),
              child: Row(
                children: <Widget>[
                  Icon(icon, size: 16, color: tint),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      message,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  if (!offline)
                    const SizedBox(
                      height: 12,
                      width: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.6),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
