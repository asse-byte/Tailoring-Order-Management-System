import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/confirm_delete_dialog.dart';
import '../../../../core/widgets/formatted_number_field.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../settings/presentation/providers/shop_settings_provider.dart';
import '../../data/salary_payments_repository.dart';
import '../../data/salary_receipt_service.dart';
import '../../data/staff_repository.dart';

/// "Staff" — monthly (non-tailor) employees only: secretary, guard, cleaner…
/// The MANAGER sees and manages salaries + payments. The SECRETARY may manage
/// the roster (add/edit/delete the person, name, phone) but never sees any
/// salary or payment (financial isolation — CLAUDE.md rule 1). Tailors live in
/// the separate "Tailleurs" screen and are always paid per piece.
class MonthlyStaffScreen extends StatefulWidget {
  const MonthlyStaffScreen({super.key});

  @override
  State<MonthlyStaffScreen> createState() => _MonthlyStaffScreenState();
}

class _MonthlyStaffScreenState extends State<MonthlyStaffScreen> {
  final StaffRepository _repo = StaffRepository();
  final SalaryPaymentsRepository _payRepo = SalaryPaymentsRepository();
  List<StaffPayInfo> _staff = <StaffPayInfo>[];      // manager (with salary)
  List<StaffContact> _contacts = <StaffContact>[];   // secretary (roster only)
  bool _isSec = false;
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
    _isSec = context.read<AuthProvider>().isSecretary;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_isSec) {
        // Roster only — no pay endpoint (that would be a 403 anyway).
        final all = await _repo.listContacts();
        setState(() => _contacts = all.where((s) => s.type == 'autre').toList());
      } else {
        final all = await _repo.listPayInfo();
        setState(() => _staff = all.where((s) => s.type == 'autre').toList());
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Roster edit for the secretary — name + phone + delete, no salary.
  Future<void> _editContact(StaffContact c) async {
    final formKey = GlobalKey<FormState>();
    String name = c.fullName;
    String phone = c.phone;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: <Widget>[
            const Expanded(child: Text('Modifier l\'employé')),
            IconButton(
              tooltip: 'Supprimer définitivement',
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              onPressed: () async {
                final bool ok = await confirmDeleteByTyping(
                  ctx,
                  itemName: c.fullName,
                  itemLabel: 'cet employé',
                  historyNote: 'Les paiements de salaire déjà enregistrés '
                      'restent conservés dans le registre (au nom mémorisé). '
                      'Seule sa fiche est supprimée.',
                );
                if (!ok) return;
                try {
                  await _repo.deleteStaff(c.id);
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  _load();
                  _toast('Employé supprimé.');
                } catch (e) {
                  if (ctx.mounted) _toast('Erreur: $e', error: true);
                }
              },
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                initialValue: name,
                decoration: const InputDecoration(labelText: 'Nom complet'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                onSaved: (v) => name = v?.trim() ?? '',
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: phone,
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
                await _repo.updateStaff(c.id,
                    fullName: name, phone: phone, type: 'autre', active: c.active);
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
    String name = member.fullName;
    String phone = member.phone;
    String frequency = member.payFrequency;
    int monthlySalary = member.monthlySalary ?? 0;
    int weeklySalary = member.weeklySalary ?? 0;
    int dueDay = member.salaryDueDay ?? 1;

    final monthlyCtrl = TextEditingController(text: formatThousands(monthlySalary));
    final weeklyCtrl = TextEditingController(text: formatThousands(weeklySalary));

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: <Widget>[
              Expanded(child: Text('Modifier l\'employé — ${member.fullName}')),
              IconButton(
                tooltip: 'Supprimer définitivement',
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                onPressed: () async {
                  final bool ok = await confirmDeleteByTyping(
                    ctx,
                    itemName: member.fullName,
                    itemLabel: 'cet employé',
                    historyNote: 'Les paiements de salaire déjà enregistrés restent conservés.',
                  );
                  if (!ok) return;
                  try {
                    await _repo.deleteStaff(member.staffId);
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    _load();
                    _toast('Employé supprimé.');
                  } catch (e) {
                    if (ctx.mounted) _toast('Erreur: $e', error: true);
                  }
                },
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextFormField(
                    initialValue: name,
                    decoration: const InputDecoration(labelText: 'Nom complet'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                    onSaved: (v) => name = v?.trim() ?? '',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: phone,
                    decoration: const InputDecoration(labelText: 'Téléphone'),
                    keyboardType: TextInputType.phone,
                    onSaved: (v) => phone = v?.trim() ?? '',
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: frequency,
                    decoration: const InputDecoration(labelText: 'Fréquence de paiement'),
                    items: const [
                      DropdownMenuItem(value: 'mensuel', child: Text('Mensuel (Fin de mois)')),
                      DropdownMenuItem(value: 'hebdo', child: Text('Hebdomadaire (Fin de semaine / Samedi)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDlg(() => frequency = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  if (frequency == 'mensuel') ...[
                    FormattedNumberField(
                      controller: monthlyCtrl,
                      label: 'Salaire Mensuel (FCFA)',
                      validator: (v) => v == null ? 'Invalide' : null,
                      onChanged: (v) => monthlySalary = v ?? 0,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: dueDay.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Jour du mois (1 - 31)'),
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        return (n == null || n < 1 || n > 31) ? 'Jour invalide' : null;
                      },
                      onSaved: (v) => dueDay = int.tryParse(v ?? '') ?? 1,
                    ),
                  ] else ...[
                    FormattedNumberField(
                      controller: weeklyCtrl,
                      label: 'Salaire Hebdomadaire (FCFA/semaine)',
                      validator: (v) => v == null ? 'Invalide' : null,
                      onChanged: (v) => weeklySalary = v ?? 0,
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                formKey.currentState!.save();
                try {
                  await _repo.updateStaff(
                    member.staffId,
                    fullName: name,
                    phone: phone,
                    type: 'autre',
                    active: member.active,
                  );
                  await _repo.updatePay(
                    member.staffId,
                    monthlySalary: frequency == 'mensuel' ? monthlySalary : 0,
                    salaryDueDay: frequency == 'mensuel' ? dueDay : null,
                    weeklySalary: frequency == 'hebdo' ? weeklySalary : 0,
                    payFrequency: frequency,
                  );
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  _load();
                  _toast('Employé mis à jour.');
                } catch (e) {
                  if (ctx.mounted) _toast('Erreur: $e', error: true);
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
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

  /// Per-employee sheet: interactive payment plan hub (Mensuel vs Hebdomadaire).
  Future<void> _openPaymentSheet(StaffPayInfo member) async {
    int year = DateTime.now().year;
    String selectedPlan = member.payFrequency; // 'mensuel' | 'hebdo'
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

          SalaryPayment? paymentForMonth(int monthIdx) {
            final String period = '$year-${(monthIdx + 1).toString().padLeft(2, '0')}';
            for (final SalaryPayment p in payments) {
              if (p.period == period && !p.voided) return p;
            }
            return null;
          }

          SalaryPayment? paymentForWeek(int weekNum) {
            final String period = '$year-W${weekNum.toString().padLeft(2, '0')}';
            for (final SalaryPayment p in payments) {
              if (p.period == period && !p.voided) return p;
            }
            return null;
          }

          final int paidMonthCount = List.generate(12, (i) => paymentForMonth(i)).whereType<SalaryPayment>().length;
          final int paidWeekCount = List.generate(52, (i) => paymentForWeek(i + 1)).whereType<SalaryPayment>().length;

          return SafeArea(
            child: DraggableScrollableSheet(
              initialChildSize: 0.90,
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
                    Row(
                      children: <Widget>[
                        CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                          child: const Icon(Icons.person_rounded, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(member.fullName, style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                              Text(
                                selectedPlan == 'hebdo'
                                    ? 'Salaire Hebdomadaire: ${formatFcfa(member.weeklySalary ?? 0)} / semaine'
                                    : 'Salaire Mensuel: ${formatFcfa(member.monthlySalary ?? 0)} (le ${member.salaryDueDay ?? 1})',
                                style: Theme.of(ctx).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Modifier Salaire / Fréquence',
                          icon: const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 28),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            _editPay(member);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Plan Switcher (Mensuel vs Hebdomadaire)
                    Center(
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'mensuel',
                            label: Text('Plan Mensuel'),
                            icon: Icon(Icons.calendar_month_rounded),
                          ),
                          ButtonSegment(
                            value: 'hebdo',
                            label: Text('Plan Hebdomadaire'),
                            icon: Icon(Icons.view_week_rounded),
                          ),
                        ],
                        selected: {selectedPlan},
                        onSelectionChanged: (val) {
                          setSheet(() => selectedPlan = val.first);
                        },
                      ),
                    ),
                    const Divider(height: 20),

                    Row(
                      children: <Widget>[
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded),
                          onPressed: () { year -= 1; load(); },
                        ),
                        Expanded(
                          child: Text(
                            selectedPlan == 'hebdo'
                                ? 'Année $year — $paidWeekCount/52 semaines payées'
                                : 'Année $year — $paidMonthCount/12 mois payés',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded),
                          onPressed: () { year += 1; load(); },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Expanded(
                      child: loading
                          ? const Center(child: CircularProgressIndicator())
                          : selectedPlan == 'mensuel'
                              ? ListView.separated(
                                  controller: scrollCtrl,
                                  itemCount: 12,
                                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                                  itemBuilder: (ctx, i) {
                                    final SalaryPayment? p = paymentForMonth(i);
                                    final bool paid = p != null;
                                    return Card(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      child: ListTile(
                                        leading: Icon(
                                          paid ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                          color: paid ? AppColors.success : AppColors.textSecondary,
                                        ),
                                        title: Text(_monthNames[i], style: const TextStyle(fontWeight: FontWeight.w600)),
                                        subtitle: paid
                                            ? Text('Payé le ${p.paidAt} · ${formatFcfa(p.amount)}')
                                            : const Text('Non payé'),
                                        trailing: paid
                                            ? PopupMenuButton<String>(
                                                onSelected: (v) {
                                                  if (v == 'receipt') {
                                                    _printReceipt(member, p, '${_monthNames[i]} $year');
                                                  } else if (v == 'void') {
                                                    _voidPayment(p, load);
                                                  }
                                                },
                                                itemBuilder: (_) => const [
                                                  PopupMenuItem(value: 'receipt', child: Text('Imprimer le reçu')),
                                                  PopupMenuItem(value: 'void', child: Text('Annuler le paiement')),
                                                ],
                                              )
                                            : ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  minimumSize: const Size(0, 40),
                                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                ),
                                                onPressed: () => _recordPayment(member, i, year, load),
                                                child: const Text('Payer'),
                                              ),
                                      ),
                                    );
                                  },
                                )
                              : ListView.separated(
                                  controller: scrollCtrl,
                                  itemCount: 52,
                                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                                  itemBuilder: (ctx, i) {
                                    final int weekNum = i + 1;
                                    final SalaryPayment? p = paymentForWeek(weekNum);
                                    final bool paid = p != null;

                                    // ISO Week Date Range calculation
                                    final jan4 = DateTime(year, 1, 4);
                                    final firstMonday = jan4.subtract(Duration(days: jan4.weekday - 1));
                                    final weekStart = firstMonday.add(Duration(days: (weekNum - 1) * 7));
                                    final weekEnd = weekStart.add(const Duration(days: 6));
                                    final String rangeStr = '${weekStart.day.toString().padLeft(2, '0')}/${weekStart.month.toString().padLeft(2, '0')} au ${weekEnd.day.toString().padLeft(2, '0')}/${weekEnd.month.toString().padLeft(2, '0')}';

                                    final now = DateTime.now();
                                    final bool isCurrentWeek = (now.year == year) &&
                                        (now.isAfter(weekStart.subtract(const Duration(seconds: 1))) &&
                                         now.isBefore(weekEnd.add(const Duration(days: 1))));

                                    final String weekLabel = 'Semaine $weekNum ($rangeStr)';

                                    return Card(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: isCurrentWeek
                                            ? const BorderSide(color: AppColors.primary, width: 2)
                                            : BorderSide.none,
                                      ),
                                      color: isCurrentWeek
                                          ? AppColors.primary.withValues(alpha: 0.08)
                                          : null,
                                      child: ListTile(
                                        leading: Icon(
                                          paid ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                          color: paid ? AppColors.success : (isCurrentWeek ? AppColors.primary : AppColors.textSecondary),
                                        ),
                                        title: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                weekLabel,
                                                style: TextStyle(
                                                  fontWeight: isCurrentWeek ? FontWeight.bold : FontWeight.w600,
                                                  color: isCurrentWeek ? AppColors.primary : null,
                                                ),
                                              ),
                                            ),
                                            if (isCurrentWeek)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary,
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: const Text(
                                                  'EN COURS',
                                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                                ),
                                              ),
                                          ],
                                        ),
                                        subtitle: paid
                                            ? Text('Payé le ${p.paidAt} · ${formatFcfa(p.amount)}')
                                            : Text(isCurrentWeek ? 'Semaine actuelle — Non payé' : 'Non payé'),
                                        trailing: paid
                                            ? PopupMenuButton<String>(
                                                onSelected: (v) {
                                                  if (v == 'receipt') {
                                                    _printReceipt(member, p, weekLabel);
                                                  } else if (v == 'void') {
                                                    _voidPayment(p, load);
                                                  }
                                                },
                                                itemBuilder: (_) => const [
                                                  PopupMenuItem(value: 'receipt', child: Text('Imprimer le reçu')),
                                                  PopupMenuItem(value: 'void', child: Text('Annuler le paiement')),
                                                ],
                                              )
                                            : ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  minimumSize: const Size(0, 40),
                                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                                  backgroundColor: isCurrentWeek ? AppColors.primary : null,
                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                ),
                                                onPressed: () => _recordWeeklyPayment(member, weekNum, year, load),
                                                child: const Text('Payer Semaine'),
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

  Future<void> _recordWeeklyPayment(
    StaffPayInfo member,
    int weekNum,
    int year,
    Future<void> Function() reload,
  ) async {
    final formKey = GlobalKey<FormState>();
    int amount = member.weeklySalary ?? 0;
    DateTime paidAt = DateTime.now();
    String note = '';
    final amountCtrl = TextEditingController(text: formatThousands(amount));
    final String period = '$year-W${weekNum.toString().padLeft(2, '0')}';
    final String weekLabel = 'Semaine $weekNum ($year)';

    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Payer — $weekLabel'),
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
                  subtitle: Text('${paidAt.day}/${paidAt.month}/${paidAt.year}'),
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
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
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
        kind: 'hebdo',
        amount: amount,
        paidAt: paidStr,
        note: note,
      );
      await reload();
      if (!mounted) return;
      _toast('Paiement hebdo enregistré.');
      final bool? print = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Reçu de paiement'),
          content: const Text('Voulez-vous imprimer le reçu maintenant ?'),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Plus tard')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Imprimer')),
          ],
        ),
      );
      if (print == true) {
        await _printReceipt(member, payment, weekLabel);
      }
    } catch (e) {
      if (mounted) _toast('Erreur: $e', error: true);
    }
  }

  /// Secretary roster list — name + phone only, with edit/delete. No salary,
  /// no payment sheet (financial isolation).
  Widget _buildSecretaryList() {
    if (_contacts.isEmpty) {
      return const Center(child: Text('Aucun employé mensuel.'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _contacts.length,
        itemBuilder: (context, i) {
          final c = _contacts[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: const Icon(Icons.person_rounded, color: AppColors.primary),
              ),
              title: Text(c.fullName,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Tél: ${c.phone}'),
              onTap: () => _editContact(c),
              trailing: IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Modifier',
                onPressed: () => _editContact(c),
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
              : _isSec
                  ? _buildSecretaryList()
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
                                m.payFrequency == 'hebdo'
                                    ? 'Salaire Hebdo: ${formatFcfa(m.weeklySalary ?? 0)} / semaine\nTél: ${m.phone}'
                                    : 'Salaire Mensuel: ${formatFcfa(m.monthlySalary ?? 0)} (le ${m.salaryDueDay ?? 1})\nTél: ${m.phone}',
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
