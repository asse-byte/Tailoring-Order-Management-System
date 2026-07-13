import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/garment_types.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/formatted_number_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../clients/data/clients_repository.dart';
import '../../../clients/domain/client.dart';
import '../../../staff/data/staff_repository.dart';
import '../../data/orders_repository.dart';

/// One editable order line (garment type + quantity + unit price).
class _LineDraft {
  _LineDraft({String? garment})
      : garment = garment ?? GarmentTypes.all.first,
        qty = TextEditingController(text: '1'),
        price = TextEditingController();
  String garment;
  final TextEditingController qty;
  final TextEditingController price;

  int get quantity => int.tryParse(qty.text.trim()) ?? 0;
  int get unitPrice => parseThousands(price.text) ?? 0;
  int get lineTotal => quantity * unitPrice;

  void dispose() {
    qty.dispose();
    price.dispose();
  }
}

/// Nouvelle commande : plusieurs articles (types de vêtement) dans une seule
/// commande, chacun avec sa quantité et son prix, liée à un couturier.
class WalkInOrderScreen extends StatefulWidget {
  const WalkInOrderScreen({super.key});

  @override
  State<WalkInOrderScreen> createState() => _WalkInOrderScreenState();
}

class _WalkInOrderScreenState extends State<WalkInOrderScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _useExisting = true;
  Client? _selectedClient;
  final TextEditingController _newName = TextEditingController();
  final TextEditingController _newPhone = TextEditingController();

  final List<_LineDraft> _lines = <_LineDraft>[_LineDraft()];
  final TextEditingController _fabric = TextEditingController();
  final TextEditingController _advance = TextEditingController(text: '0');
  final TextEditingController _notes = TextEditingController();
  DateTime? _expected;
  String _status = AppConstants.statusEnAttente;

  List<StaffContact> _tailors = <StaffContact>[];
  String? _tailorId;

  /// Garment types the selected existing client already has measurements for.
  /// Used to warn instantly when a line's garment type has no measurement.
  Set<String> _measuredGarments = <String>{};
  bool _loadingMeasures = false;

  bool _submitting = false;

  final OrdersRepository _ordersRepo = OrdersRepository();
  final ClientsRepository _clientsRepo = ClientsRepository();
  final StaffRepository _staffRepo = StaffRepository();

  @override
  void initState() {
    super.initState();
    _loadTailors();
  }

  Future<void> _loadTailors() async {
    try {
      final all = await _staffRepo.listContacts();
      if (!mounted) return;
      setState(() => _tailors =
          all.where((s) => s.type == 'couturier' && s.active).toList());
    } catch (_) {/* tailor optional — ignore load errors */}
  }

  @override
  void dispose() {
    for (final c in <TextEditingController>[
      _newName, _newPhone, _fabric, _advance, _notes,
    ]) {
      c.dispose();
    }
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  int get _total => _lines.fold(0, (sum, l) => sum + l.lineTotal);

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _expected ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _expected = picked);
  }

  Future<void> _showClientPicker() async {
    final List<Client> clients = await _clientsRepo.list(limit: 100);
    if (!mounted) return;
    final Client? chosen = await showModalBottomSheet<Client>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ClientPickerSheet(clients: clients),
    );
    if (chosen != null) {
      setState(() => _selectedClient = chosen);
      _loadClientMeasures(chosen.id);
    }
  }

  /// Loads the garment types the selected client already has measurements for,
  /// so we can warn instantly when an ordered type has no measurement.
  Future<void> _loadClientMeasures(String clientId) async {
    setState(() => _loadingMeasures = true);
    try {
      final Map<String, Map<String, num>> m =
          await _clientsRepo.measurements(clientId);
      if (!mounted) return;
      setState(() => _measuredGarments = m.keys.toSet());
    } catch (_) {
      if (mounted) setState(() => _measuredGarments = <String>{});
    } finally {
      if (mounted) setState(() => _loadingMeasures = false);
    }
  }

  /// True when the chosen existing client has no measurement for [garment].
  bool _missingMeasure(String garment) =>
      _useExisting &&
      _selectedClient != null &&
      !_loadingMeasures &&
      !_measuredGarments.contains(garment);

  /// Instant amber warning shown under a garment type the client has no
  /// measurement for, with a shortcut to record it (the draft is kept —
  /// we only push, then reload measures on return).
  Widget _measureWarning(String garment) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: <Widget>[
          const Icon(Icons.straighten_rounded,
              size: 16, color: AppColors.warning),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Ce client n\'a pas de mesure pour « $garment ».',
              style: const TextStyle(
                  color: AppColors.warning,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () async {
              final String id = _selectedClient!.id;
              await context.push(
                  '/admin/clients/$id/measurements/${Uri.encodeComponent(garment)}');
              if (mounted) await _loadClientMeasures(id);
            },
            child: const Text('Ajouter la mesure'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_useExisting && _selectedClient == null) {
      _toast('Veuillez sélectionner un client.', error: true);
      return;
    }
    // Build & validate the line items.
    final List<NewOrderItem> items = <NewOrderItem>[];
    for (final l in _lines) {
      if (l.quantity < 1 || l.unitPrice < 0 || l.price.text.trim().isEmpty) {
        _toast('Chaque article doit avoir une quantité et un prix.', error: true);
        return;
      }
      items.add(NewOrderItem(
        garmentType: l.garment, quantity: l.quantity, unitPrice: l.unitPrice));
    }

    // Safety net: warn (but don't block) if some ordered types have no
    // measurement recorded for this client.
    final Set<String> missing =
        _lines.map((l) => l.garment).where(_missingMeasure).toSet();
    if (missing.isNotEmpty) {
      final bool proceed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Mesures manquantes'),
              content: Text(
                  'Ce client n\'a pas de mesure pour : ${missing.join(', ')}.\n\n'
                  'Créer la commande quand même ?'),
              actions: <Widget>[
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Annuler')),
                ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Continuer')),
              ],
            ),
          ) ??
          false;
      if (!proceed) return;
    }

    setState(() => _submitting = true);
    try {
      final String clientId = _useExisting
          ? _selectedClient!.id
          : (await _clientsRepo.create(
              fullName: _newName.text.trim(),
              phone: _newPhone.text.trim(),
            ))
              .id;

      await _ordersRepo.create(
        clientId: clientId,
        items: items,
        tailorId: _tailorId,
        status: _status,
        fabric: _fabric.text.trim(),
        advance: parseThousands(_advance.text) ?? 0,
        expectedDate: _expected,
        notes: _notes.text.trim(),
      );

      if (!mounted) return;
      _toast('Commande créée avec succès !');
      context.pop();
    } catch (e) {
      if (mounted) _toast('Impossible de créer la commande : $e', error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle commande')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SegmentedButton<bool>(
                  segments: const <ButtonSegment<bool>>[
                    ButtonSegment<bool>(
                      value: true,
                      label: Text('Client existant'),
                      icon: Icon(Icons.people_outline),
                    ),
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('Nouveau client'),
                      icon: Icon(Icons.person_add_outlined),
                    ),
                  ],
                  selected: <bool>{_useExisting},
                  onSelectionChanged: (s) {
                    setState(() {
                      _useExisting = s.first;
                      _selectedClient = null;
                      _measuredGarments = <String>{};
                      _newName.clear();
                      _newPhone.clear();
                    });
                  },
                ),
                const SizedBox(height: 16),
                if (_useExisting)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            _selectedClient == null
                                ? 'Aucun client sélectionné'
                                : '${_selectedClient!.fullName} · ${_selectedClient!.phone}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        TextButton(
                          onPressed: _showClientPicker,
                          child: Text(
                              _selectedClient == null ? 'Choisir' : 'Changer'),
                        ),
                      ],
                    ),
                  )
                else ...<Widget>[
                  AppTextField(
                    controller: _newName,
                    label: 'Nom complet',
                    prefixIcon: Icons.person_outline_rounded,
                    validator: (v) =>
                        Validators.required(v, context, label: 'Nom complet'),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _newPhone,
                    label: 'Téléphone',
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                ],
                const SizedBox(height: 24),

                // ---- Line items ---------------------------------------------
                Row(
                  children: <Widget>[
                    Text('Articles',
                        style: Theme.of(context).textTheme.labelLarge),
                    const Spacer(),
                    Text(
                      'Total: ${formatFcfa(_total)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...List<Widget>.generate(_lines.length, _buildLineEditor),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _lines.add(_LineDraft())),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Ajouter un type'),
                  ),
                ),

                const SizedBox(height: 8),
                Text('Couturier (responsable)',
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  initialValue: _tailorId,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.badge_outlined, size: 20),
                  ),
                  hint: const Text('Aucun / à assigner'),
                  items: <DropdownMenuItem<String?>>[
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('Aucun / à assigner')),
                    ..._tailors.map((t) => DropdownMenuItem<String?>(
                        value: t.id, child: Text(t.fullName))),
                  ],
                  onChanged: (v) => setState(() => _tailorId = v),
                ),
                const SizedBox(height: 16),
                Text('Statut', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  items: AppConstants.orderStatuses
                      .map((s) => DropdownMenuItem<String>(
                          value: s, child: Text(AppConstants.statusLabel(s))))
                      .toList(growable: false),
                  onChanged: (v) =>
                      setState(() => _status = v ?? AppConstants.statusEnAttente),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _fabric,
                  label: 'Tissu (description)',
                  prefixIcon: Icons.texture_rounded,
                  maxLines: 2,
                  minLines: 1,
                ),
                const SizedBox(height: 16),
                FormattedNumberField(
                  controller: _advance,
                  label: 'Avance (FCFA)',
                  validator: (v) =>
                      (v == null || v < 0) ? 'Montant invalide' : null,
                ),
                const SizedBox(height: 16),
                Text('Date de livraison prévue',
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.event_outlined, size: 20),
                    ),
                    child: Text(
                      _expected != null
                          ? DateFormatter.date(_expected!, locale: 'fr')
                          : 'Choisir une date',
                      style: TextStyle(
                        color: _expected != null
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _notes,
                  label: 'Notes (optionnel)',
                  maxLines: 3,
                  minLines: 2,
                ),
                const SizedBox(height: 12),
                Text(
                  'Les mesures de référence sont reprises automatiquement de la '
                  'fiche du client (module Clients).',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: 'Créer la commande',
                  icon: Icons.check_rounded,
                  loading: _submitting,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLineEditor(int index) {
    final _LineDraft line = _lines[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: line.garment,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: GarmentTypes.all
                      .map((g) =>
                          DropdownMenuItem<String>(value: g, child: Text(g)))
                      .toList(growable: false),
                  onChanged: (v) =>
                      setState(() => line.garment = v ?? line.garment),
                ),
              ),
              if (_lines.length > 1)
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.error),
                  onPressed: () => setState(() {
                    _lines.removeAt(index).dispose();
                  }),
                ),
            ],
          ),
          if (_missingMeasure(line.garment)) _measureWarning(line.garment),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              SizedBox(
                width: 84,
                child: TextFormField(
                  controller: line.qty,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Qté'),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    return (n == null || n < 1) ? '≥1' : null;
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FormattedNumberField(
                  controller: line.price,
                  label: 'Prix unitaire',
                  onChanged: (_) => setState(() {}),
                  validator: (v) => (v == null || v < 0) ? 'Prix' : null,
                ),
              ),
            ],
          ),
          if (line.lineTotal > 0)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Sous-total: ${formatFcfa(line.lineTotal)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ClientPickerSheet extends StatefulWidget {
  const _ClientPickerSheet({required this.clients});
  final List<Client> clients;

  @override
  State<_ClientPickerSheet> createState() => _ClientPickerSheetState();
}

class _ClientPickerSheetState extends State<_ClientPickerSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final List<Client> list = _q.isEmpty
        ? widget.clients
        : widget.clients
            .where((u) =>
                u.fullName.toLowerCase().contains(_q) ||
                u.phone.toLowerCase().contains(_q))
            .toList(growable: false);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
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
              Text('Sélectionner un client',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              TextField(
                onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
                decoration: const InputDecoration(
                  hintText: 'Rechercher par nom ou téléphone...',
                  prefixIcon: Icon(Icons.search_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: list.isEmpty
                    ? const Center(child: Text('Aucun client trouvé'))
                    : ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final u = list[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  AppColors.primary.withValues(alpha: 0.12),
                              child: Text(
                                u.fullName.isEmpty
                                    ? '?'
                                    : u.fullName[0].toUpperCase(),
                                style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            title: Text(u.fullName),
                            subtitle: Text(u.phone.isEmpty ? '—' : u.phone),
                            onTap: () => Navigator.pop(context, u),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
