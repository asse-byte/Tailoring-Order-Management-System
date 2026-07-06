import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
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
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final isSec = context.read<AuthProvider>().isSecretary;
      if (!isSec) {
        _tabController = TabController(length: 2, vsync: this);
      }
      _loadData();
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
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
    String type = 'couturier';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Nouveau Membre'),
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
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Rôle'),
                  items: const [
                    DropdownMenuItem(value: 'couturier', child: Text('Couturier (À la pièce)')),
                    DropdownMenuItem(value: 'autre', child: Text('Autre (Mensuel)')),
                  ],
                  onChanged: (v) => setDlgState(() => type = v ?? 'couturier'),
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
                    await _repo.createStaff(fullName: name, phone: phone, type: type);
                    Navigator.pop(ctx);
                    _loadData();
                  } catch (e) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
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
    String phone = member.active ? member.fullName : ''; // Wait, use phone from details or list
    // Since details phone isn't directly in StaffPayInfo, let's load contacts or assume empty if not loaded.
    final contact = _contacts.firstWhere((x) => x.id == member.staffId, 
      orElse: () => StaffContact(id: member.staffId, fullName: member.fullName, phone: '', type: member.type, active: member.active));
    phone = contact.phone;

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
                  value: type,
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
                    Navigator.pop(ctx);
                    _loadData();
                  } catch (e) {
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

  Future<void> _editStaffPay(StaffPayInfo member) async {
    final formKey = GlobalKey<FormState>();
    int pieceRate = member.pieceRate ?? 0;
    int monthlySalary = member.monthlySalary ?? 0;
    int salaryDueDay = member.salaryDueDay ?? 1;

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
                  TextFormField(
                    initialValue: pieceRate.toString(),
                    decoration: const InputDecoration(labelText: 'Tarif par pièce (FCFA)'),
                    keyboardType: TextInputType.number,
                    validator: (v) => v == null || int.tryParse(v) == null ? 'Invalide' : null,
                    onSaved: (v) => pieceRate = int.tryParse(v ?? '') ?? 0,
                  )
                else ...[
                  TextFormField(
                    initialValue: monthlySalary.toString(),
                    decoration: const InputDecoration(labelText: 'Salaire Mensuel (FCFA)'),
                    keyboardType: TextInputType.number,
                    validator: (v) => v == null || int.tryParse(v) == null ? 'Invalide' : null,
                    onSaved: (v) => monthlySalary = int.tryParse(v ?? '') ?? 0,
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
                      pieceRate: member.type == 'couturier' ? pieceRate : 0,
                      monthlySalary: member.type == 'autre' ? monthlySalary : 0,
                      salaryDueDay: member.type == 'autre' ? salaryDueDay : 0,
                    );
                    Navigator.pop(ctx);
                    _loadData();
                  } catch (e) {
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
    DateTime date = DateTime.now();

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
                  value: tailorId,
                  decoration: const InputDecoration(labelText: 'Couturier'),
                  items: activeTailors
                      .map((t) => DropdownMenuItem(value: t.staffId, child: Text(t.fullName)))
                      .toList(),
                  onChanged: (v) => tailorId = v ?? tailorId,
                ),
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
                    );
                    Navigator.pop(ctx);
                    _loadData();
                  } catch (e) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
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
                  Navigator.pop(ctx);
                  _loadData();
                } catch (e) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
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
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
            ? Center(child: Text('Erreur: $_error'))
            : _contacts.isEmpty
                ? const Center(child: Text('Aucun employé enregistré.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _contacts.length,
                    itemBuilder: (ctx, idx) {
                      final c = _contacts[idx];
                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withOpacity(0.1),
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
                                  icon: const Icon(Icons.phone_rounded, color: Colors.green),
                                  onPressed: () => _callPhone(c.phone),
                                )
                              : null,
                        ),
                      );
                    },
                  );
  }

  Widget _buildManagerStaffTab() {
    return _payInfoList.isEmpty
        ? const Center(child: Text('Aucun employé enregistré.'))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _payInfoList.length,
            itemBuilder: (ctx, idx) {
              final m = _payInfoList[idx];
              final String typeLabel = m.type == 'couturier' ? 'Couturier' : 'Mensuel';
              final String payLabel = m.type == 'couturier'
                  ? 'Tarif p. pièce: ${m.pieceRate ?? 0} F'
                  : 'Salaire: ${m.monthlySalary ?? 0} F (le ${m.salaryDueDay ?? 1})';

              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: (m.active ? AppColors.primary : Colors.grey).withOpacity(0.1),
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
                            icon: const Icon(Icons.monetization_on_rounded, color: Colors.green),
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
                          'Date: ${e.entryDate} | Pièces: ${e.piecesCount}\nTarif: ${e.pieceRate} F | Total: ${e.amount} F',
                          style: const TextStyle(height: 1.3),
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_note_rounded, color: Colors.orange),
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

  @override
  Widget build(BuildContext context) {
    final isSec = context.watch<AuthProvider>().isSecretary;
    final shopName = context.watch<ShopSettingsProvider>().shopName;

    return Scaffold(
      appBar: AppBar(
        title: Text('$shopName - Personnel'),
        bottom: isSec || _tabController == null
            ? null
            : TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.people_rounded), text: 'Personnel'),
                  Tab(icon: Icon(Icons.assignment_turned_in_rounded), text: 'Production (Couturiers)'),
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
                      ],
                    ),
    );
  }
}
