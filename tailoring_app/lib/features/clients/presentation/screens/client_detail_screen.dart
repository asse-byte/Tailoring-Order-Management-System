import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/garment_types.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/section_header.dart';
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
      ]);
      if (!mounted) return;
      setState(() {
        _client = results[0] as Client;
        _measurements = results[1] as Map<String, Map<String, num>>;
        _orders = results[2] as List<ClientOrderSummary>;
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

  Future<void> _editClient() async {
    final bool? changed = await context.push<bool>(
        '/admin/clients/${widget.clientId}/edit',
        extra: _client);
    if (changed == true) {
      _changed = true;
      _load();
    }
  }

  Future<void> _openMeasurements(String garmentType) async {
    final bool? changed = await context.push<bool>(
      '/admin/clients/${widget.clientId}/measurements/'
      '${Uri.encodeComponent(garmentType)}',
      extra: _measurements[garmentType],
    );
    if (changed == true) {
      _changed = true;
      _load();
    }
  }

  Future<void> _pickGarmentType() async {
    final String? type = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: GarmentTypes.all
              .map((String t) => ListTile(
                    leading: const Icon(Icons.straighten_rounded),
                    title: Text(t),
                    trailing: _measurements.containsKey(t)
                        ? const Icon(Icons.check_circle_rounded,
                            color: AppColors.primary, size: 20)
                        : null,
                    onTap: () => Navigator.pop(ctx, t),
                  ))
              .toList(),
        ),
      ),
    );
    if (type != null) _openMeasurements(type);
  }

  String _statusLabel(String status) => AppConstants.statusLabel(status);

  Color _statusColor(String status) {
    switch (status) {
      case AppConstants.statusTermine:
        return Colors.orange;
      case AppConstants.statusLivre:
        return Colors.green;
      case AppConstants.statusEnAttente:
        return AppColors.textSecondary;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) context.pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_client?.fullName ?? 'Client'),
          actions: <Widget>[
            if (_client != null)
              IconButton(
                icon: const Icon(Icons.edit_rounded),
                onPressed: _editClient,
              ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _load, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }
    final Client client = _client!;
    final DateFormat dateFmt = DateFormat('dd/MM/yyyy');

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: <Widget>[
          // ---- contact card ----
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(children: <Widget>[
                    const Icon(Icons.phone_rounded,
                        size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Text(client.phone,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ]),
                  if (client.address != null && client.address!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(children: <Widget>[
                        const Icon(Icons.location_on_rounded,
                            size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(child: Text(client.address!)),
                      ]),
                    ),
                  if (client.createdAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Client depuis le ${dateFmt.format(client.createdAt!)}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ---- measurements ----
          SectionHeader(
            title: 'Mensurations',
            action: TextButton.icon(
              onPressed: _pickGarmentType,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Ajouter'),
            ),
          ),
          if (_measurements.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Aucune mensuration enregistrée.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _measurements.entries
                  .map((MapEntry<String, Map<String, num>> e) => ActionChip(
                        avatar: const Icon(Icons.straighten_rounded, size: 18),
                        label: Text('${e.key} (${e.value.length})'),
                        onPressed: () => _openMeasurements(e.key),
                      ))
                  .toList(),
            ),
          const SizedBox(height: 20),

          // ---- order history ----
          const SectionHeader(title: 'Commandes'),
          if (_orders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Aucune commande pour ce client.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
            ..._orders.map((ClientOrderSummary order) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(Icons.checkroom_rounded,
                        color: _statusColor(order.status)),
                    title: Text(order.garmentType),
                    subtitle: Text(order.createdAt != null
                        ? dateFmt.format(order.createdAt!)
                        : ''),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text(
                          formatFcfa(order.total),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _statusLabel(order.status),
                          style: TextStyle(
                            fontSize: 12,
                            color: _statusColor(order.status),
                            fontWeight: FontWeight.w600,
                          ),
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
