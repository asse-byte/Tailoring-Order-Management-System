import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/formatted_number_field.dart';
import '../../../settings/presentation/providers/shop_settings_provider.dart';
import '../../data/salary_payments_repository.dart';
import '../../data/salary_receipt_service.dart';
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
  final SalaryPaymentsRepository _payRepo = SalaryPaymentsRepository();
  List<StaffPayInfo> _staff = <StaffPayInfo>[];
  bool _loading = true;
  String? _error;

  static const List<String> _monthNames = <String>[
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet',
    'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
  ];

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

  /// Record a payment for [member] covering month [monthIdx] (0-based) of
  /// [year]; on success offers to print the receipt.
  Future<void> _recordPayment(
    StaffPayInfo member,
    int monthIdx,
    int year,
    Future<void> Function() reload,
  ) async {
    final formKey = GlobalKey<FormState>();
    int amount = member.monthlySalary ?? 0;
    DateTime paidAt = DateTime.now();
    String note = '';
    final amountCtrl = TextEditingController(text: formatThousands(amount));
    final String period = '$year-${(monthIdx + 1).toString().padLeft(2, '0')}';

    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Payer — ${_monthNames[monthIdx]} $year'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                FormattedNumberField(
                  controller: amountCtrl,
                  label: 'Montant payé (FCFA)',
                  validator: (v) => (v == null || v < 0) ? 'Invalide' : null,
                  onChanged: (v) => amount = v ?? 0,
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date de paiement'),
                  subtitle: Text(
                      '${paidAt.day}/${paidAt.month}/${paidAt.year}'),
                  trailing: const Icon(Icons.calendar_month_rounded),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: paidAt,
                      firstDate: DateTime(2026),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setDlg(() => paidAt = picked);
                  },
                ),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Note (optionnel)'),
                  onSaved: (v) => note = v?.trim() ?? '',
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                formKey.currentState!.save();
                Navigator.pop(ctx, true);
              },
              child: const Text('Confirmer le paiement'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      final String paidStr =
          '${paidAt.year}-${paidAt.month.toString().padLeft(2, '0')}-${paidAt.day.toString().padLeft(2, '0')}';
      final SalaryPayment payment = await _payRepo.record(
        staffId: member.staffId,
        period: period,
        kind: 'mensuel',
        amount: amount,
        paidAt: paidStr,
        note: note,
      );
      await reload();
      if (!mounted) return;
      _toast('Paiement enregistré.');
      // Offer the receipt right away.
      final bool? print = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Reçu de paiement'),
          content: const Text('Voulez-vous imprimer le reçu maintenant ?'),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Plus tard')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Imprimer')),
          ],
        ),
      );
      if (print == true) {
        await _printReceipt(member, payment, '${_monthNames[monthIdx]} $year');
      }
    } catch (e) {
      if (mounted) _toast('Erreur: $e', error: true);
    }
  }

  Future<void> _printReceipt(
      StaffPayInfo member, SalaryPayment payment, String periodLabel) async {
    final settings = context.read<ShopSettingsProvider>();
    try {
      await SalaryReceiptService.shareReceipt(
        shopName: settings.shopName,
        staffName: member.fullName,
        staffPhone: member.phone,
        roleLabel: 'Employé mensuel',
        periodLabel: periodLabel,
        amount: payment.amount,
        paidAtLabel: payment.paidAt,
        receiptNo: payment.id.substring(0, 8).toUpperCase(),
        logoUrl: settings.logoUrl,
      );
    } catch (e) {
      if (mounted) _toast('Erreur reçu: $e', error: true);
    }
  }

  Future<void> _voidPayment(
      SalaryPayment payment, Future<void> Function() reload) async {
    final formKey = GlobalKey<FormState>();
    String reason = '';
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Annuler le paiement'),
        content: Form(
          key: formKey,
          child: TextFormField(
            decoration: const InputDecoration(labelText: 'Motif (obligatoire)'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Motif requis' : null,
            onSaved: (v) => reason = v?.trim() ?? '',
          ),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Retour')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              formKey.currentState!.save();
              Navigator.pop(ctx, true);
            },
            child: const Text('Annuler le paiement'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _payRepo.correct(payment.id, voided: true, reason: reason);
      await reload();
      if (mounted) _toast('Paiement annulé.');
    } catch (e) {
      if (mounted) _toast('Erreur: $e', error: true);
    }
  }

  /// Per-employee sheet: a Jan→Dec grid for a year, showing which months are
  /// paid, with actions to pay / print a receipt / void.
  Future<void> _openPaymentSheet(StaffPayInfo member) async {
    int year = DateTime.now().year;
    List<SalaryPayment> payments = <SalaryPayment>[];
    bool loading = true;
    bool started = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Future<void> load() async {
            setSheet(() => loading = true);
            try {
              payments = await _payRepo.forStaffYear(member.staffId, year);
            } catch (_) {
              payments = <SalaryPayment>[];
            }
            if (ctx.mounted) setSheet(() => loading = false);
          }

          if (!started) {
            started = true;
            WidgetsBinding.instance.addPostFrameCallback((_) => load());
          }

          SalaryPayment? paymentFor(int monthIdx) {
            final String period =
                '$year-${(monthIdx + 1).toString().padLeft(2, '0')}';
            for (final SalaryPayment p in payments) {
              if (p.period == period && !p.voided) return p;
            }
            return null;
          }

          final int paidCount =
              List.generate(12, (i) => paymentFor(i)).whereType<SalaryPayment>().length;

          return SafeArea(
            child: DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (ctx, scrollCtrl) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Center(
                      child: Container(
                        height: 4, width: 40,
                        decoration: BoxDecoration(
                          color: Theme.of(ctx).dividerColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(children: <Widget>[
                      CircleAvatar(
                        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                        child: const Icon(Icons.person_rounded,
                            color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(member.fullName,
                                style: Theme.of(ctx).textTheme.titleLarge),
                            Text(
                                'Salaire mensuel: ${formatFcfa(member.monthlySalary ?? 0)}',
                                style: Theme.of(ctx).textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ]),
                    const Divider(),
                    Row(children: <Widget>[
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded),
                        onPressed: () { year -= 1; load(); },
                      ),
                      Expanded(
                        child: Text('Année $year — $paidCount/12 payés',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded),
                        onPressed: () { year += 1; load(); },
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Expanded(
                      child: loading
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.separated(
                              controller: scrollCtrl,
                              itemCount: 12,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 6),
                              itemBuilder: (ctx, i) {
                                final SalaryPayment? p = paymentFor(i);
                                final bool paid = p != null;
                                return Card(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  child: ListTile(
                                    leading: Icon(
                                      paid
                                          ? Icons.check_circle_rounded
                                          : Icons.radio_button_unchecked_rounded,
                                      color: paid
                                          ? AppColors.success
                                          : AppColors.textSecondary,
                                    ),
                                    title: Text(_monthNames[i],
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
                                    subtitle: paid
                                        ? Text(
                                            'Payé le ${p.paidAt} · ${formatFcfa(p.amount)}')
                                        : const Text('Non payé'),
                                    trailing: paid
                                        ? PopupMenuButton<String>(
                                            onSelected: (v) {
                                              if (v == 'receipt') {
                                                _printReceipt(member, p,
                                                    '${_monthNames[i]} $year');
                                              } else if (v == 'void') {
                                                _voidPayment(p, load);
                                              }
                                            },
                                            itemBuilder: (_) => const [
                                              PopupMenuItem(
                                                  value: 'receipt',
                                                  child: Text('Imprimer le reçu')),
                                              PopupMenuItem(
                                                  value: 'void',
                                                  child: Text('Annuler le paiement')),
                                            ],
                                          )
                                        : ElevatedButton(
                                            // The global theme forces buttons to
                                            // full width (Size.fromHeight →
                                            // infinite), which a ListTile trailing
                                            // cannot lay out. Override to size to
                                            // content so it fits in the trailing.
                                            style: ElevatedButton.styleFrom(
                                              minimumSize: const Size(0, 40),
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 16),
                                              tapTargetSize: MaterialTapTargetSize
                                                  .shrinkWrap,
                                            ),
                                            onPressed: () =>
                                                _recordPayment(member, i, year, load),
                                            child: const Text('Payer'),
                                          ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
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
                              onTap: () => _openPaymentSheet(m),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  IconButton(
                                    icon: const Icon(Icons.payments_outlined),
                                    tooltip: 'Paiements mensuels',
                                    onPressed: () => _openPaymentSheet(m),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    tooltip: 'Modifier le salaire',
                                    onPressed: () => _editPay(m),
                                  ),
                                ],
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
