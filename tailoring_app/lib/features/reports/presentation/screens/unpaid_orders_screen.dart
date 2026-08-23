import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/couture_icons.dart';
import '../../../../core/theme/couture_palette.dart';
import '../../../../core/widgets/couture/couture_bits.dart';
import '../../../../core/widgets/couture/couture_scaffold.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/whatsapp.dart';
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
          backgroundColor: CouturePalette.terracottaDeep,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CoutureScaffold(
      title: 'Argent à rentrer',
      subtitle: 'Commandes livrées, pas encore payées',
      actions: <Widget>[
        CoutureBandAction(
          icon: CoutureIcons.refresh,
          tooltip: 'Actualiser',
          onPressed: _loading ? () {} : _load,
        ),
      ],
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return const CoutureEmpty(
        icon: CoutureIcons.warningCircle,
        tone: CoutureTone.urgent,
        title: 'La liste ne s\'affiche pas',
        message: 'Vérifiez la connexion, puis appuyez sur Actualiser.',
      );
    }

    final UnpaidOrdersPage page = _page!;
    if (page.items.isEmpty) {
      return const CoutureEmpty(
        icon: CoutureIcons.checkCircle,
        tone: CoutureTone.good,
        title: 'Personne ne doit rien',
        message: 'Toutes les commandes livrées ont été payées.',
      );
    }

    return Column(
      children: <Widget>[
        _TotalBanner(totalDue: page.totalDue, count: page.totalCount),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(CouturePalette.s4,
                  CouturePalette.s3, CouturePalette.s4, CouturePalette.s6),
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
    final CoutureScheme c = CoutureScheme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
          CouturePalette.s4, CouturePalette.s4, CouturePalette.s4, 0),
      padding: const EdgeInsets.all(CouturePalette.s4),
      decoration: BoxDecoration(
        color: c.urgentWash,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          Icon(CoutureIcons.wallet, color: c.urgentText, size: 22),
          const SizedBox(width: CouturePalette.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  formatFcfa(totalDue),
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: c.urgentText,
                  ),
                ),
                Text(
                  count > 1
                      ? '$count clients doivent encore de l\'argent'
                      : '1 client doit encore de l\'argent',
                  style: TextStyle(fontSize: 12.5, color: c.urgentText),
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
    final CoutureScheme c = CoutureScheme.of(context);
    return CoutureCard(
      onTap: onOpen,
      padding: const EdgeInsets.all(CouturePalette.s3 + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  order.clientName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: c.ink,
                  ),
                ),
              ),
              Text(
                formatFcfa(order.reste),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: c.urgentText,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Prix ${formatFcfa(order.total)} · déjà payé ${formatFcfa(order.paid)}'
            '${order.deliveredDate != null ? ' · livrée le ${order.deliveredDate!.split('T').first}' : ''}',
            style: TextStyle(fontSize: 12, color: c.inkSoft),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: reachable ? onRemind : null,
                  icon: const Icon(CoutureIcons.whatsapp, size: 18),
                  label: Text(
                      reachable ? 'Rappeler sur WhatsApp' : 'Pas de numéro'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.goodInk,
                    minimumSize: const Size.fromHeight(CouturePalette.minTouch),
                    side: BorderSide(color: c.goodInk, width: 1.2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
