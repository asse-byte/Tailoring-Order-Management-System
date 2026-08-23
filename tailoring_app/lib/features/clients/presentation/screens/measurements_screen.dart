import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/garment_types.dart';
import '../../../../core/theme/couture_icons.dart';
import '../../../../core/theme/couture_palette.dart';
import '../../../../core/widgets/couture/couture_scaffold.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/clients_repository.dart';

/// Flexible measurements editor for one client + one garment type:
/// suggested fields for the type, existing values, plus custom fields.
/// Values are centimetres (numbers); empty fields are simply not saved.
class MeasurementsScreen extends StatefulWidget {
  const MeasurementsScreen({
    super.key,
    required this.clientId,
    required this.garmentType,
    this.initial,
    this.suggestedFields,
  });

  final String clientId;
  final String garmentType;
  final Map<String, num>? initial;
  final List<String>? suggestedFields;

  @override
  State<MeasurementsScreen> createState() => _MeasurementsScreenState();
}

class _MeasurementsScreenState extends State<MeasurementsScreen> {
  final Map<String, TextEditingController> _fields =
      <String, TextEditingController>{};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Union: suggested fields for this garment type + already-saved keys.
    final List<String> suggested = widget.suggestedFields ??
        GarmentTypes.defaultFields[widget.garmentType] ??
        <String>[];
    for (final String field in suggested) {
      _fields[field] =
          TextEditingController(text: widget.initial?[field]?.toString() ?? '');
    }
    widget.initial?.forEach((String key, num value) {
      _fields.putIfAbsent(
          key, () => TextEditingController(text: value.toString()));
    });
  }

  @override
  void dispose() {
    for (final TextEditingController c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _addCustomField() async {
    final TextEditingController ctrl = TextEditingController();
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Nouveau champ'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ex: Tour de bras'),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Ajouter')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && !_fields.containsKey(name)) {
      setState(() => _fields[name] = TextEditingController());
    }
  }

  Future<void> _save() async {
    final Map<String, num> measures = <String, num>{};
    for (final MapEntry<String, TextEditingController> e in _fields.entries) {
      final num? value = num.tryParse(e.value.text.trim().replaceAll(',', '.'));
      if (value != null) measures[e.key] = value;
    }
    setState(() => _saving = true);
    try {
      await ClientsRepository()
          .saveMeasurements(widget.clientId, widget.garmentType, measures);
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
    final List<String> keys = _fields.keys.toList();
    final CoutureScheme c = CoutureScheme.of(context);
    return CoutureScaffold(
      title: 'Les mesures',
      subtitle: widget.garmentType,
      bottomBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: PrimaryButton(
            label: 'Enregistrer les mesures',
            loading: _saving,
            onPressed: _save,
          ),
        ),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
            CouturePalette.s4, CouturePalette.s4, CouturePalette.s4, 120),
        itemCount: keys.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (BuildContext context, int index) {
          if (index == keys.length) {
            return OutlinedButton.icon(
              onPressed: _addCustomField,
              style: OutlinedButton.styleFrom(
                foregroundColor: c.inkList,
                side: BorderSide(color: c.line),
                minimumSize: const Size.fromHeight(CouturePalette.minTouch),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(CoutureIcons.plus, size: 18),
              label: const Text('Ajouter une mesure'),
            );
          }
          final String field = keys[index];
          return TextField(
            controller: _fields[field],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: field,
              suffixText: 'cm',
            ),
          );
        },
      ),
    );
  }
}
