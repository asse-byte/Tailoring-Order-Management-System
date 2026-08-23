import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/couture_icons.dart';
import '../../../../core/theme/couture_palette.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/couture/couture_bits.dart';
import '../../../../core/widgets/couture/couture_scaffold.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../../data/orders_repository.dart';
import '../../domain/entities/order.dart';
import '../widgets/order_card.dart';

/// Historique : commandes livrées (status = livre), recherche par client et
/// filtre par date de livraison (côté serveur).
///
/// Redesigned onto "Indigo & Terre" in the same commit as the orders list,
/// because both draw the same [OrderCard] — leaving one behind would have put
/// a new card inside an old screen.
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
    final List<TailoringOrder> filtered = q.isEmpty
        ? _orders
        : _orders
            .where((TailoringOrder o) =>
                o.clientName.toLowerCase().contains(q) ||
                o.clientPhone.contains(q) ||
                o.garmentType.toLowerCase().contains(q))
            .toList(growable: false);

    final bool dated = _from != null && _to != null;

    return CoutureScaffold(
      title: 'Historique',
      subtitle: 'Les commandes déjà livrées',
      actions: <Widget>[
        if (dated)
          CoutureBandAction(
            icon: CoutureIcons.filterOff,
            tooltip: 'Toutes les dates',
            onPressed: () {
              setState(() {
                _from = null;
                _to = null;
              });
              _load();
            },
          ),
      ],
      below: Padding(
        padding: const EdgeInsets.fromLTRB(
            CouturePalette.s4, CouturePalette.s3, CouturePalette.s4, 0),
        child: Column(
          children: <Widget>[
            CoutureSearchField(
              controller: _searchCtrl,
              hint: 'Nom du client, téléphone, vêtement',
              onChanged: (String v) => setState(() => _query = v),
              onClear: () {
                _searchCtrl.clear();
                setState(() => _query = '');
              },
            ),
            const SizedBox(height: CouturePalette.s3),
            Align(
              alignment: Alignment.centerLeft,
              child: CoutureFilterChip(
                icon: CoutureIcons.calendarBlank,
                label: dated
                    ? '${DateFormatter.shortDate(_from!, locale: 'fr')} – ${DateFormatter.shortDate(_to!, locale: 'fr')}'
                    : 'Choisir des dates',
                selected: dated,
                onTap: _pickDateRange,
              ),
            ),
            const SizedBox(height: CouturePalette.s3),
          ],
        ),
      ),
      child: _body(filtered),
    );
  }

  Widget _body(List<TailoringOrder> filtered) {
    if (_loading) return LoadingShimmer.list();
    if (_error != null) {
      return const CoutureEmpty(
        icon: CoutureIcons.warningCircle,
        tone: CoutureTone.urgent,
        title: 'L\'historique ne s\'affiche pas',
        message:
            'Vérifiez la connexion, puis tirez vers le bas pour réessayer.',
      );
    }
    if (filtered.isEmpty) {
      return CoutureEmpty(
        icon: CoutureIcons.clockCounterClockwise,
        title:
            _orders.isEmpty ? 'Rien de livré pour l\'instant' : 'Rien trouvé',
        message: _orders.isEmpty
            ? 'Une commande arrive ici le jour où vous la remettez au client.'
            : 'Essayez un autre nom, ou d\'autres dates.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(CouturePalette.s4, CouturePalette.s1,
            CouturePalette.s4, CouturePalette.s6),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: CouturePalette.s3),
        itemBuilder: (_, int i) {
          final TailoringOrder order = filtered[i];
          return OrderCard(
            order: order,
            onTap: () async {
              await context.push('/admin/order/${order.id}');
              if (mounted) _load();
            },
          );
        },
      ),
    );
  }
}
