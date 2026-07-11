import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../providers/admin_orders_provider.dart';
import '../widgets/order_card.dart';

/// Commandes actives (en cours / prêt). Les commandes livrées vivent dans
/// l'Historique — même ligne, statut différent.
class AdminOrdersListScreen extends StatefulWidget {
  const AdminOrdersListScreen({super.key});

  @override
  State<AdminOrdersListScreen> createState() => _AdminOrdersListScreenState();
}

class _AdminOrdersListScreenState extends State<AdminOrdersListScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  static const List<({String? value, String label})> _statusFilters =
      <({String? value, String label})>[
    (value: null, label: 'Tous actifs'),
    (value: AppConstants.statusEnAttente, label: 'En attente'),
    (value: AppConstants.statusEnCours, label: 'En cours'),
    (value: AppConstants.statusTermine, label: 'Terminé'),
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
    final filtered =
        p.filtered.where((o) => !o.isLivre).toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Commandes'),
        actions: <Widget>[
          if (p.from != null ||
              p.to != null ||
              p.statusFilter != null ||
              p.query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.filter_alt_off_outlined),
              tooltip: 'Effacer les filtres',
              onPressed: () {
                _searchCtrl.clear();
                p.clearFilters();
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: p.refresh,
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: p.setQuery,
              decoration: InputDecoration(
                hintText: 'Rechercher par client, téléphone, vêtement...',
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
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _statusFilters.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                if (i == _statusFilters.length) {
                  final bool active = p.from != null && p.to != null;
                  return ActionChip(
                    avatar: const Icon(Icons.event_outlined, size: 16),
                    label: Text(active
                        ? '${DateFormatter.shortDate(p.from!, locale: 'fr')} – ${DateFormatter.shortDate(p.to!, locale: 'fr')}'
                        : 'Période'),
                    backgroundColor: active
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : null,
                    onPressed: _pickDateRange,
                  );
                }
                final f = _statusFilters[i];
                final bool selected = p.statusFilter == f.value;
                return ChoiceChip(
                  label: Text(f.label),
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
        onPressed: () async {
          await context.push('/admin/walk-in');
          if (mounted) p.refresh();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nouvelle commande'),
      ),
    );
  }

  Widget _body(AdminOrdersProvider p, List filtered) {
    if (p.loading) return LoadingShimmer.list();
    if (p.error != null) {
      return EmptyState(
        title: 'Impossible de charger les commandes',
        message: p.error,
        icon: Icons.error_outline,
      );
    }
    if (filtered.isEmpty) {
      return EmptyState(
        title: p.orders.isEmpty
            ? 'Aucune commande pour le moment'
            : 'Aucun résultat pour ce filtre',
        message: p.orders.isEmpty
            ? 'Les commandes des clients apparaîtront ici.'
            : 'Essayez un autre filtre pour voir plus de commandes.',
        icon: Icons.inbox_outlined,
      );
    }
    return RefreshIndicator(
      onRefresh: p.refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final order = filtered[i];
          return OrderCard(
            order: order,
            onTap: () async {
              await context.push('/admin/order/${order.id}');
              if (mounted) p.refresh();
            },
          );
        },
      ),
    );
  }
}
