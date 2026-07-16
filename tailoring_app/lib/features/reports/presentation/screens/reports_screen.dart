import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
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
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet',
    'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
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
            backgroundColor: AppColors.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapport & Statistiques'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
          if (_summary != null)
            IconButton(
              icon: const Icon(Icons.print_rounded),
              tooltip: 'Imprimer le rapport',
              onPressed: _printReport,
            ),
        ],
      ),
      body: Column(
        children: <Widget>[
          _periodBar(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text('Erreur: $_error'))
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
          Text(_periodLabel,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary)),
          const SizedBox(height: 12),

          // Headline KPIs.
          Row(children: <Widget>[
            Expanded(
                child: _kpi('Revenu total', formatFcfa(r.totalRevenue),
                    AppColors.primary, Icons.trending_up_rounded)),
            const SizedBox(width: 10),
            Expanded(
                child: _kpi('Bénéfice net', formatFcfa(r.netProfit),
                    r.netProfit >= 0 ? AppColors.success : AppColors.error,
                    Icons.account_balance_wallet_rounded)),
          ]),
          const SizedBox(height: 10),
          _kpi('Coûts totaux', formatFcfa(r.totalCosts), AppColors.warning,
              Icons.payments_rounded),

          const SizedBox(height: 20),
          const _SectionTitle('Activité'),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: <Widget>[
              _stat('Nouveaux clients', '${r.newClients}', Icons.person_add_rounded),
              _stat('Clients servis', '${r.servedClients}', Icons.how_to_reg_rounded),
              _stat('Commandes livrées', '${r.ordersDelivered}', Icons.check_circle_rounded),
              _stat('Commandes créées', '${r.ordersCreated}', Icons.add_box_rounded),
              _stat('En cours (actuel)', '${r.ordersActive}', Icons.timelapse_rounded),
              _stat('Produits vendus', '${r.productsSoldUnits}', Icons.shopping_bag_rounded),
            ],
          ),

          const SizedBox(height: 20),
          const _SectionTitle('Détail des coûts'),
          _line('Marchandises vendues (COGS)', r.cogs),
          _line('Main d\'œuvre couture', r.tailorWages),
          _line('Salaires mensuels (prorata)', r.salaries),
          _line('Dépenses', r.expenses),

          const SizedBox(height: 20),
          const _SectionTitle('Revenus'),
          _line('Ventes produits / prêt-à-porter', r.salesRevenue),
          _line('Commandes livrées', r.ordersRevenue),

          if (r.topTailors.isNotEmpty) ...<Widget>[
            const SizedBox(height: 20),
            const _SectionTitle('Classement des tailleurs'),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: Text(medal, style: const TextStyle(fontSize: 18)),
                  title: Text(t.tailorName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${t.piecesTotal} pièces'),
                  trailing: Text(formatFcfa(t.amountTotal),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, color: AppColors.primary)),
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
          Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(value,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
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
        child: Text(title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
      );
}
