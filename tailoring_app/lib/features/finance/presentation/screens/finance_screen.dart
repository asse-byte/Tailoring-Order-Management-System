import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/couture_icons.dart';
import '../../../../core/theme/couture_palette.dart';
import '../../../../core/widgets/couture/couture_bits.dart';
import '../../../../core/widgets/couture/couture_scaffold.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/formatted_number_field.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/finance_repository.dart';
import '../../../settings/presentation/providers/shop_settings_provider.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  final FinanceRepository _repo = FinanceRepository();
  bool _loading = true;
  String? _error;

  FinanceSummary? _summary;
  List<Expense> _expenses = [];

  // Per-category operations for the selected period, each with the subtotal
  // the SERVER computed over the whole window. The screen must never add these
  // up itself: the rows are capped for the phone's sake, so a folded subtotal
  // would silently cover only part of the period.
  FinanceDetail? _detail;

  // Date range state: default to current month
  DateTime _fromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _toDate = DateTime.now();
  String _period = 'mois'; // jour | semaine | mois | annee | perso

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final isSec = context.read<AuthProvider>().isSecretary;
      if (!isSec) {
        _loadFinanceData();
      }
    });
  }

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadFinanceData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final fromStr = _formatDate(_fromDate);
      final toStr = _formatDate(_toDate);

      final results = await Future.wait(<Future<dynamic>>[
        _repo.getSummary(from: fromStr, to: toStr),
        _repo.listExpenses(),
        _repo.detail(from: fromStr, to: toStr),
      ]);

      setState(() {
        _summary = results[0] as FinanceSummary;
        _expenses = results[1] as List<Expense>;
        _detail = results[2] as FinanceDetail;
      });
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _loading = false);
    }
  }

  void _setPeriod(String period) {
    final now = DateTime.now();
    final DateTime to = now;
    DateTime from;
    switch (period) {
      case 'jour':
        from = DateTime(now.year, now.month, now.day);
        break;
      case 'semaine':
        from = now.subtract(Duration(days: now.weekday - 1));
        from = DateTime(from.year, from.month, from.day);
        break;
      case 'annee':
        from = DateTime(now.year, 1, 1);
        break;
      case 'mois':
      default:
        from = DateTime(now.year, now.month, 1);
    }
    setState(() {
      _period = period;
      _fromDate = from;
      _toDate = to;
    });
    _loadFinanceData();
  }

  /// An expandable table for one finance category (operations + subtotal).
  ///
  /// The subtotal is [FinanceCategory.total] — computed by the server over the
  /// whole period. It is NOT the sum of [FinanceCategory.rows]: those are
  /// capped so a phone does not render thousands of lines, and folding them
  /// here is exactly what used to print a first-page total under a card
  /// holding the real one.
  Widget _detailSection(
      String title, FinanceCategory cat, IconData icon, Color color) {
    final List<FinanceRow> rows = cat.rows;
    final int subtotal = cat.total;
    final CoutureScheme c = CoutureScheme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: CouturePalette.s2),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Icon(icon, color: color, size: 20),
        title: Text(title,
            style: TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13.5, color: c.ink)),
        subtitle: Text(
            cat.truncated
                ? 'Les ${rows.length} plus récentes (le total compte tout)'
                : rows.length == 1
                    ? '1 opération'
                    : '${rows.length} opérations',
            style: TextStyle(fontSize: 12, color: c.inkFaint)),
        trailing: Text(formatFcfa(subtotal),
            style: TextStyle(fontWeight: FontWeight.w700, color: color)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: rows.isEmpty
            ? <Widget>[
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('Rien sur cette période.',
                      style: TextStyle(fontSize: 13, color: c.inkFaint)),
                )
              ]
            : rows
                .map((r) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(r.title,
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: c.ink,
                                        fontWeight: FontWeight.w500)),
                                if (r.subtitle.isNotEmpty)
                                  Text(r.subtitle,
                                      style: TextStyle(
                                          fontSize: 11, color: c.inkFaint)),
                              ],
                            ),
                          ),
                          Text(formatFcfa(r.amount),
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: c.ink)),
                        ],
                      ),
                    ))
                .toList(),
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2026),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
      });
      _loadFinanceData();
    }
  }

  Future<void> _addExpense() async {
    final formKey = GlobalKey<FormState>();
    String reason = '';
    int amount = 0;
    final amountCtrl = TextEditingController();
    DateTime date = DateTime.now();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Nouvelle Dépense'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    decoration: const InputDecoration(
                        labelText: 'Raison / Description'),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Requis' : null,
                    onSaved: (v) => reason = v ?? '',
                  ),
                  const SizedBox(height: 12),
                  FormattedNumberField(
                    controller: amountCtrl,
                    label: 'Montant (FCFA)',
                    validator: (v) =>
                        (v == null || v <= 0) ? 'Montant invalide' : null,
                    onChanged: (v) => amount = v ?? 0,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    title: const Text('Date'),
                    subtitle: Text(_formatDate(date)),
                    trailing: const Icon(CoutureIcons.calendarBlank),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(2026),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setDlgState(() => date = picked);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  formKey.currentState!.save();
                  try {
                    await _repo.createExpense(
                      reason: reason,
                      amount: amount,
                      spentAt: _formatDate(date),
                    );
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    _loadFinanceData();
                  } catch (e) {
                    if (!ctx.mounted) return;
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                          content: Text('Impossible : $e'),
                          backgroundColor: CouturePalette.terracottaDeep),
                    );
                  }
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _correctExpense(Expense expense) async {
    final formKey = GlobalKey<FormState>();
    int newAmount = expense.amount;
    final newAmountCtrl =
        TextEditingController(text: formatThousands(expense.amount));
    String reason = '';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Corriger Dépense'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  'Dépense d\'origine: ${expense.reason} (${formatFcfa(expense.amount)})'),
              const SizedBox(height: 12),
              FormattedNumberField(
                controller: newAmountCtrl,
                label: 'Nouveau montant (0 pour annuler/supprimer)',
                validator: (v) => (v == null || v < 0) ? 'Invalide' : null,
                onChanged: (v) => newAmount = v ?? 0,
              ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: const InputDecoration(
                    labelText: 'Raison de correction (Obligatoire)'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Raison requise' : null,
                onSaved: (v) => reason = v ?? '',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                formKey.currentState!.save();
                try {
                  await _repo.correctExpense(expense.id,
                      newAmount: newAmount, reason: reason);
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  _loadFinanceData();
                } catch (e) {
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                        content: Text('Impossible : $e'),
                        backgroundColor: CouturePalette.terracottaDeep),
                  );
                }
              }
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // Secretary access block
    if (auth.isSecretary) {
      return const CoutureScaffold(
        title: 'Finances',
        child: CoutureEmpty(
          icon: CoutureIcons.prohibit,
          tone: CoutureTone.urgent,
          title: 'Réservé au Gérant',
          message: 'Cette partie de l\'application ne vous est pas ouverte.',
        ),
      );
    }

    final shopName = context.watch<ShopSettingsProvider>().shopName;

    final CoutureScheme c = CoutureScheme.of(context);

    return CoutureScaffold(
      title: 'Finances',
      subtitle: shopName.isEmpty ? 'L\'argent de la boutique' : shopName,
      actions: <Widget>[
        CoutureBandAction(
          icon: CoutureIcons.chartBar,
          tooltip: 'Rapports',
          onPressed: () => context.push('/admin/reports'),
        ),
        CoutureBandAction(
          icon: CoutureIcons.refresh,
          tooltip: 'Actualiser',
          onPressed: _loadFinanceData,
        ),
      ],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? const CoutureEmpty(
                  icon: CoutureIcons.warningCircle,
                  tone: CoutureTone.urgent,
                  title: 'Les chiffres ne s\'affichent pas',
                  message:
                      'Vérifiez la connexion, puis appuyez sur Actualiser.',
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(CouturePalette.s4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Period presets
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: <Widget>[
                            for (final p
                                in const <({String key, String label})>[
                              (key: 'jour', label: 'Aujourd\'hui'),
                              (key: 'semaine', label: 'Cette semaine'),
                              (key: 'mois', label: 'Ce mois'),
                              (key: 'annee', label: 'Cette année'),
                            ])
                              Padding(
                                padding: const EdgeInsets.only(
                                    right: CouturePalette.s2),
                                child: CoutureFilterChip(
                                  label: p.label,
                                  selected: _period == p.key,
                                  onTap: () => _setPeriod(p.key),
                                ),
                              ),
                            CoutureFilterChip(
                              icon: CoutureIcons.calendarBlank,
                              label: 'Choisir',
                              selected: _period == 'perso',
                              onTap: () {
                                setState(() => _period = 'perso');
                                _selectDateRange();
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Date range summary header
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                'Du ${_formatDate(_fromDate)} au ${_formatDate(_toDate)}',
                                style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: c.inkSoft),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _selectDateRange,
                              style: TextButton.styleFrom(
                                  foregroundColor: c.iconInk),
                              icon: const Icon(CoutureIcons.pencil, size: 14),
                              label: const Text('Changer'),
                            ),
                          ],
                        ),
                      ),

                      if (_summary != null) ...[
                        // KPI cards
                        _buildKpiCard(
                          title: 'Argent reçu',
                          value: formatFcfa(_summary!.totalRevenue),
                          color: c.goodInk,
                          icon: CoutureIcons.wallet,
                          details:
                              'Commandes des clients: ${formatFcfa(_summary!.ordersRevenue)}\n'
                              'Ventes en boutique: ${formatFcfa(_summary!.salesRevenue)}\n'
                              'Ventes en gros: ${formatFcfa(_summary!.wholesaleRevenue)}',
                        ),
                        const SizedBox(height: 16),
                        _buildKpiCard(
                          title: 'Argent sorti',
                          value: formatFcfa(_summary!.totalCosts),
                          color: c.urgentText,
                          icon: CoutureIcons.receipt,
                          // The cost of the goods sold belongs in this list:
                          // without it the four lines never added up to the
                          // total printed just above them.
                          details:
                              'Achat de la marchandise vendue: ${formatFcfa(_summary!.costOfGoodsSold)}\n'
                              'Paie des couturiers: ${formatFcfa(_summary!.tailorWages)}\n'
                              'Salaires du personnel: ${formatFcfa(_summary!.salaries)}\n'
                              'Autres dépenses: ${formatFcfa(_summary!.expenses)}',
                        ),
                        const SizedBox(height: 16),
                        _buildKpiCard(
                          title: 'Ce qui reste',
                          value: formatFcfa(_summary!.netProfit),
                          color: _summary!.netProfit >= 0
                              ? c.iconInk
                              : c.urgentText,
                          icon: CoutureIcons.chartBar,
                          details:
                              'L\'argent qui reste après toutes les dépenses.',
                        ),
                      ],

                      const SizedBox(height: 20),
                      Text('LE DÉTAIL',
                          style: CouturePalette.sectionLabel
                              .copyWith(color: c.inkFaint)),
                      const SizedBox(height: CouturePalette.s2),
                      // "Commandes" lists the money actually COLLECTED, not
                      // the price of the orders: the card above is cash-basis,
                      // and listing order totals under it meant a delivered
                      // order with an unpaid balance looked like money in hand.
                      _detailSection(
                          'Argent reçu — commandes des clients',
                          _detail?.orders ?? FinanceCategory.empty,
                          CoutureIcons.clipboardText,
                          c.goodInk),
                      _detailSection(
                          'Argent reçu — ventes en boutique',
                          _detail?.sales ?? FinanceCategory.empty,
                          CoutureIcons.shoppingBag,
                          c.goodInk),
                      _detailSection(
                          'Argent sorti — paie des couturiers',
                          _detail?.wages ?? FinanceCategory.empty,
                          CoutureIcons.scissors,
                          c.urgentText),
                      _detailSection(
                          'Argent sorti — autres dépenses',
                          _detail?.expenses ?? FinanceCategory.empty,
                          CoutureIcons.receipt,
                          c.urgentText),

                      const SizedBox(height: 24),

                      // Expense Title row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'LES DÉPENSES',
                            style: CouturePalette.sectionLabel
                                .copyWith(color: c.inkFaint),
                          ),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: c.iconInk,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 40),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: CouturePalette.s4),
                            ),
                            icon: const Icon(CoutureIcons.plus, size: 16),
                            label: const Text('Ajouter'),
                            onPressed: _addExpense,
                          )
                        ],
                      ),

                      const SizedBox(height: 12),

                      _expenses.isEmpty
                          ? Card(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Center(
                                    child: Text('Aucune dépense notée.',
                                        style: TextStyle(
                                            fontSize: 13, color: c.inkFaint))),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _expenses.length,
                              itemBuilder: (context, index) {
                                final exp = _expenses[index];
                                return Card(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: c.urgentWash,
                                      child: Icon(CoutureIcons.receipt,
                                          color: c.urgentText, size: 19),
                                    ),
                                    title: Text(exp.reason,
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: c.ink)),
                                    subtitle: Text(exp.spentAt,
                                        style: TextStyle(
                                            fontSize: 12.5, color: c.inkSoft)),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '-${formatFcfa(exp.amount)}',
                                          style: TextStyle(
                                              color: c.urgentText,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: Icon(CoutureIcons.pencil,
                                              color: c.inkSoft, size: 18),
                                          tooltip: 'Corriger / Annuler',
                                          onPressed: () => _correctExpense(exp),
                                        )
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
    required String details,
  }) {
    final CoutureScheme c = CoutureScheme.of(context);
    return CoutureCard(
      padding: const EdgeInsets.all(CouturePalette.s4 + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 23),
          ),
          const SizedBox(width: CouturePalette.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: c.inkSoft)),
                const SizedBox(height: 2),
                // The figure is the point of the card: nothing else on it is
                // allowed to be this size.
                Text(value,
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: c.ink,
                        height: 1.15)),
                const SizedBox(height: CouturePalette.s2),
                Text(details,
                    style: TextStyle(
                        fontSize: 12, color: c.inkSoft, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
