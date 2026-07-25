import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/confirm_delete_dialog.dart';
import '../../../settings/presentation/providers/shop_settings_provider.dart';
import '../../data/pret_a_porter_repository.dart';

class ModelsShowcaseScreen extends StatefulWidget {
  const ModelsShowcaseScreen({super.key});

  @override
  State<ModelsShowcaseScreen> createState() => _ModelsShowcaseScreenState();
}

class _ModelsShowcaseScreenState extends State<ModelsShowcaseScreen> {
  final PretAPorterRepository _repo = PretAPorterRepository();
  final TextEditingController _searchCtrl = TextEditingController();
  List<PretAPorterModel> _allModels = [];
  List<PretAPorterModel> _filteredModels = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadModels() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repo.list();
      setState(() {
        _allModels = items;
        _applySearch();
      });
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _loading = false);
    }
  }

  void _applySearch() {
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) {
      _filteredModels = List.from(_allModels);
    } else {
      _filteredModels = _allModels.where((m) {
        return m.name.toLowerCase().contains(query) ||
            m.fabricType.toLowerCase().contains(query) ||
            (m.description ?? '').toLowerCase().contains(query);
      }).toList();
    }
  }

  void _viewModelShowcase(PretAPorterModel m) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) {
        final hasImg = m.media.any((x) => x.kind == 'image');

        final imgUrl = hasImg
            ? m.media.firstWhere((x) => x.kind == 'image').url
            : '';
        final resolvedImg = imgUrl.isNotEmpty
            ? (imgUrl.startsWith('http') ? imgUrl : '${ApiClient.baseUrl}$imgUrl')
            : '';

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          builder: (ctx, scrollCtrl) => ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Image / Video display
              if (resolvedImg.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 1.2,
                    child: CachedNetworkImage(
                      imageUrl: resolvedImg,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
                      errorWidget: (_, __, ___) => const Icon(Icons.broken_image, size: 50),
                    ),
                  ),
                )
              else
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Icon(Icons.checkroom_rounded, size: 64, color: AppColors.primary),
                  ),
                ),

              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      m.name,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      formatFcfa(m.price.toInt()),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),

              if (m.fabricType.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.texture_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Tissu recommandé: ${m.fabricType}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],

              if (m.description != null && m.description!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Description du Modèle',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 6),
                Text(
                  m.description!,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
              ],

              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add_shopping_cart_rounded),
                label: const Text('Commander ce modèle pour un client'),
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push('/admin/walk-in');
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Supprimer ce modèle'),
                onPressed: () async {
                  final confirm = await confirmDeleteByTyping(
                    context,
                    itemName: m.name,
                    itemLabel: 'ce modèle',
                    historyNote: 'Les commandes créées avec ce modèle restent enregistrées.',
                  );
                  if (confirm && ctx.mounted) {
                    Navigator.pop(ctx);
                    try {
                      await _repo.delete(m.id);
                      if (mounted) _loadModels();
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
                        );
                      }
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final shopName = context.watch<ShopSettingsProvider>().shopName;

    return Scaffold(
      appBar: AppBar(
        title: Text('$shopName — Mes Modèles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadModels,
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(_applySearch),
              decoration: InputDecoration(
                hintText: 'Rechercher un modèle ou un tissu...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(_applySearch);
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text('Erreur: $_error'))
                    : _filteredModels.isEmpty
                        ? const Center(child: Text('Aucun modèle d\'exposition trouvé.'))
                        : GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.75,
                            ),
                            itemCount: _filteredModels.length,
                            itemBuilder: (context, index) {
                              final m = _filteredModels[index];
                              final hasImg = m.media.any((x) => x.kind == 'image');
                              final imgUrl = hasImg ? m.media.firstWhere((x) => x.kind == 'image').url : '';
                              final resolvedImg = imgUrl.isNotEmpty
                                  ? (imgUrl.startsWith('http') ? imgUrl : '${ApiClient.baseUrl}$imgUrl')
                                  : '';

                              return Card(
                                elevation: 3,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () => _viewModelShowcase(m),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            if (resolvedImg.isNotEmpty)
                                              CachedNetworkImage(
                                                imageUrl: resolvedImg,
                                                fit: BoxFit.cover,
                                                placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
                                                errorWidget: (_, __, ___) => const Icon(Icons.broken_image, size: 40),
                                              )
                                            else
                                              Container(
                                                color: AppColors.primary.withValues(alpha: 0.1),
                                                child: const Icon(Icons.checkroom_rounded, size: 48, color: AppColors.primary),
                                              ),
                                            Positioned(
                                              top: 8,
                                              right: 8,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withValues(alpha: 0.65),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  formatFcfa(m.price.toInt()),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(10),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              m.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              m.fabricType.isNotEmpty ? m.fabricType : 'Modèle sur mesure',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
