import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/context_colors.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/whatsapp.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../settings/presentation/providers/shop_settings_provider.dart';
import '../../data/reports_repository.dart';

/// Delivered orders that still carry an unpaid balance, with a one-tap polite
/// WhatsApp reminder per client.
class UnpaidOrdersScreen extends StatefulWidget {
  const UnpaidOrdersScreen({super.key});

  @override
  State<UnpaidOrdersScreen> createState() => _UnpaidOrdersScreenState();
}

class _UnpaidOrdersScreenState extends State<UnpaidOrdersScreen> {
  final ReportsRepository _repo = ReportsRepository();

  UnpaidOrdersPage? _page;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final UnpaidOrdersPage page = await _repo.unpaidOrders(limit: 200);
      if (!mounted) return;
      setState(() {
        _page = page;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _remind(UnpaidOrder order) async {
    final String shopName = context.read<ShopSettingsProvider>().shopName;
    final bool ok = await openWhatsApp(
      order.clientPhone,
      text: unpaidReminderMessage(
        clientName: order.clientName,
        shopName: shopName,
        resteFormatted: formatFcfa(order.reste),
      ),
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Numéro WhatsApp manquant ou invalide pour ce client.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cBackground,
      appBar: AppBar(
        title: const Text('Impayés & Rappels'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualiser',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.error_outline_rounded,
                  size: 44, color: AppColors.error),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: context.cTextPrimary)),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }

    final UnpaidOrdersPage page = _page!;
    if (page.items.isEmpty) {
      return const EmptyState(
        icon: Icons.verified_rounded,
        title: 'Aucun impayé',
        message: 'Toutes les commandes livrées ont été réglées.',
      );
    }

    return Column(
      children: <Widget>[
        _TotalBanner(totalDue: page.totalDue, count: page.totalCount),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: page.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (BuildContext context, int index) {
                final UnpaidOrder order = page.items[index];
                return _UnpaidCard(
                  order: order,
                  onRemind: () => _remind(order),
                  onOpen: () => context.push('/admin/order/${order.id}'),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _TotalBanner extends StatelessWidget {
  const _TotalBanner({required this.totalDue, required this.count});

  final int totalDue;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.account_balance_wallet_rounded,
              color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  formatFcfa(totalDue),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.error,
                  ),
                ),
                Text(
                  '$count commande${count > 1 ? 's' : ''} livrée${count > 1 ? 's' : ''} non réglée${count > 1 ? 's' : ''}',
                  style: TextStyle(fontSize: 12, color: context.cTextSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UnpaidCard extends StatelessWidget {
  const _UnpaidCard({
    required this.order,
    required this.onRemind,
    required this.onOpen,
  });

  final UnpaidOrder order;
  final VoidCallback onRemind;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final bool reachable = canWhatsApp(order.clientPhone);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: context.cBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      order.clientName,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: context.cTextPrimary,
                      ),
                    ),
                  ),
                  Text(
                    formatFcfa(order.reste),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppColors.error,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Total ${formatFcfa(order.total)} — réglé ${formatFcfa(order.paid)}'
                '${order.deliveredDate != null ? ' — livrée le ${order.deliveredDate!.split('T').first}' : ''}',
                style: TextStyle(fontSize: 12, color: context.cTextSecondary),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: reachable ? onRemind : null,
                      icon: const Icon(Icons.chat_rounded, size: 18),
                      label: Text(reachable
                          ? 'Rappeler sur WhatsApp'
                          : 'Numéro manquant'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.success,
                        side: const BorderSide(color: AppColors.success, width: 1.2),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
