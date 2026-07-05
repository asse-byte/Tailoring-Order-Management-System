import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../providers/admin_orders_provider.dart';
import '../widgets/order_card.dart';

class HistoryOrdersScreen extends StatefulWidget {
  const HistoryOrdersScreen({super.key});

  @override
  State<HistoryOrdersScreen> createState() => _HistoryOrdersScreenState();
}

class _HistoryOrdersScreenState extends State<HistoryOrdersScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AdminOrdersProvider>();
    final completedOrders = p.orders.where((o) => o.status == 'completed').toList();
    
    final filtered = completedOrders.where((o) {
      final matchesSearch = o.customerName.toLowerCase().contains(_query.toLowerCase()) ||
          o.garmentType.toLowerCase().contains(_query.toLowerCase()) ||
          o.id.toLowerCase().contains(_query.toLowerCase());
      return matchesSearch;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique / Completed Orders'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Rechercher par client, id / Search...',
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
          ),
          Expanded(
            child: p.loading
                ? LoadingShimmer.list()
                : filtered.isEmpty
                    ? const EmptyState(
                        title: 'Aucun historique / No completed orders',
                        message: 'Les commandes terminées apparaîtront ici.',
                        icon: Icons.history_rounded,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      ),
          ),
        ],
      ),
    );
  }
}
