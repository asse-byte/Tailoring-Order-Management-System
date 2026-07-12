import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/formatted_number_field.dart';
import '../../data/staff_repository.dart';

/// "Staff" — monthly (non-tailor) employees only: secretary, guard, cleaner…
/// Manager-only (salary data). Tailors live in the separate "Tailleurs"
/// screen and are always paid per piece.
class MonthlyStaffScreen extends StatefulWidget {
  const MonthlyStaffScreen({super.key});

  @override
  State<MonthlyStaffScreen> createState() => _MonthlyStaffScreenState();
}

class _MonthlyStaffScreenState extends State<MonthlyStaffScreen> {
  final StaffRepository _repo = StaffRepository();
  List<StaffPayInfo> _staff = <StaffPayInfo>[];
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
      final all = await _repo.listPayInfo();
      setState(() => _staff = all.where((s) => s.type == 'autre').toList());
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.error : AppColors.success,
    ));
  }

  Future<void> _addStaff() async {
    final formKey = GlobalKey<FormState>();
    String name = '';
    String phone = '';
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Nouvel employé (mensuel)'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                decoration: const InputDecoration(labelText: 'Nom complet'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                onSaved: (v) => name = v?.trim() ?? '',
              ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Téléphone'),
                keyboardType: TextInputType.phone,
                onSaved: (v) => phone = v?.trim() ?? '',
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              formKey.currentState!.save();
              try {
                await _repo.createStaff(fullName: name, phone: phone, type: 'autre');
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _load();
              } catch (e) {
                if (ctx.mounted) _toast('Erreur: $e', error: true);
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  Future<void> _editPay(StaffPayInfo member) async {
    final formKey = GlobalKey<FormState>();
    int salary = member.monthlySalary ?? 0;
    int dueDay = member.salaryDueDay ?? 1;
    final salaryCtrl = TextEditingController(text: formatThousands(salary));

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Salaire — ${member.fullName}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              FormattedNumberField(
                controller: salaryCtrl,
                label: 'Salaire mensuel (FCFA)',
                validator: (v) => v == null ? 'Invalide' : null,
                onChanged: (v) => salary = v ?? 0,
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: dueDay.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Jour de versement (1 - 31)'),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return (n == null || n < 1 || n > 31) ? 'Jour invalide' : null;
                },
                onSaved: (v) => dueDay = int.tryParse(v ?? '') ?? 1,
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              formKey.currentState!.save();
              try {
                await _repo.updatePay(member.staffId,
                    monthlySalary: salary, salaryDueDay: dueDay);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _load();
              } catch (e) {
                if (ctx.mounted) _toast('Erreur: $e', error: true);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Staff (mensuel)')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Erreur: $_error'))
              : _staff.isEmpty
                  ? const Center(child: Text('Aucun employé mensuel.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _staff.length,
                        itemBuilder: (context, i) {
                          final m = _staff[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    AppColors.primary.withValues(alpha: 0.12),
                                child: const Icon(Icons.person_rounded,
                                    color: AppColors.primary),
                              ),
                              title: Text(m.fullName,
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                'Salaire: ${formatFcfa(m.monthlySalary ?? 0)} '
                                '(le ${m.salaryDueDay ?? 1})\nTél: ${m.phone}',
                              ),
                              isThreeLine: true,
                              trailing: IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: 'Modifier le salaire',
                                onPressed: () => _editPay(m),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addStaff,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Employé', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
