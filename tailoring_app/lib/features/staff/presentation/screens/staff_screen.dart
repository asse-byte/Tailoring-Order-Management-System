import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/garment_types.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/formatted_number_field.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../orders/data/orders_repository.dart';
import '../../../orders/domain/entities/order.dart';
import '../../data/staff_repository.dart';
import '../../../settings/presentation/providers/shop_settings_provider.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  final StaffRepository _repo = StaffRepository();

  List<StaffContact> _contacts = [];
  List<StaffPayInfo> _payInfoList = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  /// ISO-8601 week id (e.g. 2026-W28) — matches the backend so the weekly
  /// detail returns the right entries. Weeks run Monday→Sunday.
  String _getWeekId(DateTime date) {
    final DateTime d = DateTime.utc(date.year, date.month, date.day);
    // Thursday of this week decides the ISO year.
    final DateTime thursday = d.add(Duration(days: 4 - d.weekday));
    final DateTime jan4 = DateTime.utc(thursday.year, 1, 4);
    final DateTime week1Monday =
        jan4.subtract(Duration(days: jan4.weekday - 1));
    final int week = 1 + (thursday.difference(week1Monday).inDays ~/ 7);
    return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
  }

  /// Monday of the week containing [date].
  DateTime _mondayOf(DateTime date) =>
      DateTime(date.year, date.month, date.day)
          .subtract(Duration(days: date.weekday - 1));

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final isSec = context.read<AuthProvider>().isSecretary;
      if (isSec) {
        _contacts = await _repo.listContacts();
      } else {
        _payInfoList = await _repo.listPayInfo();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _callPhone(String phone) async {
    if (phone.isEmpty) return;
    final Uri uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de passer l\'appel.')),
        );
      }
    }
  }

  Future<void> _addStaffMember() async {
    final formKey = GlobalKey<FormState>();
    String name = '';
    String phone = '';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Nouveau Tailleur'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Nom Complet'),
                  validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                  onSaved: (v) => name = v ?? '',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Téléphone'),
                  keyboardType: TextInputType.phone,
                  onSaved: (v) => phone = v ?? '',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tous les tailleurs sont payés à la pièce. Les employés mensuels '
                  'se gèrent dans la section « Staff ».',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  formKey.currentState!.save();
                  try {
                    await _repo.createStaff(
                        fullName: name, phone: phone, type: 'couturier');
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    _loadData();
                  } catch (e) {
                    if (!ctx.mounted) return;
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
                    );
                  }
                }
              },
              child: const Text('Sauvegarder'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editStaffContact(StaffPayInfo member) async {
    final formKey = GlobalKey<FormState>();
    String name = member.fullName;
    String phone = member.phone;
    bool active = member.active;
    String type = member.type;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Modifier Infos Contact'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: name,
                  decoration: const InputDecoration(labelText: 'Nom Complet'),
                  validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                  onSaved: (v) => name = v ?? '',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: phone,
                  decoration: const InputDecoration(labelText: 'Téléphone'),
                  keyboardType: TextInputType.phone,
                  onSaved: (v) => phone = v ?? '',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Rôle'),
                  items: const [
                    DropdownMenuItem(value: 'couturier', child: Text('Couturier (À la pièce)')),
                    DropdownMenuItem(value: 'autre', child: Text('Autre (Mensuel)')),
                  ],
                  onChanged: (v) => setDlgState(() => type = v ?? 'couturier'),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Actif / En poste'),
                  value: active,
                  onChanged: (v) => setDlgState(() => active = v),
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
                    await _repo.updateStaff(member.staffId, fullName: name, phone: phone, type: type, active: active);
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    _loadData();
                  } catch (e) {
                    if (!ctx.mounted) return;
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
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

  Future<void> _editStaffPay(StaffPayInfo member) async {
    final formKey = GlobalKey<FormState>();
    int pieceRate = member.pieceRate ?? 0;
    int monthlySalary = member.monthlySalary ?? 0;
    int salaryDueDay = member.salaryDueDay ?? 1;
    final pieceRateCtrl = TextEditingController(text: formatThousands(pieceRate));
    final salaryCtrl = TextEditingController(text: formatThousands(monthlySalary));

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Paramètres Financiers - ${member.fullName}'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (member.type == 'couturier')
                  FormattedNumberField(
                    controller: pieceRateCtrl,
                    label: 'Tarif par pièce (FCFA)',
                    validator: (v) => v == null ? 'Invalide' : null,
                    onChanged: (v) => pieceRate = v ?? 0,
                  )
                else ...[
                  FormattedNumberField(
                    controller: salaryCtrl,
                    label: 'Salaire Mensuel (FCFA)',
                    validator: (v) => v == null ? 'Invalide' : null,
                    onChanged: (v) => monthlySalary = v ?? 0,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: salaryDueDay.toString(),
                    decoration: const InputDecoration(labelText: 'Jour de versement (1 - 31)'),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final val = int.tryParse(v ?? '');
                      if (val == null || val < 1 || val > 31) return 'Jour invalide (1 - 31)';
                      return null;
                    },
                    onSaved: (v) => salaryDueDay = int.tryParse(v ?? '') ?? 1,
                  ),
                ],
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
                    await _repo.updatePay(
                      member.staffId,
                      pieceRate: member.type == 'couturier' ? pieceRate : null,
                      monthlySalary: member.type == 'autre' ? monthlySalary : null,
                      salaryDueDay: member.type == 'autre' ? salaryDueDay : null,
                    );
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    _loadData();
                  } catch (e) {
                    if (!ctx.mounted) return;
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
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

  Future<void> _addTailorEntry({StaffPayInfo? preselect}) async {
    final formKey = GlobalKey<FormState>();
    final activeTailors = _payInfoList.where((x) => x.active && x.type == 'couturier').toList();

    if (activeTailors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun couturier actif trouvé pour ajouter une entrée.')),
      );
      return;
    }

    // Default to the tailor whose sheet we came from (when provided).
    final StaffPayInfo initialTailor = (preselect != null &&
            activeTailors.any((t) => t.staffId == preselect.staffId))
        ? preselect
        : activeTailors.first;
    String tailorId = initialTailor.staffId;
    int pieces = 1;
    int? rate;
    String garment = GarmentTypes.all.first;
    String? linkedOrderId;
    DateTime date = DateTime.now();
    // Optional: link the day's work to an active order so the client name is
    // derived (never re-typed). Load a short list of recent non-delivered ones.
    List<TailoringOrder> linkableOrders = <TailoringOrder>[];
    try {
      linkableOrders = await OrdersRepository().list(limit: 50);
      linkableOrders = linkableOrders.where((o) => !o.isLivre).toList();
    } catch (_) {/* linking is optional */}
    if (!mounted) return;
    // Pre-fill the rate with the selected tailor's configured piece rate; the
    // manager can override it per entry (a tailor may sew different garments
    // at different prices).
    final rateController = TextEditingController(
      text: initialTailor.pieceRate != null
          ? formatThousands(initialTailor.pieceRate!)
          : '',
    );

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Nouvelle Entrée Couture'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: tailorId,
                  decoration: const InputDecoration(labelText: 'Couturier'),
                  items: activeTailors
                      .map((t) => DropdownMenuItem(value: t.staffId, child: Text(t.fullName)))
                      .toList(),
                  onChanged: (v) {
                    tailorId = v ?? tailorId;
                    // Refresh the rate field to the newly selected tailor's rate.
                    final sel = activeTailors.firstWhere((t) => t.staffId == tailorId);
                    setDlgState(() => rateController.text =
                        sel.pieceRate != null ? formatThousands(sel.pieceRate!) : '');
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: garment,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Type de vêtement'),
                  items: GarmentTypes.all
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (v) => setDlgState(() => garment = v ?? garment),
                ),
                if (linkableOrders.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: linkedOrderId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Commande liée (optionnel)',
                      helperText: 'Renseigne automatiquement le client',
                    ),
                    items: <DropdownMenuItem<String?>>[
                      const DropdownMenuItem<String?>(
                          value: null, child: Text('Aucune')),
                      ...linkableOrders.map((o) => DropdownMenuItem<String?>(
                            value: o.id,
                            child: Text('${o.clientName} — ${o.garmentType}',
                                overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    onChanged: (v) {
                      final ord = v == null
                          ? null
                          : linkableOrders.firstWhere((o) => o.id == v);
                      setDlgState(() {
                        linkedOrderId = v;
                        if (ord != null && ord.garmentType.isNotEmpty) {
                          garment = GarmentTypes.all.contains(ord.garmentType)
                              ? ord.garmentType
                              : garment;
                        }
                      });
                    },
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: '1',
                  decoration: const InputDecoration(labelText: 'Nombre de pièces'),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final val = int.tryParse(v ?? '');
                    if (val == null || val < 1) return 'Quantité invalide';
                    return null;
                  },
                  onSaved: (v) => pieces = int.tryParse(v ?? '') ?? 1,
                ),
                const SizedBox(height: 12),
                FormattedNumberField(
                  controller: rateController,
                  label: 'Prix par pièce (FCFA)',
                  hint: 'Modifiable selon le type de vêtement',
                  validator: (v) => (v == null || v < 1) ? 'Prix invalide' : null,
                  onChanged: (v) => rate = v,
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: const Text('Date'),
                  subtitle: Text('${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'),
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
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  formKey.currentState!.save();
                  try {
                    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                    await _repo.createTailorEntry(
                      tailorId: tailorId,
                      entryDate: dateStr,
                      piecesCount: pieces,
                      pieceRate: parseThousands(rateController.text) ?? rate,
                      garmentType: garment,
                      orderId: linkedOrderId,
                    );
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    _loadData();
                  } catch (e) {
                    if (!ctx.mounted) return;
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
                    );
                  }
                }
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecretaryView() {
    final couturiers =
        _contacts.where((c) => c.type == 'couturier').toList();
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
            ? Center(child: Text('Erreur: $_error'))
            : couturiers.isEmpty
                ? const Center(child: Text('Aucun tailleur enregistré.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: couturiers.length,
                    itemBuilder: (ctx, idx) {
                      final c = couturiers[idx];
                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                            child: Icon(
                              c.type == 'couturier' ? Icons.content_cut_rounded : Icons.person_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                          title: Text(c.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            c.type == 'couturier' ? 'Couturier' : 'Autre personnel',
                          ),
                          trailing: c.phone.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.phone_rounded, color: AppColors.success),
                                  onPressed: () => _callPhone(c.phone),
                                )
                              : null,
                        ),
                      );
                    },
                  );
  }

  Widget _buildManagerStaffTab() {
    final tailors =
        _payInfoList.where((m) => m.type == 'couturier').toList();
    return tailors.isEmpty
        ? const Center(child: Text('Aucun tailleur enregistré.'))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tailors.length,
            itemBuilder: (ctx, idx) {
              final m = tailors[idx];
              const String typeLabel = 'Couturier';
              final String payLabel =
                  'Tarif p. pièce: ${formatFcfa(m.pieceRate ?? 0)}';

              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                margin: const EdgeInsets.only(bottom: 12),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _openTailorSheet(m),
                  child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: (m.active ? AppColors.primary : Colors.grey).withValues(alpha: 0.1),
                        child: Icon(
                          m.type == 'couturier' ? Icons.content_cut_rounded : Icons.person_rounded,
                          color: m.active ? AppColors.primary : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(m.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(width: 8),
                                if (!m.active)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('Inactif', style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text('$typeLabel | $payLabel', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                            tooltip: 'Modifier Contact',
                            onPressed: () => _editStaffContact(m),
                          ),
                          IconButton(
                            icon: const Icon(Icons.monetization_on_rounded, color: AppColors.success),
                            tooltip: 'Paramètres Financiers',
                            onPressed: () => _editStaffPay(m),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
                ),
              );
            },
          );
  }

  static String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Everything for one tailor in a single sheet: a real Monday→Sunday week
  /// (navigable), each day's garments/quantities/clients + daily total, the
  /// week total, plus add-entry and edit-rate actions.
  Future<void> _openTailorSheet(StaffPayInfo member) async {
    DateTime weekStart = _mondayOf(DateTime.now());
    WeeklyDetail? detail;
    bool loading = true;
    bool started = false;

    const dayNames = <String>[
      'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'
    ];

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
              detail = await _repo.weeklyDetail(
                  _getWeekId(weekStart), member.staffId);
            } catch (_) {
              detail = null;
            }
            if (ctx.mounted) setSheet(() => loading = false);
          }

          if (!started) {
            started = true;
            WidgetsBinding.instance.addPostFrameCallback((_) => load());
          }

          void shiftWeek(int deltaDays) {
            weekStart = weekStart.add(Duration(days: deltaDays));
            load();
          }

          final DateTime weekEnd = weekStart.add(const Duration(days: 6));
          final days =
              List.generate(7, (i) => weekStart.add(Duration(days: i)));
          final byDay = <String, List<WeeklyDetailEntry>>{};
          for (final e in detail?.items ?? const <WeeklyDetailEntry>[]) {
            byDay.putIfAbsent(e.entryDate.split('T').first, () => []).add(e);
          }

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
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Header: name, rate, actions.
                    Row(
                      children: <Widget>[
                        CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                          child: const Icon(Icons.content_cut_rounded,
                              color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(member.fullName,
                                  style: Theme.of(ctx).textTheme.titleLarge),
                              Text('Tarif p. pièce: ${formatFcfa(member.pieceRate ?? 0)}',
                                  style: Theme.of(ctx).textTheme.bodySmall),
                            ],
                          ),
                        ),
                        if (member.phone.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.phone_rounded, color: AppColors.success),
                            onPressed: () => _callPhone(member.phone),
                          ),
                        IconButton(
                          icon: const Icon(Icons.monetization_on_rounded, color: AppColors.success),
                          tooltip: 'Modifier le tarif',
                          onPressed: () async {
                            await _editStaffPay(member);
                          },
                        ),
                      ],
                    ),
                    const Divider(),
                    // Week navigation.
                    Row(
                      children: <Widget>[
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded),
                          onPressed: () => shiftWeek(-7),
                        ),
                        Expanded(
                          child: Text(
                            'Semaine du ${weekStart.day}/${weekStart.month} au ${weekEnd.day}/${weekEnd.month}/${weekEnd.year}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded),
                          onPressed: () => shiftWeek(7),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: loading
                          ? const Center(child: CircularProgressIndicator())
                          : SingleChildScrollView(
                              controller: scrollCtrl,
                              child: Table(
                                border:
                                    TableBorder.all(color: AppColors.border),
                                columnWidths: const <int, TableColumnWidth>{
                                  0: FlexColumnWidth(1.7),
                                  1: FlexColumnWidth(2.2),
                                  2: FlexColumnWidth(1.0),
                                  3: FlexColumnWidth(2.7),
                                  4: FlexColumnWidth(2.0),
                                },
                                children: <TableRow>[
                                  TableRow(
                                    decoration: const BoxDecoration(
                                        color: AppColors.primary),
                                    children: <Widget>[
                                      for (final h in const <String>[
                                        'Jours',
                                        'Nom client',
                                        'Qté',
                                        'Modèle',
                                        'Montant'
                                      ])
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 10),
                                          child: Text(h,
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12.5)),
                                        ),
                                    ],
                                  ),
                                  for (int i = 0; i < 7; i++)
                                    _tailorDayRow(
                                      dayNames[i],
                                      days[i],
                                      byDay[_ymd(days[i])] ??
                                          const <WeeklyDetailEntry>[],
                                      (e) => _correctWeeklyEntry(e, load),
                                    ),
                                ],
                              ),
                            ),
                    ),
                    const Divider(),
                    Row(
                      children: <Widget>[
                        Text('Total semaine',
                            style: Theme.of(ctx).textTheme.titleMedium),
                        const Spacer(),
                        Text(formatFcfa(detail?.total ?? 0),
                            style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                )),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await _addTailorEntry(preselect: member);
                        await load();
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Ajouter une entrée'),
                      style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(46)),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    _loadData();
  }

  /// One TableCell with standard padding, vertically centered.
  Widget _tcell(Widget child) => TableCell(
        verticalAlignment: TableCellVerticalAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: child,
        ),
      );

  /// A single Monday→Sunday row of the tailor weekly table, matching the
  /// requested layout: Jours | Nom client | Qté | Modèle(s) | Montant(s).
  /// The Modèle and Montant cells stack one fixed-height line per entry so the
  /// two columns stay aligned; each line is tappable to open a correction.
  TableRow _tailorDayRow(
      String dayName,
      DateTime day,
      List<WeeklyDetailEntry> entries,
      void Function(WeeklyDetailEntry) onCorrect) {
    const double lineH = 30;
    final int qty = entries.fold<int>(0, (s, e) => s + e.piecesCount);
    final String clients = <String>{
      for (final e in entries)
        if ((e.clientName ?? '').isNotEmpty) e.clientName!
    }.join('\n');

    return TableRow(
      children: <Widget>[
        _tcell(Text('$dayName\n${day.day}/${day.month}',
            style:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5))),
        _tcell(Text(clients.isEmpty ? '—' : clients,
            style: const TextStyle(fontSize: 12.5))),
        _tcell(Text(entries.isEmpty ? '—' : '$qty',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600))),
        _tcell(entries.isEmpty
            ? const Text('—')
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (final e in entries)
                    SizedBox(
                      height: lineH,
                      child: InkWell(
                        onTap: () => onCorrect(e),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${e.garmentType.isEmpty ? 'Pièce' : e.garmentType}'
                            '${e.piecesCount > 1 ? ' ×${e.piecesCount}' : ''}',
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ),
                      ),
                    ),
                ],
              )),
        _tcell(entries.isEmpty
            ? const Text('—', textAlign: TextAlign.right)
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  for (final e in entries)
                    SizedBox(
                      height: lineH,
                      child: InkWell(
                        onTap: () => onCorrect(e),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(formatFcfa(e.amount),
                              style: const TextStyle(fontSize: 12.5)),
                        ),
                      ),
                    ),
                ],
              )),
      ],
    );
  }

  /// Small correction dialog for a weekly entry (pieces + mandatory reason).
  Future<void> _correctWeeklyEntry(
      WeeklyDetailEntry e, Future<void> Function() reload) async {
    final formKey = GlobalKey<FormState>();
    int newPieces = e.piecesCount;
    String reason = '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Corriger : ${e.garmentType}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                initialValue: e.piecesCount.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Nombre de pièces'),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return (n == null || n < 0) ? 'Quantité invalide' : null;
                },
                onSaved: (v) => newPieces = int.tryParse(v ?? '') ?? 0,
              ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Motif (obligatoire)'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Motif requis' : null,
                onSaved: (v) => reason = v?.trim() ?? '',
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                formKey.currentState!.save();
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Corriger'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _repo.correctTailorEntry(e.id, newPieces: newPieces, reason: reason);
        await reload();
      } catch (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $err'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSec = context.watch<AuthProvider>().isSecretary;
    final shopName = context.watch<ShopSettingsProvider>().shopName;

    return Scaffold(
      appBar: AppBar(
        title: Text('$shopName - Tailleurs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          )
        ],
      ),
      floatingActionButton: isSec
          ? null
          : FloatingActionButton.extended(
              onPressed: _addStaffMember,
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('Tailleur', style: TextStyle(color: Colors.white)),
            ),
      // Single view: the tailor list. Tap a tailor for everything (week
      // detail, entries, add-entry, rate) in one sheet.
      body: isSec
          ? _buildSecretaryView()
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text('Erreur: $_error'))
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      child: _buildManagerStaffTab(),
                    ),
    );
  }
}
