import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/garment_types.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../clients/data/clients_repository.dart';
import '../../../clients/domain/client.dart';
import '../../data/orders_repository.dart';

/// Nouvelle commande : pour un client existant ou un nouveau client
/// (créé d'abord dans /clients, puis la commande est liée à sa fiche).
/// Les mesures de référence sont figées automatiquement par le serveur
/// depuis la fiche du client.
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

  String _garment = GarmentTypes.all.first;
  final TextEditingController _fabric = TextEditingController();
  final TextEditingController _price = TextEditingController();
  final TextEditingController _advance = TextEditingController(text: '0');
  final TextEditingController _notes = TextEditingController();
  DateTime? _expected;

  bool _submitting = false;

  final OrdersRepository _ordersRepo = OrdersRepository();
  final ClientsRepository _clientsRepo = ClientsRepository();

  @override
  void dispose() {
    for (final c in <TextEditingController>[
      _newName,
      _newPhone,
      _fabric,
      _price,
      _advance,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

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
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_useExisting && _selectedClient == null) {
      _toast('Veuillez sélectionner un client.', error: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      // Un nouveau client devient d'abord une fiche client (module Clients),
      // puis la commande est liée à cette fiche.
      final String clientId = _useExisting
          ? _selectedClient!.id
          : (await _clientsRepo.create(
              fullName: _newName.text.trim(),
              phone: _newPhone.text.trim(),
            ))
              .id;

      await _ordersRepo.create(
        clientId: clientId,
        garmentType: _garment,
        fabric: _fabric.text.trim(),
        price: int.tryParse(_price.text.trim()) ?? 0,
        advance: int.tryParse(_advance.text.trim()) ?? 0,
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
                Text('Type de vêtement',
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _garment,
                  items: GarmentTypes.all
                      .map((g) =>
                          DropdownMenuItem<String>(value: g, child: Text(g)))
                      .toList(growable: false),
                  onChanged: (v) => setState(() => _garment = v ?? _garment),
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
                Row(
                  children: <Widget>[
                    Expanded(
                      child: AppTextField(
                        controller: _price,
                        label: 'Prix (FCFA)',
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          return (n == null || n < 0)
                              ? 'Montant invalide'
                              : null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: _advance,
                        label: 'Avance (FCFA)',
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          return (n == null || n < 0)
                              ? 'Montant invalide'
                              : null;
                        },
                      ),
                    ),
                  ],
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
