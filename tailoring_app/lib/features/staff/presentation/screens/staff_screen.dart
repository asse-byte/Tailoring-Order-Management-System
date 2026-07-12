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

class _StaffScreenState extends State<StaffScreen> with SingleTickerProviderStateMixin {
  final StaffRepository _repo = StaffRepository();
  TabController? _tabController;

  List<StaffContact> _contacts = [];
  List<StaffPayInfo> _payInfoList = [];
  List<TailorEntry> _entries = [];
  List<WeeklyTailorSummary> _weeklySummary = [];
  bool _loading = true;
  String? _error;
  late DateTime _currentWeekStart;

  @override
  void initState() {
    super.initState();
    _currentWeekStart = _getWeekStart(DateTime.now());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final isSec = context.read<AuthProvider>().isSecretary;
      if (!isSec) {
        _tabController = TabController(length: 3, vsync: this);
      }
      _loadData();
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  String _getWeekId(DateTime date) {
    final year = date.year;
    final firstDayOfYear = DateTime(year, 1, 1);
    final dayOfWeek = firstDayOfYear.weekday;
    final weekStart = firstDayOfYear.subtract(Duration(days: dayOfWeek - 1));
    final weeksElapsed = ((date.difference(weekStart).inDays) / 7).floor();
    final weekNum = weeksElapsed + 1;
    return '$year-W${weekNum.toString().padLeft(2, '0')}';
  }

  DateTime _getWeekStart(DateTime date) {
    final diff = date.weekday - 1;
    return date.subtract(Duration(days: diff));
  }

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
        _entries = await _repo.listTailorEntries();
        final weekId = _getWeekId(_currentWeekStart);
        _weeklySummary = await _repo.listWeeklyTotals(weekId);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _loading = false);
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

  Future<void> _addTailorEntry() async {
    final formKey = GlobalKey<FormState>();
    final activeTailors = _payInfoList.where((x) => x.active && x.type == 'couturier').toList();
    
    if (activeTailors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun couturier actif trouvé pour ajouter une entrée.')),
      );
      return;
    }

    String tailorId = activeTailors.first.staffId;
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
      text: activeTailors.first.pieceRate != null
          ? formatThousands(activeTailors.first.pieceRate!)
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

  Future<void> _correctTailorEntry(TailorEntry entry) async {
    final formKey = GlobalKey<FormState>();
    int newPieces = entry.piecesCount;
    String reason = '';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Correction - ${entry.tailorName}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Date de l\'entrée: ${entry.entryDate}'),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: entry.piecesCount.toString(),
                decoration: const InputDecoration(labelText: 'Nouveau nombre de pièces (0 pour annuler)'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final val = int.tryParse(v ?? '');
                  if (val == null || val < 0) return 'Invalide';
                  return null;
                },
                onSaved: (v) => newPieces = int.tryParse(v ?? '') ?? 0,
              ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Raison de la correction (Obligatoire)'),
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
                  await _repo.correctTailorEntry(entry.id, newPieces: newPieces, reason: reason);
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
            child: const Text('Corriger'),
          ),
        ],
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
              );
            },
          );
  }

  Widget _buildManagerEntriesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _addTailorEntry,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nouvelle Entrée Couture'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
          ),
        ),
        Expanded(
          child: _entries.isEmpty
              ? const Center(child: Text('Aucune production enregistrée.'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _entries.length,
                  itemBuilder: (ctx, idx) {
                    final e = _entries[idx];
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Text(e.tailorName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          'Date: ${e.entryDate} | Pièces: ${e.piecesCount}\nTarif: ${formatFcfa(e.pieceRate)} | Total: ${formatFcfa(e.amount)}',
                          style: const TextStyle(height: 1.3),
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_note_rounded, color: AppColors.warning),
                          tooltip: 'Corriger l\'entrée',
                          onPressed: () => _correctTailorEntry(e),
                        ),
                      ),
                    );
                  },
                ),
        )
      ],
    );
  }

  /// Detailed week for one tailor: entries grouped Monday→Sunday, each day
  /// listing garment types + quantities + client names + daily total.
  Future<void> _showWeeklyDetail(String tailorId, String tailorName) async {
    final weekId = _getWeekId(_currentWeekStart);
    final WeeklyDetail detail;
    try {
      detail = await _repo.weeklyDetail(weekId, tailorId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
      return;
    }
    if (!mounted) return;

    // Group by day, preserving Monday→Sunday order.
    const dayNames = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    final Map<String, List<WeeklyDetailEntry>> byDay = {};
    for (final e in detail.items) {
      byDay.putIfAbsent(e.entryDate, () => []).add(e);
    }
    final sortedDates = byDay.keys.toList()..sort();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (ctx, scrollCtrl) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    height: 4,
                    width: 40,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Semaine de $tailorName',
                    style: Theme.of(ctx).textTheme.headlineSmall),
                Text('Semaine $weekId',
                    style: Theme.of(ctx).textTheme.bodySmall),
                const SizedBox(height: 12),
                Expanded(
                  child: detail.items.isEmpty
                      ? const Center(child: Text('Aucune production cette semaine.'))
                      : ListView.builder(
                          controller: scrollCtrl,
                          itemCount: sortedDates.length,
                          itemBuilder: (ctx, i) {
                            final date = sortedDates[i];
                            final dayEntries = byDay[date]!;
                            final dt = DateTime.tryParse(date);
                            final dayLabel = dt != null
                                ? '${dayNames[dt.weekday - 1]} ${dt.day}/${dt.month}'
                                : date;
                            final dayTotal = dayEntries.fold<int>(
                                0, (s, e) => s + e.amount);
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Row(
                                      children: <Widget>[
                                        Text(dayLabel,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold)),
                                        const Spacer(),
                                        Text(formatFcfa(dayTotal),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.success)),
                                      ],
                                    ),
                                    const Divider(),
                                    ...dayEntries.map((e) => Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 3),
                                          child: Row(
                                            children: <Widget>[
                                              Expanded(
                                                child: Text(
                                                  '${e.garmentType.isEmpty ? 'Pièce' : e.garmentType}'
                                                  ' × ${e.piecesCount}'
                                                  '${e.clientName != null ? '  · ${e.clientName}' : ''}',
                                                  style: Theme.of(ctx)
                                                      .textTheme
                                                      .bodyMedium,
                                                ),
                                              ),
                                              Text(formatFcfa(e.amount)),
                                            ],
                                          ),
                                        )),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: <Widget>[
                      Text('Total semaine',
                          style: Theme.of(ctx).textTheme.titleMedium),
                      const Spacer(),
                      Text(formatFcfa(detail.total),
                          style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                              )),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklySummaryTab() {
    final weekStart = _currentWeekStart;
    final weekEnd = weekStart.add(const Duration(days: 6));
    final weekLabel = '${weekStart.day}/${weekStart.month} - ${weekEnd.day}/${weekEnd.month}/${weekEnd.year}';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => setState(() => _currentWeekStart = _currentWeekStart.subtract(const Duration(days: 7))),
              ),
              Expanded(
                child: Text(
                  'Semaine du $weekLabel',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_rounded),
                onPressed: () => setState(() => _currentWeekStart = _currentWeekStart.add(const Duration(days: 7))),
              ),
            ],
          ),
        ),
        Expanded(
          child: _weeklySummary.isEmpty
              ? const Center(child: Text('Aucune production cette semaine.'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _weeklySummary.length,
                  itemBuilder: (ctx, idx) {
                    final w = _weeklySummary[idx];
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.only(bottom: 10),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                      onTap: () => _showWeeklyDetail(w.tailorId, w.tailorName),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                              child: Icon(Icons.content_cut_rounded, color: AppColors.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(w.tailorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Pièces: ${w.piecesTotal} | Jours: ${w.daysWorked}',
                                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  formatFcfa(w.amountTotal),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.success),
                                ),
                                const Text('Total', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      ),
                    );
                  },
                ),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSec = context.watch<AuthProvider>().isSecretary;
    final shopName = context.watch<ShopSettingsProvider>().shopName;

    return Scaffold(
      appBar: AppBar(
        title: Text('$shopName - Tailleurs'),
        bottom: isSec || _tabController == null
            ? null
            : TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.content_cut_rounded), text: 'Tailleurs'),
                  Tab(icon: Icon(Icons.assignment_turned_in_rounded), text: 'Entrées'),
                  Tab(icon: Icon(Icons.summarize_rounded), text: 'Résumés'),
                ],
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          )
        ],
      ),
      floatingActionButton: isSec
          ? null
          : FloatingActionButton(
              onPressed: _addStaffMember,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add_rounded, color: Colors.white),
            ),
      body: isSec
          ? _buildSecretaryView()
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text('Erreur: $_error'))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildManagerStaffTab(),
                        _buildManagerEntriesTab(),
                        _buildWeeklySummaryTab(),
                      ],
                    ),
    );
  }
}
