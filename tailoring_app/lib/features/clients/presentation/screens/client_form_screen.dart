import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/couture_icons.dart';
import '../../../../core/theme/couture_palette.dart';
import '../../../../core/widgets/couture/couture_scaffold.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/clients_repository.dart';
import '../../domain/client.dart';

/// Add / edit a client record.
class ClientFormScreen extends StatefulWidget {
  const ClientFormScreen({super.key, this.client});

  final Client? client; // null = create

  @override
  State<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends State<ClientFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl =
      TextEditingController(text: widget.client?.fullName ?? '');
  late final TextEditingController _phoneCtrl =
      TextEditingController(text: widget.client?.phone ?? '');
  late final TextEditingController _addressCtrl =
      TextEditingController(text: widget.client?.address ?? '');
  String _gender = 'homme';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.client != null) {
      _gender = widget.client!.gender;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final ClientsRepository repo = ClientsRepository();
    try {
      if (widget.client == null) {
        await repo.create(
          fullName: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          address: _addressCtrl.text.trim().isEmpty
              ? null
              : _addressCtrl.text.trim(),
          gender: _gender,
        );
      } else {
        await repo.update(
          widget.client!.id,
          fullName: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          address: _addressCtrl.text.trim().isEmpty
              ? null
              : _addressCtrl.text.trim(),
          gender: _gender,
        );
      }
      if (mounted) context.pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: CouturePalette.terracottaDeep,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.client != null;
    return CoutureScaffold(
      title: isEdit ? 'Modifier le client' : 'Nouveau client',
      subtitle: isEdit ? null : 'Nom et téléphone suffisent',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(CouturePalette.s4),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AppTextField(
                controller: _nameCtrl,
                label: 'Nom complet',
                hint: 'Amadou Traoré',
                prefixIcon: CoutureIcons.user,
                textInputAction: TextInputAction.next,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Le nom est obligatoire'
                    : null,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _phoneCtrl,
                label: 'Téléphone',
                hint: '70 00 00 00',
                prefixIcon: CoutureIcons.phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Le téléphone est obligatoire'
                    : null,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _addressCtrl,
                label: 'Adresse (facultatif)',
                hint: 'Quartier, ville…',
                prefixIcon: CoutureIcons.mapPin,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 16),
              Text(
                'Homme ou femme ?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: CoutureScheme.of(context).ink,
                ),
              ),
              const SizedBox(height: CouturePalette.s2),
              SegmentedButton<String>(
                segments: const <ButtonSegment<String>>[
                  // These labels used to read "Homme / Homme" and
                  // "Femme / Femme" — the leftover of a bilingual pair whose
                  // second half was translated into the first.
                  ButtonSegment<String>(
                    value: 'homme',
                    label: Text('Homme'),
                    icon: Icon(CoutureIcons.genderMale),
                  ),
                  ButtonSegment<String>(
                    value: 'femme',
                    label: Text('Femme'),
                    icon: Icon(CoutureIcons.genderFemale),
                  ),
                ],
                selected: <String>{_gender},
                onSelectionChanged: (Set<String> sel) {
                  setState(() => _gender = sel.first);
                },
              ),
              const SizedBox(height: 28),
              PrimaryButton(
                label: isEdit ? 'Enregistrer' : 'Ajouter le client',
                loading: _saving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
