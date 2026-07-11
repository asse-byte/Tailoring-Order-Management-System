import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  
  // Date range state: default to current month
  DateTime _fromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _toDate = DateTime.now();

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
      
      final sum = await _repo.getSummary(from: fromStr, to: toStr);
      final expList = await _repo.listExpenses();

      setState(() {
        _summary = sum;
        _expenses = expList;
      });
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _loading = false);
    }
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Nouvelle Dépense'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Raison / Description'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
                    onSaved: (v) => reason = v ?? '',
                  ),
                  const SizedBox(height: 12),
                  FormattedNumberField(
                    controller: amountCtrl,
                    label: 'Montant (FCFA)',
                    validator: (v) => (v == null || v <= 0) ? 'Montant invalide' : null,
                    onChanged: (v) => amount = v ?? 0,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    title: const Text('Date'),
                    subtitle: Text(_formatDate(date)),
                    trailing: const Icon(Icons.calendar_month_rounded),
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
                      SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
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
    final newAmountCtrl = TextEditingController(text: formatThousands(expense.amount));
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
              Text('Dépense d\'origine: ${expense.reason} (${formatFcfa(expense.amount)})'),
              const SizedBox(height: 12),
              FormattedNumberField(
                controller: newAmountCtrl,
                label: 'Nouveau montant (0 pour annuler/supprimer)',
                validator: (v) => (v == null || v < 0) ? 'Invalide' : null,
                onChanged: (v) => newAmount = v ?? 0,
              ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Raison de correction (Obligatoire)'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Raison requise' : null,
                onSaved: (v) => reason = v ?? '',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                formKey.currentState!.save();
                try {
                  await _repo.correctExpense(expense.id, newAmount: newAmount, reason: reason);
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  _loadFinanceData();
                } catch (e) {
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
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
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_rounded, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(
                'Accès refusé - Réservé au Gérant',
                style: TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    final shopName = context.watch<ShopSettingsProvider>().shopName;

    return Scaffold(
      appBar: AppBar(
        title: Text('$shopName - Comptabilité'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range_rounded),
            tooltip: 'Filtrer les dates',
            onPressed: _selectDateRange,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadFinanceData,
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Erreur: $_error'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date range summary header
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Période: ${_formatDate(_fromDate)} au ${_formatDate(_toDate)}',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]),
                            ),
                            TextButton.icon(
                              onPressed: _selectDateRange,
                              icon: const Icon(Icons.edit_rounded, size: 14),
                              label: const Text('Modifier'),
                            ),
                          ],
                        ),
                      ),

                      if (_summary != null) ...[
                        // KPI cards
                        _buildKpiCard(
                          title: 'Revenus Totaux',
                          value: formatFcfa(_summary!.totalRevenue),
                          color: Colors.green,
                          icon: Icons.trending_up_rounded,
                          details: 'Commandes: ${formatFcfa(_summary!.ordersRevenue)}\nVentes Comptoir: ${formatFcfa(_summary!.salesRevenue)}',
                        ),
                        const SizedBox(height: 16),
                        _buildKpiCard(
                          title: 'Dépenses & Coûts',
                          value: formatFcfa(_summary!.totalCosts),
                          color: Colors.red,
                          icon: Icons.trending_down_rounded,
                          details: 'Salaires (Mensuels): ${formatFcfa(_summary!.salaries)}\nMain d\'œuvre (Pièce): ${formatFcfa(_summary!.tailorWages)}\nFrais & Dépenses: ${formatFcfa(_summary!.expenses)}',
                        ),
                        const SizedBox(height: 16),
                        _buildKpiCard(
                          title: 'Bénéfice Net',
                          value: formatFcfa(_summary!.netProfit),
                          color: _summary!.netProfit >= 0 ? Colors.teal : Colors.orange,
                          icon: Icons.account_balance_rounded,
                          details: 'Indicateur de rentabilité nette sur la période.',
                        ),
                      ],
                      
                      const SizedBox(height: 24),
                      
                      // Expense Title row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Dépenses Opérationnelles',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(0, 40),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Dépense'),
                            onPressed: _addExpense,
                          )
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      _expenses.isEmpty
                          ? const Card(
                              child: Padding(
                                padding: EdgeInsets.all(24.0),
                                child: Center(child: Text('Aucune dépense enregistrée.')),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _expenses.length,
                              itemBuilder: (context, index) {
                                final exp = _expenses[index];
                                return Card(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.red.withValues(alpha: 0.1),
                                      child: const Icon(Icons.money_off_rounded, color: Colors.red),
                                    ),
                                    title: Text(exp.reason, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text(exp.spentAt),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '-${formatFcfa(exp.amount)}',
                                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.edit_note_rounded, color: Colors.orange),
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
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.12), color.withValues(alpha: 0.02)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.2),
              radius: 28,
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(details, style: TextStyle(fontSize: 12, color: Colors.grey[700], height: 1.3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
