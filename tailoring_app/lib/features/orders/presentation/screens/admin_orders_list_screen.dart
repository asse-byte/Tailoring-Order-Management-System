import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/couture_icons.dart';
import '../../../../core/theme/couture_palette.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/couture/couture_bits.dart';
import '../../../../core/widgets/couture/couture_scaffold.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../providers/admin_orders_provider.dart';
import '../widgets/order_card.dart';

/// Commandes actives (en attente / en couture / prêtes). Les commandes livrées
/// vivent dans l'Historique — même ligne, statut différent.
///
/// Redesigned onto "Indigo & Terre". Every filter, query and route is the one
/// it was; what changed is the wording (the filters now say what the shop says
/// out loud — "Prêtes" rather than "Terminé") and the weight of each part.
class AdminOrdersListScreen extends StatefulWidget {
  const AdminOrdersListScreen({super.key});

  @override
  State<AdminOrdersListScreen> createState() => _AdminOrdersListScreenState();
}

class _AdminOrdersListScreenState extends State<AdminOrdersListScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  static const List<({String? value, String label})> _statusFilters =
      <({String? value, String label})>[
    (value: null, label: 'Tout'),
    (value: AppConstants.statusEnAttente, label: 'En attente'),
    (value: AppConstants.statusEnCours, label: 'En couture'),
    (value: AppConstants.statusTermine, label: 'Prêtes'),
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
    final bool anyFilter = p.from != null ||
        p.to != null ||
        p.statusFilter != null ||
        p.query.isNotEmpty;

    return CoutureScaffold(
      title: 'Commandes',
      subtitle: 'Le travail en cours dans l\'atelier',
      actions: <Widget>[
        CoutureBandAction(
          icon: CoutureIcons.calendarCheck,
          tooltip: 'Programme de la semaine',
          onPressed: () => context.push('/admin/schedule'),
        ),
        if (anyFilter)
          CoutureBandAction(
            icon: CoutureIcons.filterOff,
            tooltip: 'Tout afficher',
            onPressed: () {
              _searchCtrl.clear();
              p.clearFilters();
            },
          ),
        CoutureBandAction(
          icon: CoutureIcons.refresh,
          tooltip: 'Actualiser',
          onPressed: p.refresh,
        ),
      ],
      below: _header(p),
      floatingActionButton: _NewOrderButton(
        onDone: () async {
          if (mounted) await p.refresh();
        },
      ),
      child: _body(p, filtered),
    );
  }

  Widget _header(AdminOrdersProvider p) => Padding(
        padding: const EdgeInsets.fromLTRB(
            CouturePalette.s4, CouturePalette.s3, CouturePalette.s4, 0),
        child: Column(
          children: <Widget>[
            CoutureSearchField(
              controller: _searchCtrl,
              hint: 'Nom du client, téléphone, vêtement',
              onChanged: (String v) {
                p.setQuery(v);
                setState(
                    () {}); // the clear button appears with the first letter
              },
              onClear: () {
                _searchCtrl.clear();
                p.setQuery('');
                setState(() {});
              },
            ),
            const SizedBox(height: CouturePalette.s3),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _statusFilters.length + 1,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: CouturePalette.s2),
                itemBuilder: (_, int i) {
                  if (i == _statusFilters.length) {
                    final bool active = p.from != null && p.to != null;
                    return CoutureFilterChip(
                      icon: CoutureIcons.calendarBlank,
                      label: active
                          ? '${DateFormatter.shortDate(p.from!, locale: 'fr')} – ${DateFormatter.shortDate(p.to!, locale: 'fr')}'
                          : 'Dates',
                      selected: active,
                      onTap: _pickDateRange,
                    );
                  }
                  final f = _statusFilters[i];
                  return CoutureFilterChip(
                    label: f.label,
                    selected: p.statusFilter == f.value,
                    onTap: () => p.setStatusFilter(f.value),
                  );
                },
              ),
            ),
            const SizedBox(height: CouturePalette.s3),
          ],
        ),
      );

  Widget _body(AdminOrdersProvider p, List filtered) {
    if (p.loading) return LoadingShimmer.list();
    if (p.error != null) {
      return const CoutureEmpty(
        icon: CoutureIcons.warningCircle,
        tone: CoutureTone.urgent,
        title: 'Les commandes ne s\'affichent pas',
        message: 'Vérifiez la connexion, puis appuyez sur Actualiser.',
      );
    }
    if (filtered.isEmpty) {
      return CoutureEmpty(
        icon: p.orders.isEmpty
            ? CoutureIcons.clipboardText
            : CoutureIcons.magnifyingGlass,
        title: p.orders.isEmpty ? 'Aucune commande' : 'Rien avec ce filtre',
        message: p.orders.isEmpty
            ? 'Appuyez sur « Nouvelle commande » pour en enregistrer une.'
            : 'Essayez un autre filtre, ou appuyez sur « Tout ».',
      );
    }
    return RefreshIndicator(
      onRefresh: p.refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
            CouturePalette.s4, CouturePalette.s1, CouturePalette.s4, 96),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: CouturePalette.s3),
        itemBuilder: (_, int i) {
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

/// The one action of this screen, in the warm colour — the same treatment the
/// till gets on the home screen, for the same reason.
class _NewOrderButton extends StatelessWidget {
  const _NewOrderButton({required this.onDone});

  final Future<void> Function() onDone;

  @override
  Widget build(BuildContext context) {
    final CoutureScheme c = CoutureScheme.of(context);
    return FloatingActionButton.extended(
      backgroundColor: c.urgentInk,
      foregroundColor: Colors.white,
      elevation: 2,
      onPressed: () async {
        await context.push('/admin/walk-in');
        await onDone();
      },
      icon: const Icon(CoutureIcons.plus, size: 20),
      label: const Text('Nouvelle commande',
          style: TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}
