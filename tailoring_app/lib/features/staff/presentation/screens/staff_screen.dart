import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/data/mock_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  List<Map<String, dynamic>> _staff = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    setState(() => _loading = true);
    final s = await MockDatabase.instance.getStaff();
    setState(() {
      _staff = s;
      _loading = false;
    });
  }

  Future<void> _addStaffMember() async {
    final formKey = GlobalKey<FormState>();
    String name = '';
    String phone = '';
    String role = 'tailor';
    double pieceRate = 5000.0;
    double monthlySalary = 120000.0;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Nouveau Membre / New Staff'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Nom / Name'),
                    validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                    onSaved: (v) => name = v ?? '',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Téléphone'),
                    onSaved: (v) => phone = v ?? '',
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: role,
                    decoration: const InputDecoration(labelText: 'Rôle'),
                    items: const [
                      DropdownMenuItem(value: 'tailor', child: Text('الخياطين / Tailor')),
                      DropdownMenuItem(value: 'non_tailor', child: Text('آخرين / Autre (Mensuel)')),
                    ],
                    onChanged: (v) => setDlgState(() => role = v ?? 'tailor'),
                  ),
                  const SizedBox(height: 12),
                  if (role == 'tailor')
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Tarif par costume / Rate per Suit (CFA)'),
                      initialValue: '5000',
                      keyboardType: TextInputType.number,
                      validator: (v) => v == null || double.tryParse(v) == null ? 'Invalide' : null,
                      onSaved: (v) => pieceRate = double.tryParse(v ?? '') ?? 5000.0,
                    )
                  else
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Salaire Mensuel / Monthly Salary (CFA)'),
                      initialValue: '120000',
                      keyboardType: TextInputType.number,
                      validator: (v) => v == null || double.tryParse(v) == null ? 'Invalide' : null,
                      onSaved: (v) => monthlySalary = double.tryParse(v ?? '') ?? 120000.0,
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
                  final newStaff = {
                    'id': 'st_${DateTime.now().millisecondsSinceEpoch}',
                    'name': name,
                    'phone': phone,
                    'role': role,
                    'pieceRate': role == 'tailor' ? pieceRate : 0.0,
                    'monthlySalary': role == 'non_tailor' ? monthlySalary : 0.0,
                    'suitsSewnToday': 0,
                    'suitsHistory': {
                      'Monday': 0,
                      'Tuesday': 0,
                      'Wednesday': 0,
                      'Thursday': 0,
                      'Friday': 0,
                      'Saturday': 0,
                      'Sunday': 0,
                    }
                  };
                  await MockDatabase.instance.saveStaffMember(newStaff);
                  Navigator.pop(ctx);
                  _loadStaff();
                }
              },
              child: const Text('Sauvegarder'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _recordWork(Map<String, dynamic> member, bool isSec) async {
    final Map<String, dynamic> history = Map<String, dynamic>.from(member['suitsHistory'] ?? {});
    final List<String> days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          int calculateTotalSuits() {
            int tot = 0;
            for (final d in days) {
              tot += int.tryParse(history[d]?.toString() ?? '0') ?? 0;
            }
            return tot;
          }
          final double rate = (member['pieceRate'] as num?)?.toDouble() ?? 0.0;
          final int totalSuits = calculateTotalSuits();
          final double totalWage = totalSuits * rate;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Travail / Work - ${member['name']}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...days.map((day) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(day, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 24),
                        SizedBox(
                          width: 80,
                          child: TextFormField(
                            initialValue: (history[day] ?? 0).toString(),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(hintText: '0'),
                            onChanged: (v) {
                              setDlgState(() {
                                history[day] = int.tryParse(v) ?? 0;
                              });
                            },
                          ),
                        ),
                      ],
                    );
                  }),
                  const Divider(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total complet / Total Suits:'),
                      Text('$totalSuits', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  if (!isSec) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tarif / Piece Rate:'),
                        Text('$rate CFA', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total hebdomadaire / Weekly Wage:'),
                        Text(
                          '$totalWage CFA',
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 18),
                        ),
                      ],
                    ),
                  ]
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Fermer / Close'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final updatedMember = Map<String, dynamic>.from(member);
                  updatedMember['suitsHistory'] = history;
                  updatedMember['suitsSewnToday'] = history['Saturday'] ?? 0; // simple mock update
                  await MockDatabase.instance.saveStaffMember(updatedMember);
                  Navigator.pop(ctx);
                  _loadStaff();
                },
                child: const Text('Enregistrer / Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isSec = auth.isSecretary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personnel / Staff'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadStaff,
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _staff.length,
              itemBuilder: (context, index) {
                final s = _staff[index];
                final isTailor = s['role'] == 'tailor';
                
                // Calculate weekly suits if tailor
                int totalSuits = 0;
                if (isTailor) {
                  final history = s['suitsHistory'] as Map<String, dynamic>? ?? {};
                  history.forEach((k, v) => totalSuits += int.tryParse(v.toString()) ?? 0);
                }

                final double rate = (s['pieceRate'] as num?)?.toDouble() ?? 0.0;
                final double weeklyWage = totalSuits * rate;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isTailor ? Colors.teal.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                      child: Icon(
                        isTailor ? Icons.content_cut_rounded : Icons.person_rounded,
                        color: isTailor ? Colors.teal : Colors.orange,
                      ),
                    ),
                    title: Text(s['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      isTailor
                          ? 'Maitre Tailleur (خياط)\nSuits Sewn: $totalSuits'
                          : 'Autre personnel (غير خياط)',
                    ),
                    trailing: isSec
                        ? (isTailor
                            ? ElevatedButton.icon(
                                icon: const Icon(Icons.edit_note, size: 16),
                                label: const Text('Suits'),
                                onPressed: () => _recordWork(s, isSec),
                              )
                            : const SizedBox())
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (isTailor) ...[
                                Text(
                                  '$weeklyWage CFA',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text('Hebdo / Weekly', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              ] else ...[
                                Text(
                                  '${s['monthlySalary']} CFA',
                                  style: const TextStyle(
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text('Mensuel / Monthly', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              ],
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isTailor)
                                    IconButton(
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(Icons.edit_note, color: Colors.blue),
                                      onPressed: () => _recordWork(s, isSec),
                                    ),
                                  IconButton(
                                    constraints: const BoxConstraints(),
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                                    onPressed: () async {
                                      await MockDatabase.instance.deleteStaffMember(s['id']);
                                      _loadStaff();
                                    },
                                  ),
                                ],
                              )
                            ],
                          ),
                  ),
                );
              },
            ),
      floatingActionButton: isSec
          ? null
          : FloatingActionButton(
              onPressed: _addStaffMember,
              child: const Icon(Icons.add_rounded),
            ),
    );
  }
}
