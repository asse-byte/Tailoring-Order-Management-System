import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/couture_icons.dart';
import '../../../../core/theme/couture_palette.dart';
import '../../../../core/widgets/couture/couture_bits.dart';
import '../../../../core/widgets/couture/couture_scaffold.dart';
import '../../../../core/utils/money.dart';
import '../../../settings/presentation/providers/shop_settings_provider.dart';
import '../../data/report_pdf_service.dart';
import '../../data/reports_repository.dart';

/// Item 8 — advanced stats board + printable report. Manager-only (the route
/// is guarded; the API returns 403 to the secretary).
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ReportsRepository _repo = ReportsRepository();

  late DateTime _from;
  late DateTime _to;
  String _presetLabel = 'Ce mois';
  ReportSummary? _summary;
  bool _loading = true;
  String? _error;

  static const List<String> _monthNames = <String>[
    'Janvier',
    'Février',
    'Mars',
    'Avril',
    'Mai',
    'Juin',
    'Juillet',
    'Août',
    'Septembre',
    'Octobre',
    'Novembre',
    'Décembre'
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to = now;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await _repo.summary(_from, _to);
      if (!mounted) return;
      setState(() {
        _summary = s;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _applyPreset(String label) {
    final now = DateTime.now();
    setState(() {
      _presetLabel = label;
      switch (label) {
        case 'Ce mois':
          _from = DateTime(now.year, now.month, 1);
          _to = now;
          break;
        case 'Mois dernier':
          final prev = DateTime(now.year, now.month - 1, 1);
          _from = prev;
          _to = DateTime(now.year, now.month, 0); // last day of prev month
          break;
        case 'Cette année':
          _from = DateTime(now.year, 1, 1);
          _to = now;
          break;
      }
    });
    _load();
  }

  Future<void> _pickCustom() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2026),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (picked != null) {
      setState(() {
        _presetLabel = 'Personnalisé';
        _from = picked.start;
        _to = picked.end;
      });
      _load();
    }
  }

  String get _periodLabel {
    if (_presetLabel == 'Cette année') return '${_from.year}';
    if (_presetLabel == 'Ce mois' || _presetLabel == 'Mois dernier') {
      return '${_monthNames[_from.month - 1]} ${_from.year}';
    }
    return 'du ${_from.day}/${_from.month}/${_from.year} au ${_to.day}/${_to.month}/${_to.year}';
  }

  Future<void> _printReport() async {
    final s = _summary;
    if (s == null) return;
    final settings = context.read<ShopSettingsProvider>();
    try {
      await ReportPdfService.shareReport(
        r: s,
        shopName: settings.shopName,
        periodLabel: _periodLabel,
        logoUrl: settings.logoUrl,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erreur rapport: $e'),
            backgroundColor: CouturePalette.terracottaDeep));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CoutureScaffold(
      title: 'Rapports',
      subtitle: 'Ce que la boutique a fait',
      actions: <Widget>[
        if (_summary != null)
          CoutureBandAction(
            icon: CoutureIcons.printer,
            tooltip: 'Imprimer',
            onPressed: _printReport,
          ),
        CoutureBandAction(
          icon: CoutureIcons.refresh,
          tooltip: 'Actualiser',
          onPressed: _load,
        ),
      ],
      child: Column(
        children: <Widget>[
          _periodBar(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? const CoutureEmpty(
                        icon: CoutureIcons.warningCircle,
                        tone: CoutureTone.urgent,
                        title: 'Le rapport ne s\'affiche pas',
                        message:
                            'Vérifiez la connexion, puis appuyez sur Actualiser.',
                      )
                    : _summary == null
                        ? const SizedBox.shrink()
                        : _body(_summary!),
          ),
        ],
      ),
    );
  }

  Widget _periodBar() {
    Widget chip(String label) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(label),
            selected: _presetLabel == label,
            onSelected: (_) => _applyPreset(label),
          ),
        );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Row(
        children: <Widget>[
          chip('Ce mois'),
          chip('Mois dernier'),
          chip('Cette année'),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('Personnalisé'),
              selected: _presetLabel == 'Personnalisé',
              onSelected: (_) => _pickCustom(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(ReportSummary r) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          Text(_periodLabel.toUpperCase(),
              style: CouturePalette.sectionLabel
                  .copyWith(color: CoutureScheme.of(context).inkFaint)),
          const SizedBox(height: 12),

          // Headline KPIs.
          Row(children: <Widget>[
            Expanded(
                child: _kpi('Argent reçu', formatFcfa(r.totalRevenue),
                    CoutureScheme.of(context).iconInk, CoutureIcons.wallet)),
            const SizedBox(width: CouturePalette.s2 + 2),
            Expanded(
                child: _kpi(
                    'Ce qui reste',
                    formatFcfa(r.netProfit),
                    r.netProfit >= 0
                        ? CoutureScheme.of(context).goodInk
                        : CoutureScheme.of(context).urgentText,
                    CoutureIcons.chartBar)),
          ]),
          const SizedBox(height: CouturePalette.s2 + 2),
          _kpi('Argent sorti', formatFcfa(r.totalCosts),
              CoutureScheme.of(context).urgentText, CoutureIcons.receipt),

          const SizedBox(height: 20),
          const _SectionTitle('Le travail de la période'),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: <Widget>[
              _stat('Nouveaux clients', '${r.newClients}', CoutureIcons.user),
              _stat('Clients servis', '${r.servedClients}',
                  CoutureIcons.checkCircle),
              _stat('Commandes livrées', '${r.ordersDelivered}',
                  CoutureIcons.truck),
              _stat('Commandes prises', '${r.ordersCreated}',
                  CoutureIcons.clipboardText),
              _stat('En couture', '${r.ordersActive}', CoutureIcons.needle),
              _stat('Produits vendus', '${r.productsSoldUnits}',
                  CoutureIcons.shoppingBag),
            ],
          ),

          const SizedBox(height: 20),
          const _SectionTitle('Ce que la boutique a dépensé'),
          _line('Achat de la marchandise vendue', r.cogs),
          _line('Paie des couturiers', r.tailorWages),
          _line('Salaires du personnel', r.salaries),
          _line('Autres dépenses', r.expenses),

          const SizedBox(height: 20),
          const _SectionTitle('Ce que la boutique a encaissé'),
          _line('Ventes en boutique', r.salesRevenue),
          _line('Commandes des clients', r.ordersRevenue),
          _line('Ventes en gros', r.wholesaleRevenue),

          if (r.topTailors.isNotEmpty) ...<Widget>[
            const SizedBox(height: 20),
            const _SectionTitle('Les meilleurs couturiers'),
            ...List.generate(r.topTailors.length, (i) {
              final t = r.topTailors[i];
              final medal = i == 0
                  ? '🥇'
                  : i == 1
                      ? '🥈'
                      : i == 2
                          ? '🥉'
                          : '${i + 1}';
              return Card(
                margin: const EdgeInsets.only(bottom: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: Text(medal, style: const TextStyle(fontSize: 18)),
                  title: Text(t.tailorName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${t.piecesTotal} pièces'),
                  trailing: Text(formatFcfa(t.amountTotal),
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: CoutureScheme.of(context).ink)),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _kpi(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(title,
              style: TextStyle(
                  fontSize: 12, color: CoutureScheme.of(context).inkSoft)),
        ],
      ),
    );
  }

  Widget _stat(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: CoutureScheme.of(context).iconInk, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(value,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: CoutureScheme.of(context).ink)),
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11,
                        color: CoutureScheme.of(context).inkSoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(String label, int amount) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Expanded(child: Text(label)),
            Text(formatFcfa(amount),
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title.toUpperCase(),
            style: CouturePalette.sectionLabel
                .copyWith(color: CoutureScheme.of(context).inkFaint)),
      );
}
