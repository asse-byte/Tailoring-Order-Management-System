import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/data/mock_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  double _productSales = 185000.0; // Seed default product sales revenue
  double _orderRevenues = 0.0;
  double _tailorWages = 0.0;
  double _staffSalaries = 0.0;
  
  List<Map<String, dynamic>> _customExpenses = [
    {'title': 'Sewing Machine Thread & Oil', 'amount': 15000.0, 'date': '2026-07-01'},
    {'title': 'Electricity Bill', 'amount': 45000.0, 'date': '2026-07-02'},
  ];
  
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFinanceData();
  }

  Future<void> _loadFinanceData() async {
    setState(() => _loading = true);
    
    // Calculate order revenues from completed orders
    final orders = MockDatabase.instance.getAllOrders();
    double completedOrdersSum = 0.0;
    for (final o in orders) {
      if (o.status == 'completed') {
        completedOrdersSum += o.price ?? 0.0;
      }
    }

    // Calculate wages from staff
    final staff = await MockDatabase.instance.getStaff();
    double tailorsSum = 0.0;
    double salariedSum = 0.0;
    for (final s in staff) {
      if (s['role'] == 'tailor') {
        int totalSuits = 0;
        final history = s['suitsHistory'] as Map<String, dynamic>? ?? {};
        history.forEach((k, v) => totalSuits += int.tryParse(v.toString()) ?? 0);
        final double rate = (s['pieceRate'] as num?)?.toDouble() ?? 0.0;
        tailorsSum += totalSuits * rate;
      } else {
        salariedSum += (s['monthlySalary'] as num?)?.toDouble() ?? 0.0;
      }
    }

    setState(() {
      _orderRevenues = completedOrdersSum;
      _tailorWages = tailorsSum;
      _staffSalaries = salariedSum;
      _loading = false;
    });
  }

  Future<void> _addExpense() async {
    final formKey = GlobalKey<FormState>();
    String title = '';
    double amount = 0.0;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Nouvelle Dépense / New Expense'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Titre / Description'),
                validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                onSaved: (v) => title = v ?? '',
              ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Montant / Amount (CFA)'),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || double.tryParse(v) == null ? 'Invalide' : null,
                onSaved: (v) => amount = double.tryParse(v ?? '') ?? 0.0,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                formKey.currentState!.save();
                setState(() {
                  _customExpenses.insert(0, {
                    'title': title,
                    'amount': amount,
                    'date': DateTime.now().toIso8601String().substring(0, 10),
                  });
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.isSecretary) {
      return const Scaffold(
        body: Center(child: Text('Accès refusé / Access Denied', style: TextStyle(color: Colors.red, fontSize: 18))),
      );
    }

    final double totalRevenue = _orderRevenues + _productSales;
    
    // Sum custom expenses
    double customExpSum = 0.0;
    for (final e in _customExpenses) {
      customExpSum += e['amount'];
    }
    
    final double totalExpenditure = _tailorWages + _staffSalaries + customExpSum;
    final double netProfit = totalRevenue - totalExpenditure;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comptabilité Financière / Finance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadFinanceData,
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // KPI cards
                  _buildKpiCard(
                    title: 'Revenus Totaux / Total Revenue',
                    value: '$totalRevenue CFA',
                    color: Colors.green,
                    icon: Icons.trending_up_rounded,
                    details: 'Commandes / Orders: $_orderRevenues CFA\nProduits / Products: $_productSales CFA',
                  ),
                  const SizedBox(height: 16),
                  _buildKpiCard(
                    title: 'Dépenses Totales / Total Expenditure',
                    value: '$totalExpenditure CFA',
                    color: Colors.red,
                    icon: Icons.trending_down_rounded,
                    details: 'Salaires / Wages: ${_tailorWages + _staffSalaries} CFA\nFrais de fonctionnement / Operations: $customExpSum CFA',
                  ),
                  const SizedBox(height: 16),
                  _buildKpiCard(
                    title: 'Bénéfice Net / Net Profit',
                    value: '$netProfit CFA',
                    color: netProfit >= 0 ? Colors.teal : Colors.orange,
                    icon: Icons.account_balance_rounded,
                    details: 'Solde en caisse disponible / Cash Balance',
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Dépenses Opérationnelles / Expenses',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Dépense'),
                        onPressed: _addExpense,
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._customExpenses.map((exp) {
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.red.withOpacity(0.1),
                          child: const Icon(Icons.money_off_rounded, color: Colors.red),
                        ),
                        title: Text(exp['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(exp['date']),
                        trailing: Text(
                          '-${exp['amount']} CFA',
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    );
                  }),
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
            colors: [color.withOpacity(0.12), color.withOpacity(0.02)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.2),
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
