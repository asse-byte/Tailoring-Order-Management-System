import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../domain/client.dart';
import '../providers/clients_provider.dart';

/// Clients list: instant (debounced) search by name or phone + infinite
/// scroll pagination. Available to both roles.
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
      client == null ? '/admin/clients/new' : '/admin/clients/${client.id}/edit',
      extra: client,
    );
    if (changed == true && mounted) {
      context.read<ClientsProvider>().refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ClientsProvider provider = context.watch<ClientsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Clients')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Nouveau client'),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Rechercher par nom ou téléphone…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearchChanged('');
                          setState(() {});
                        },
                      ),
              ),
            ),
          ),
          Expanded(child: _body(provider)),
        ],
      ),
    );
  }

  Widget _body(ClientsProvider provider) {
    if (provider.error != null && provider.items.isEmpty) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Erreur de connexion',
        message: provider.error,
        actionLabel: 'Réessayer',
        onAction: () => provider.refresh(),
      );
    }
    if (provider.loading && provider.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.items.isEmpty) {
      return const EmptyState(
        icon: Icons.people_outline_rounded,
        title: 'Aucun client',
        message: 'Ajoutez votre premier client avec le bouton ci-dessous.',
      );
    }
    return RefreshIndicator(
      onRefresh: () => provider.refresh(),
      child: ListView.separated(
        controller: _scrollCtrl,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        itemCount: provider.items.length + (provider.hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (BuildContext context, int index) {
          if (index >= provider.items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final Client client = provider.items[index];
          return Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  client.fullName.isNotEmpty
                      ? client.fullName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(client.fullName,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(client.phone),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/admin/clients/${client.id}'),
            ),
          );
        },
      ),
    );
  }
}
