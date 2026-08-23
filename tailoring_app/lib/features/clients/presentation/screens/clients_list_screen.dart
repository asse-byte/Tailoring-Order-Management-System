import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/couture_icons.dart';
import '../../../../core/theme/couture_palette.dart';
import '../../../../core/utils/whatsapp.dart';
import '../../../../core/widgets/couture/couture_bits.dart';
import '../../../../core/widgets/couture/couture_scaffold.dart';
import '../../domain/client.dart';
import '../providers/clients_provider.dart';

/// Clients list: instant (debounced) search by name or phone + infinite
/// scroll pagination. Available to both roles.
///
/// Redesigned onto "Indigo & Terre". The debounce, the pagination and the
/// routes are untouched — this only changes what is drawn.
class ClientsListScreen extends StatefulWidget {
  const ClientsListScreen({super.key});

  @override
  State<ClientsListScreen> createState() => _ClientsListScreenState();
}

class _ClientsListScreenState extends State<ClientsListScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ClientsProvider>().refresh(search: '');
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >
        _scrollCtrl.position.maxScrollExtent - 300) {
      context.read<ClientsProvider>().loadMore();
    }
  }

  // Debounce ~300ms: one request per pause in typing, not per keystroke.
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final String trimmed = value.trim();
      if (trimmed.isNotEmpty && trimmed.length < 2) {
        return;
      }
      if (mounted) context.read<ClientsProvider>().refresh(search: trimmed);
    });
  }

  Future<void> _openForm({Client? client}) async {
    final bool? changed = await context.push<bool>(
      client == null
          ? '/admin/clients/new'
          : '/admin/clients/${client.id}/edit',
      extra: client,
    );
    if (changed == true && mounted) {
      context.read<ClientsProvider>().refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ClientsProvider provider = context.watch<ClientsProvider>();
    final CoutureScheme c = CoutureScheme.of(context);

    return CoutureScaffold(
      title: 'Clients',
      subtitle: 'Chercher un client, ou en ajouter un',
      below: Padding(
        padding: const EdgeInsets.fromLTRB(
            CouturePalette.s4, CouturePalette.s3, CouturePalette.s4, 0),
        child: CoutureSearchField(
          controller: _searchCtrl,
          hint: 'Nom ou téléphone',
          onChanged: (String v) {
            _onSearchChanged(v);
            setState(() {}); // the clear button follows the first letter
          },
          onClear: () {
            _searchCtrl.clear();
            _onSearchChanged('');
            setState(() {});
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: c.urgentInk,
        foregroundColor: Colors.white,
        elevation: 2,
        onPressed: () => _openForm(),
        icon: const Icon(CoutureIcons.plus, size: 20),
        label: const Text('Nouveau client',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      child: _body(provider),
    );
  }

  Widget _body(ClientsProvider provider) {
    if (provider.error != null && provider.items.isEmpty) {
      return const CoutureEmpty(
        icon: CoutureIcons.warningCircle,
        tone: CoutureTone.urgent,
        title: 'Pas de connexion',
        message: 'Tirez vers le bas pour réessayer.',
      );
    }
    if (provider.loading && provider.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.items.isEmpty) {
      return const CoutureEmpty(
        icon: CoutureIcons.user,
        title: 'Aucun client',
        message: 'Appuyez sur « Nouveau client » pour enregistrer le premier.',
      );
    }
    return RefreshIndicator(
      onRefresh: () => provider.refresh(),
      child: ListView.separated(
        controller: _scrollCtrl,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
            CouturePalette.s4, CouturePalette.s3, CouturePalette.s4, 96),
        itemCount: provider.items.length + (provider.hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: CouturePalette.s2),
        itemBuilder: (BuildContext context, int index) {
          if (index >= provider.items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: CouturePalette.s4),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _ClientRow(
            client: provider.items[index],
            onOpen: () async {
              final ClientsProvider p = context.read<ClientsProvider>();
              final bool? changed = await context
                  .push<bool>('/admin/clients/${provider.items[index].id}');
              if (changed == true && mounted) p.refresh();
            },
          );
        },
      ),
    );
  }
}

class _ClientRow extends StatelessWidget {
  const _ClientRow({required this.client, required this.onOpen});

  final Client client;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final CoutureScheme c = CoutureScheme.of(context);
    final bool whatsApp = canWhatsApp(client.phone);

    return CoutureCard(
      onTap: onOpen,
      padding: const EdgeInsets.fromLTRB(CouturePalette.s3,
          CouturePalette.s2 + 2, CouturePalette.s2, CouturePalette.s2 + 2),
      child: Row(
        children: <Widget>[
          // The client's initial, not a generic silhouette: in a list of forty
          // names the letter is what the eye actually finds.
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.iconWash,
              shape: BoxShape.circle,
            ),
            child: Text(
              client.fullName.isNotEmpty
                  ? client.fullName.characters.first.toUpperCase()
                  : '?',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: c.iconInk,
              ),
            ),
          ),
          const SizedBox(width: CouturePalette.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  client.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  client.phone.isEmpty ? 'Pas de téléphone' : client.phone,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: c.inkSoft),
                ),
              ],
            ),
          ),
          // Shown only when the stored number can actually be dialled, so the
          // button never opens on nothing.
          if (whatsApp)
            IconButton(
              tooltip: 'Écrire sur WhatsApp',
              icon: Icon(CoutureIcons.whatsapp, size: 21, color: c.goodInk),
              onPressed: () async {
                final ScaffoldMessengerState messenger =
                    ScaffoldMessenger.of(context);
                final bool ok = await openWhatsApp(client.phone);
                if (!ok) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: const Text(
                          'WhatsApp ne s\'ouvre pas avec ce numéro.'),
                      backgroundColor: c.urgentInk,
                    ),
                  );
                }
              },
            ),
          Icon(CoutureIcons.caretRight, size: 16, color: c.inkFaint),
          const SizedBox(width: CouturePalette.s1),
        ],
      ),
    );
  }
}
