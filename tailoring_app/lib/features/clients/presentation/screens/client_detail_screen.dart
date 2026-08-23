import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/garment_types.dart';
import '../../../../core/theme/couture_icons.dart';
import '../../../../core/theme/couture_palette.dart';
import '../../../../core/widgets/couture/couture_bits.dart';
import '../../../../core/widgets/couture/couture_scaffold.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/whatsapp.dart';
import '../../../../core/widgets/confirm_delete_dialog.dart';
import '../../data/clients_repository.dart';
import '../../domain/client.dart';

/// Client file: contact info, measurements per garment type, order history.
class ClientDetailScreen extends StatefulWidget {
  const ClientDetailScreen({super.key, required this.clientId});

  final String clientId;

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  final ClientsRepository _repo = ClientsRepository();

  Client? _client;
  Map<String, Map<String, num>> _measurements = <String, Map<String, num>>{};
  List<ClientOrderSummary> _orders = <ClientOrderSummary>[];
  Map<String, dynamic> _customGarments = <String, dynamic>{
    'homme': <String, dynamic>{},
    'femme': <String, dynamic>{}
  };
  bool _loading = true;
  String? _error;
  bool _changed = false;

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
      final List<dynamic> results = await Future.wait(<Future<dynamic>>[
        _repo.getById(widget.clientId),
        _repo.measurements(widget.clientId),
        _repo.orders(widget.clientId),
        _repo.getCustomGarments(),
      ]);
      if (!mounted) return;
      setState(() {
        _client = results[0] as Client;
        _measurements = results[1] as Map<String, Map<String, num>>;
        _orders = results[2] as List<ClientOrderSummary>;
        _customGarments = results[3] as Map<String, dynamic>;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  /// Opens the WhatsApp conversation with this client (no prefilled text —
  /// this is a plain "contact the client" shortcut, not an order message).
  Future<void> _openWhatsApp() async {
    final bool ok = await openWhatsApp(_client?.phone);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d\'ouvrir WhatsApp pour ce numéro.'),
          backgroundColor: CouturePalette.terracottaDeep,
        ),
      );
    }
  }

  Future<void> _editClient() async {
    final bool? changed = await context
        .push<bool>('/admin/clients/${widget.clientId}/edit', extra: _client);
    if (changed == true) {
      _changed = true;
      _load();
    }
  }

  Future<void> _deleteClient() async {
    final bool confirm = await confirmDeleteByTyping(
      context,
      itemName: _client?.fullName ?? '',
      itemLabel: 'ce client',
      historyNote: 'Les commandes déjà livrées de ce client restent '
          'conservées dans l\'Historique (au nom mémorisé), même après '
          'la suppression de sa fiche.',
    );
    if (!confirm) return;
    try {
      await _repo.remove(widget.clientId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client supprimé.')),
      );
      _changed = true;
      context.pop(true); // back to the list, which refreshes on a true result
    } catch (e) {
      if (!mounted) return;
      // A client with linked orders cannot be deleted (history is preserved):
      // the API returns a clear French 409 message — surface it as-is.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(e.toString()),
            backgroundColor: CouturePalette.terracottaDeep),
      );
    }
  }

  Future<void> _openMeasurements(String garmentType,
      {List<String>? suggestedFields}) async {
    final bool? changed = await context.push<bool>(
      '/admin/clients/${widget.clientId}/measurements/'
      '${Uri.encodeComponent(garmentType)}',
      extra: <String, dynamic>{
        'initial': _measurements[garmentType],
        'suggestedFields': suggestedFields,
      },
    );
    if (changed == true) {
      _changed = true;
      _load();
    }
  }

  Future<void> _pickGarmentType() async {
    final String gender = _client?.gender ?? 'homme';
    final List<String> standardList = gender == 'femme'
        ? GarmentTypes.femaleGarments
        : GarmentTypes.maleGarments;

    final Map<String, dynamic> customForGender =
        (_customGarments[gender] as Map<String, dynamic>?) ??
            <String, dynamic>{};
    final List<String> customList = customForGender.keys.toList();

    // Union: standard models + custom models
    final List<String> choices = <String>[
      ...standardList.where((String x) => x != 'Autres'),
      ...customList,
      'Autres',
    ];

    final String? type = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: choices
              .map((String t) => ListTile(
                    leading: Icon(CoutureIcons.coatHanger,
                        color: CoutureScheme.of(context).inkSoft),
                    title: Text(t),
                    trailing: _measurements.containsKey(t)
                        ? Icon(CoutureIcons.checkCircle,
                            color: CoutureScheme.of(context).goodInk, size: 20)
                        : null,
                    onTap: () => Navigator.pop(ctx, t),
                  ))
              .toList(),
        ),
      ),
    );

    if (type == null) return;
    if (!mounted) return;

    if (type == 'Autres') {
      final TextEditingController nameCtrl = TextEditingController();
      final TextEditingController fieldsCtrl = TextEditingController(
        text: gender == 'femme'
            ? GarmentTypes.defaultFields['Robe']!.join(', ')
            : GarmentTypes.defaultFields['Grand Boubou']!.join(', '),
      );

      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          title: const Text('Nouveau modèle personnalisé'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'Nom du modèle (Ex: Gagny Lah)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: fieldsCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Champs de mesure (séparés par des virgules)',
                  helperText: 'Ex: LB, LM, TM, E, P',
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler')),
            TextButton(
              onPressed: () {
                if (nameCtrl.text.trim().isNotEmpty) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Créer'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        final String newName = nameCtrl.text.trim();
        final List<String> newFields = fieldsCtrl.text
            .split(',')
            .map((String s) => s.trim())
            .where((String s) => s.isNotEmpty)
            .toList();

        final Map<String, dynamic> customForGenderMutable =
            Map<String, dynamic>.from(customForGender);
        customForGenderMutable[newName] = newFields;
        _customGarments[gender] = customForGenderMutable;

        setState(() {
          _loading = true;
        });

        try {
          await _repo.saveCustomGarments(_customGarments);
          await _load();
          if (mounted) {
            _openMeasurements(newName, suggestedFields: newFields);
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _loading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(e.toString()),
              backgroundColor: CouturePalette.terracottaDeep,
            ));
          }
        }
      }
    } else {
      final List<String>? customFields = customList.contains(type)
          ? List<String>.from(customForGender[type] as Iterable<dynamic>)
          : null;
      _openMeasurements(type, suggestedFields: customFields);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) context.pop(_changed);
      },
      child: CoutureScaffold(
        title: _client?.fullName ?? 'Client',
        subtitle: _client?.phone,
        onBack: () => context.pop(_changed),
        actions: <Widget>[
          // Direct WhatsApp chat, only when the number is usable.
          if (_client != null && canWhatsApp(_client!.phone))
            CoutureBandAction(
              icon: CoutureIcons.whatsapp,
              tooltip: 'Écrire sur WhatsApp',
              onPressed: _openWhatsApp,
            ),
          if (_client != null)
            CoutureBandAction(
              icon: CoutureIcons.pencil,
              tooltip: 'Modifier',
              onPressed: _editClient,
            ),
          if (_client != null)
            CoutureBandAction(
              icon: CoutureIcons.trash,
              tooltip: 'Supprimer',
              onPressed: _deleteClient,
            ),
        ],
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return const CoutureEmpty(
        icon: CoutureIcons.warningCircle,
        tone: CoutureTone.urgent,
        title: 'La fiche ne s\'affiche pas',
        message: 'Vérifiez la connexion, puis tirez vers le bas.',
      );
    }
    final Client client = _client!;
    final DateFormat dateFmt = DateFormat('dd/MM/yyyy');
    final CoutureScheme c = CoutureScheme.of(context);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(CouturePalette.s4, CouturePalette.s4,
            CouturePalette.s4, CouturePalette.s8),
        children: <Widget>[
          // ---- contact card ----
          CoutureCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(children: <Widget>[
                  Icon(CoutureIcons.phone, size: 17, color: c.iconInk),
                  const SizedBox(width: CouturePalette.s2),
                  Text(client.phone,
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: c.ink)),
                ]),
                if (client.address != null && client.address!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: CouturePalette.s2),
                    child: Row(children: <Widget>[
                      Icon(CoutureIcons.storefront, size: 17, color: c.iconInk),
                      const SizedBox(width: CouturePalette.s2),
                      Expanded(
                          child: Text(client.address!,
                              style:
                                  TextStyle(fontSize: 13.5, color: c.inkList))),
                    ]),
                  ),
                if (client.createdAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: CouturePalette.s2),
                    child: Text(
                      'Client depuis le ${dateFmt.format(client.createdAt!)}',
                      style: TextStyle(fontSize: 12, color: c.inkFaint),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: CouturePalette.s6),

          // ---- measurements ----
          Row(
            children: <Widget>[
              Expanded(
                child: Text('LES MESURES',
                    style: CouturePalette.sectionLabel
                        .copyWith(color: c.inkFaint)),
              ),
              TextButton.icon(
                onPressed: _pickGarmentType,
                icon: const Icon(CoutureIcons.plus, size: 16),
                label: const Text('Ajouter'),
                style: TextButton.styleFrom(foregroundColor: c.iconInk),
              ),
            ],
          ),
          if (_measurements.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: CouturePalette.s3),
              child: Text(
                'Aucune mesure notée. Appuyez sur « Ajouter ».',
                style: TextStyle(fontSize: 13, color: c.inkFaint),
              ),
            )
          else
            Wrap(
              spacing: CouturePalette.s2,
              runSpacing: CouturePalette.s2,
              children: _measurements.entries
                  .map((MapEntry<String, Map<String, num>> e) => ActionChip(
                        backgroundColor: c.quiet,
                        side: BorderSide(color: c.line),
                        labelStyle: TextStyle(fontSize: 12.5, color: c.inkList),
                        avatar: Icon(CoutureIcons.coatHanger,
                            size: 16, color: c.inkSoft),
                        label: Text('${e.key} (${e.value.length})'),
                        onPressed: () {
                          final String gender = _client?.gender ?? 'homme';
                          final Map<String, dynamic>? customForGender =
                              _customGarments[gender] as Map<String, dynamic>?;
                          final List<String>? customFields =
                              customForGender?[e.key] != null
                                  ? List<String>.from(customForGender![e.key]
                                      as Iterable<dynamic>)
                                  : null;
                          _openMeasurements(e.key,
                              suggestedFields: customFields);
                        },
                      ))
                  .toList(),
            ),
          const SizedBox(height: 20),

          // ---- order history ----
          Text('SES COMMANDES',
              style: CouturePalette.sectionLabel.copyWith(color: c.inkFaint)),
          const SizedBox(height: CouturePalette.s2),
          if (_orders.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: CouturePalette.s3),
              child: Text(
                'Ce client n\'a encore rien commandé.',
                style: TextStyle(fontSize: 13, color: c.inkFaint),
              ),
            )
          else
            ..._orders.map((ClientOrderSummary order) => Padding(
                  padding: const EdgeInsets.only(bottom: CouturePalette.s2),
                  child: CoutureCard(
                    padding: const EdgeInsets.all(CouturePalette.s3),
                    child: Row(
                      children: <Widget>[
                        const CoutureWash(
                            icon: CoutureIcons.coatHanger,
                            size: 38,
                            iconSize: 19),
                        const SizedBox(width: CouturePalette.s3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(order.garmentType,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600,
                                      color: c.ink)),
                              Text(
                                  order.createdAt != null
                                      ? dateFmt.format(order.createdAt!)
                                      : '',
                                  style: TextStyle(
                                      fontSize: 12.5, color: c.inkSoft)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Text(
                              formatFcfa(order.total),
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: c.ink),
                            ),
                            const SizedBox(height: 3),
                            CoutureStatusPill(
                                status: order.status, compact: true),
                          ],
                        ),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}
