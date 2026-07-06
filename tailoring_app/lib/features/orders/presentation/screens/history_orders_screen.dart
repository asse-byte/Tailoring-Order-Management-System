import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../../data/orders_repository.dart';
import '../../domain/entities/order.dart';
import '../widgets/order_card.dart';

/// Historique : commandes livrées (status = livre), recherche par client
/// et filtre par date de livraison (côté serveur).
class HistoryOrdersScreen extends StatefulWidget {
  const HistoryOrdersScreen({super.key});

  @override
  State<HistoryOrdersScreen> createState() => _HistoryOrdersScreenState();
}

class _HistoryOrdersScreenState extends State<HistoryOrdersScreen> {
  final OrdersRepository _repo = OrdersRepository();
  final TextEditingController _searchCtrl = TextEditingController();

  List<TailoringOrder> _orders = <TailoringOrder>[];
  bool _loading = true;
  String? _error;
  String _query = '';
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _orders = await _repo.list(
        status: AppConstants.statusLivre,
        from: _from,
        to: _to,
        limit: 100,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      lastDate: DateTime.now(),
      initialDateRange: (_from != null && _to != null)
          ? DateTimeRange(start: _from!, end: _to!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _from = picked.start;
        _to = picked.end;
      });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final String q = _query.toLowerCase();
    final filtered = q.isEmpty
        ? _orders
        : _orders
            .where((o) =>
                o.clientName.toLowerCase().contains(q) ||
                o.clientPhone.contains(q) ||
                o.garmentType.toLowerCase().contains(q))
            .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique'),
        actions: <Widget>[
          IconButton(
            icon: Icon(
              Icons.event_outlined,
              color: (_from != null) ? AppColors.primary : null,
            ),
            tooltip: 'Filtrer par date de livraison',
            onPressed: _pickDateRange,
          ),
          if (_from != null)
            IconButton(
              icon: const Icon(Icons.filter_alt_off_outlined),
              tooltip: 'Effacer le filtre de dates',
              onPressed: () {
                setState(() {
                  _from = null;
                  _to = null;
                });
                _load();
              },
            ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Rechercher par client, téléphone, vêtement...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
          if (_from != null && _to != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  avatar: const Icon(Icons.event_outlined, size: 16),
                  label: Text(
                    '${DateFormatter.shortDate(_from!, locale: 'fr')} – ${DateFormatter.shortDate(_to!, locale: 'fr')}',
                  ),
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? LoadingShimmer.list()
                : _error != null
                    ? EmptyState(
                        title: 'Impossible de charger l\'historique',
                        message: _error,
                        icon: Icons.error_outline,
                      )
                    : filtered.isEmpty
                        ? const EmptyState(
                            title: 'Aucune commande livrée',
                            message:
                                'Les commandes livrées apparaîtront ici, avec tous leurs détails.',
                            icon: Icons.history_rounded,
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (_, i) {
                                final order = filtered[i];
                                return OrderCard(
                                  order: order,
                                  onTap: () async {
                                    await context
                                        .push('/admin/order/${order.id}');
                                    if (mounted) _load();
                                  },
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
