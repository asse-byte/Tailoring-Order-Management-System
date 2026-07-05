import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../providers/admin_orders_provider.dart';
import '../widgets/order_card.dart';

class AdminOrdersListScreen extends StatefulWidget {
  const AdminOrdersListScreen({super.key});

  @override
  State<AdminOrdersListScreen> createState() => _AdminOrdersListScreenState();
}

class _AdminOrdersListScreenState extends State<AdminOrdersListScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  static const List<({String? value, String label})> _statusFilters =
      <({String? value, String label})>[
    (value: null, label: 'All Active'),
    (value: AppConstants.statusPending, label: 'Pending'),
    (value: AppConstants.statusInProgress, label: 'In Progress'),
    (value: AppConstants.statusCancelled, label: 'Cancelled'),
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final p = context.read<AdminOrdersProvider>();
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: (p.from != null && p.to != null)
          ? DateTimeRange(start: p.from!, end: p.to!)
          : null,
    );
    if (picked != null) {
      p.setDateRange(picked.start, picked.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AdminOrdersProvider>();
    final filtered = p.filtered.where((o) => o.status != AppConstants.statusCompleted).toList();
    final loc = context.loc;
    final isFr = loc.locale.languageCode == 'fr';

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.viewAllOrders),
        actions: <Widget>[
          if (p.from != null ||
              p.to != null ||
              p.statusFilter != null ||
              p.query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.filter_alt_off_outlined),
              tooltip: isFr ? 'Effacer les filtres' : 'Clear filters',
              onPressed: () {
                _searchCtrl.clear();
                p.clearFilters();
              },
            ),
        ],
      ),
      body: Column(
        children: <Widget>[
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: p.setQuery,
              decoration: InputDecoration(
                hintText: isFr
                    ? 'Rechercher par client, vêtement, id...'
                    : 'Search by customer, garment, order id…',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: p.query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          p.setQuery('');
                        },
                      ),
              ),
            ),
          ),
          // Filter chips row
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _statusFilters.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                if (i == _statusFilters.length) {
                  // Date range chip
                  final bool active = p.from != null && p.to != null;
                  final String lang = loc.locale.languageCode;
                  return ActionChip(
                    avatar: const Icon(Icons.event_outlined, size: 16),
                    label: Text(active
                        ? '${DateFormatter.shortDate(p.from!, locale: lang)} – ${DateFormatter.shortDate(p.to!, locale: lang)}'
                        : (isFr ? 'Période' : 'Date range')),
                    backgroundColor: active
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : null,
                    onPressed: _pickDateRange,
                  );
                }
                final f = _statusFilters[i];
                final bool selected = p.statusFilter == f.value;

                String chipLabel;
                if (f.value == null) {
                  chipLabel = loc.all;
                } else if (f.value == AppConstants.statusPending) {
                  chipLabel = loc.statusPending;
                } else if (f.value == AppConstants.statusInProgress) {
                  chipLabel = loc.statusInProgress;
                } else if (f.value == AppConstants.statusCompleted) {
                  chipLabel = loc.statusCompleted;
                } else {
                  chipLabel = loc.statusCancelled;
                }

                return ChoiceChip(
                  label: Text(chipLabel),
                  selected: selected,
                  onSelected: (_) => p.setStatusFilter(f.value),
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
          const SizedBox(height: 8),
          Expanded(child: _body(p, filtered)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/admin/walk-in'),
        icon: const Icon(Icons.add_rounded),
        label: Text(loc.walkIn),
      ),
    );
  }

  Widget _body(AdminOrdersProvider p, List filtered) {
    final loc = context.loc;
    final isFr = loc.locale.languageCode == 'fr';
    if (p.loading) return LoadingShimmer.list();
    if (p.error != null) {
      return EmptyState(
        title: loc.orderLoadError,
        message: p.error,
        icon: Icons.error_outline,
      );
    }
    if (filtered.isEmpty) {
      return EmptyState(
        title: p.orders.isEmpty ? loc.noOrdersYet : loc.noFilterResults,
        message: p.orders.isEmpty
            ? (isFr
                ? 'Les commandes passées par les clients et sur place apparaîtront ici.'
                : 'Customer-placed and walk-in orders will show here.')
            : loc.noFilterResultsDesc,
        icon: Icons.inbox_outlined,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final order = filtered[i];
        return OrderCard(
          order: order,
          showCustomer: true,
          onTap: () => context.push('/admin/order/${order.id}'),
        );
      },
    );
  }
}
