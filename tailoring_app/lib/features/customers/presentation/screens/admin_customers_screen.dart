import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../providers/admin_customers_provider.dart';

class AdminCustomersScreen extends StatefulWidget {
  const AdminCustomersScreen({super.key});

  @override
  State<AdminCustomersScreen> createState() => _AdminCustomersScreenState();
}

class _AdminCustomersScreenState extends State<AdminCustomersScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final isFr = loc.locale.languageCode == 'fr';
    return ChangeNotifierProvider<AdminCustomersProvider>(
      create: (_) => AdminCustomersProvider(),
      child: Builder(
        builder: (context) {
          final p = context.watch<AdminCustomersProvider>();
          final list = p.filtered;
          return Scaffold(
            appBar: AppBar(title: Text(loc.customers)),
            body: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: p.setQuery,
                    decoration: InputDecoration(
                      hintText: loc.searchCustomer,
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: p.query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                p.setQuery('');
                              },
                            ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: <Widget>[
                      Text(
                        isFr
                            ? '${p.customers.length} client${p.customers.length == 1 ? '' : 's'}'
                            : '${p.customers.length} customer${p.customers.length == 1 ? '' : 's'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (p.query.isNotEmpty) ...<Widget>[
                        const SizedBox(width: 8),
                        Text(
                          isFr
                              ? ' · ${list.length} correspondant${list.length == 1 ? '' : 's'}'
                              : ' · ${list.length} match${list.length == 1 ? '' : 'es'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(child: _body(p, list)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _body(AdminCustomersProvider p, List<AppUser> list) {
    final loc = context.loc;
    final isFr = loc.locale.languageCode == 'fr';
    if (p.loading) return LoadingShimmer.list();
    if (p.error != null) {
      return EmptyState(
        title: isFr
            ? 'Impossible de charger les clients'
            : 'Could not load customers',
        message: p.error,
        icon: Icons.error_outline,
      );
    }
    if (list.isEmpty) {
      return EmptyState(
        title: p.customers.isEmpty
            ? (isFr ? 'Aucun client pour le moment' : 'No customers yet')
            : (isFr
                ? 'Aucun résultat correspondant'
                : 'Nothing matches your search'),
        message: p.customers.isEmpty
            ? (isFr
                ? 'Lorsque des clients s\'inscriront, ils apparaîtront ici.'
                : 'When customers register, they’ll appear here.')
            : (isFr
                ? 'Essayez de chercher un autre nom, téléphone ou e-mail.'
                : 'Try a different name, phone or email.'),
        icon: Icons.people_outline_rounded,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _CustomerTile(user: list[i]),
    );
  }
}

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final isFr = loc.locale.languageCode == 'fr';
    return Material(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/admin/customer/${user.id}'),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: <Widget>[
              _Avatar(url: user.profilePhotoUrl, name: user.name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      user.name.isEmpty
                          ? (isFr ? '(sans nom)' : '(no name)')
                          : user.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.phone.isEmpty ? user.email : user.phone,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.name});
  final String? url;
  final String name;

  @override
  Widget build(BuildContext context) {
    final String initial = name.isEmpty ? '?' : name.trim()[0].toUpperCase();
    if (url == null || url!.isEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
        child: Text(
          initial,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url!,
        height: 44,
        width: 44,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          child: Text(initial),
        ),
      ),
    );
  }
}
