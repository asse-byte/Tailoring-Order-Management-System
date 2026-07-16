import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/formatted_number_field.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/products_provider.dart';
import '../../domain/product.dart';
import '../../data/products_repository.dart';
import '../../../settings/presentation/providers/shop_settings_provider.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ProductsProvider>().loadProducts(clear: true);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels > _scrollCtrl.position.maxScrollExtent - 200) {
      context.read<ProductsProvider>().loadProducts();
    }
  }

  String _mapCategoryToFrench(String cat) {
    switch (cat) {
      case 'parfum':
        return 'Parfums';
      case 'chaussure':
        return 'Chaussures';
      case 'tissu':
        return 'Tissus';
      default:
        return cat;
    }
  }

  Future<void> _recordSale(Product product) async {
    final formKey = GlobalKey<FormState>();
    int qty = 1;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Vendre / Sell - ${product.name}'),
        content: Form(
          key: formKey,
          child: TextFormField(
            decoration: const InputDecoration(
              labelText: 'Quantité à vendre',
              suffixText: 'unités',
            ),
            keyboardType: TextInputType.number,
            initialValue: '1',
            validator: (v) {
              final val = int.tryParse(v ?? '');
              if (val == null || val < 1) return 'Quantité invalide';
              if (val > product.quantity) return 'Stock insuffisant (${product.quantity} dispo)';
              return null;
            },
            onSaved: (v) => qty = int.tryParse(v ?? '') ?? 1,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                formKey.currentState!.save();
                Navigator.pop(ctx);
                final success = await context.read<ProductsProvider>().sellProduct(product.id, qty);
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vente enregistrée avec succès !'), backgroundColor: AppColors.success),
                  );
                } else if (mounted) {
                  final err = context.read<ProductsProvider>().error ?? 'Une erreur est survenue.';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(err), backgroundColor: AppColors.error),
                  );
                }
              }
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  Future<void> _openProductForm({Product? product}) async {
    final formKey = GlobalKey<FormState>();
    String name = product?.name ?? '';
    String category = product?.category ?? 'parfum';
    double price = product?.price ?? 0.0;
    double costPrice = product?.costPrice ?? 0.0;
    int quantity = product?.quantity ?? 0;
    int lowStockThreshold = product?.lowStockThreshold ?? 3;
    final priceCtrl = TextEditingController(text: price > 0 ? formatThousands(price.toInt()) : '');
    final costCtrl = TextEditingController(text: costPrice > 0 ? formatThousands(costPrice.toInt()) : '');
    final qtyCtrl = TextEditingController(text: product != null ? formatThousands(quantity) : '');
    final thresholdCtrl = TextEditingController(text: formatThousands(lowStockThreshold));
    XFile? selectedImage;
    Uint8List? selectedBytes; // in-memory preview, works on web + mobile
    bool uploadingImage = false;
    final String? currentImageUrl = product?.images.isNotEmpty == true ? product!.images.first.url : null;
    final String? currentThumbUrl = product?.images.isNotEmpty == true ? product!.images.first.thumbUrl : null;

    final ImagePicker picker = ImagePicker();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(product == null ? 'Nouveau Produit' : 'Modifier Produit'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: name,
                    decoration: const InputDecoration(labelText: 'Nom du produit'),
                    validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                    onSaved: (v) => name = v ?? '',
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Catégorie'),
                    items: const [
                      DropdownMenuItem(value: 'parfum', child: Text('Parfums')),
                      DropdownMenuItem(value: 'chaussure', child: Text('Chaussures')),
                      DropdownMenuItem(value: 'tissu', child: Text('Tissus')),
                    ],
                    onChanged: (v) => setDlgState(() => category = v ?? 'parfum'),
                  ),
                  const SizedBox(height: 12),
                  FormattedNumberField(
                    controller: priceCtrl,
                    label: 'Prix de vente (FCFA)',
                    validator: (v) => v == null ? 'Prix invalide' : null,
                    onChanged: (v) => setDlgState(() => price = (v ?? 0).toDouble()),
                  ),
                  const SizedBox(height: 12),
                  FormattedNumberField(
                    controller: costCtrl,
                    label: 'Prix d\'achat (FCFA)',
                    validator: (v) => v == null ? 'Prix d\'achat invalide' : null,
                    onChanged: (v) => setDlgState(() => costPrice = (v ?? 0).toDouble()),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Bénéfice unitaire: ${formatFcfa((price - costPrice).toInt())}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: (price - costPrice) >= 0 ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FormattedNumberField(
                    controller: qtyCtrl,
                    label: 'Quantité en stock',
                    suffixText: null,
                    validator: (v) => v == null ? 'Quantité invalide' : null,
                    onChanged: (v) => quantity = v ?? 0,
                  ),
                  const SizedBox(height: 12),
                  FormattedNumberField(
                    controller: thresholdCtrl,
                    label: 'Seuil d\'alerte stock bas',
                    suffixText: null,
                    validator: (v) => v == null ? 'Seuil invalide' : null,
                    onChanged: (v) => lowStockThreshold = v ?? 3,
                  ),
                  const SizedBox(height: 16),
                  
                  // Image selection UI
                  Row(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey[350]!),
                        ),
                        child: selectedBytes != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(selectedBytes!, fit: BoxFit.cover),
                              )
                            : (currentImageUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: CachedNetworkImage(
                                      imageUrl: currentImageUrl.startsWith('http')
                                          ? currentImageUrl
                                          : '${ApiClient.baseUrl}$currentImageUrl',
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
                                      errorWidget: (_, __, ___) => const Icon(Icons.image_not_supported_rounded),
                                    ),
                                  )
                                : const Icon(Icons.image_rounded, color: Colors.grey)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ElevatedButton.icon(
                              onPressed: uploadingImage
                                  ? null
                                  : () async {
                                      // ImagePicker handles simple compression via quality parameters
                                      final XFile? file = await picker.pickImage(
                                        source: ImageSource.gallery,
                                        maxWidth: 800,
                                        maxHeight: 800,
                                        imageQuality: 85,
                                      );
                                      if (file != null) {
                                        final bytes = await file.readAsBytes();
                                        setDlgState(() {
                                          selectedImage = file;
                                          selectedBytes = bytes;
                                        });
                                      }
                                    },
                              icon: const Icon(Icons.photo_library_rounded, size: 16),
                              label: const Text('Choisir une image'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                            ),
                            if (uploadingImage)
                              const Padding(
                                padding: EdgeInsets.only(top: 4.0),
                                child: LinearProgressIndicator(),
                              ),
                          ],
                        ),
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: uploadingImage ? null : () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: uploadingImage
                  ? null
                  : () async {
                      if (formKey.currentState!.validate()) {
                        formKey.currentState!.save();
                        final provider = context.read<ProductsProvider>();
                        final messenger = ScaffoldMessenger.of(context);
                        setDlgState(() => uploadingImage = true);

                        final List<Map<String, String>> imgList = [];
                        if (selectedImage != null) {
                          final uploaded = await provider.uploadImage(selectedImage!);
                          if (uploaded != null) {
                            imgList.add({
                              'url': uploaded['url']!,
                              'thumb_url': uploaded['thumb_url'] ?? '',
                            });
                          }
                        } else if (currentImageUrl != null) {
                          imgList.add({
                            'url': currentImageUrl,
                            'thumb_url': currentThumbUrl ?? '',
                          });
                        }

                        bool success;
                        if (product == null) {
                          success = await provider.addProduct(
                            name: name,
                            category: category,
                            price: price,
                            costPrice: costPrice,
                            quantity: quantity,
                            lowStockThreshold: lowStockThreshold,
                            images: imgList,
                          );
                        } else {
                          success = await provider.editProduct(
                            product.id,
                            name: name,
                            category: category,
                            price: price,
                            costPrice: costPrice,
                            quantity: quantity,
                            lowStockThreshold: lowStockThreshold,
                            images: imgList,
                          );
                        }

                        setDlgState(() => uploadingImage = false);
                        if (success) {
                          if (ctx.mounted) Navigator.pop(ctx);
                        } else {
                          messenger.showSnackBar(
                            SnackBar(content: Text(provider.error ?? 'Erreur d\'enregistrement'), backgroundColor: AppColors.error),
                          );
                        }
                      }
                    },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showProductDetails(Product p) async {
    final bool isManager = !context.read<AuthProvider>().isSecretary;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          p.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _detailRow('Catégorie', _mapCategoryToFrench(p.category)),
                  _detailRow('Prix de vente', formatFcfa(p.price.toInt())),
                  _detailRow('Stock actuel', '${p.quantity} unités'),
                  if (isManager) ...[
                    _detailRow('Prix d\'achat', formatFcfa(p.costPrice.toInt())),
                    const SizedBox(height: 16),
                    const Text(
                      'Statistiques de vente',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<Map<String, dynamic>>(
                      future: ProductsRepository().getStats(p.id),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        if (snapshot.hasError) {
                          return Text(
                            'Erreur: ${snapshot.error}',
                            style: const TextStyle(color: AppColors.error),
                          );
                        }
                        final stats = snapshot.data!;
                        final int totalSold = stats['total_sold'] as int;
                        final int totalRevenue = stats['total_revenue'] as int;
                        final int totalProfit = stats['total_profit'] as int;

                        return Column(
                          children: [
                            _detailRow('Quantité vendue', '$totalSold unités'),
                            _detailRow('Ventes totales', formatFcfa(totalRevenue)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Bénéfice/Perte total'),
                                Text(
                                  formatFcfa(totalProfit),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: totalProfit >= 0
                                        ? AppColors.success
                                        : AppColors.error,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductsProvider>();
    final auth = context.watch<AuthProvider>();
    final isSec = auth.isSecretary;

    // Client-side search filtering over fetched items
    final filtered = provider.items.where((p) {
      final matchesSearch = p.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesSearch;
    }).toList();

    final shopName = context.watch<ShopSettingsProvider>().shopName;

    return Scaffold(
      appBar: AppBar(
        title: Text('$shopName - Produits'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => provider.refresh(),
          )
        ],
      ),
      floatingActionButton: isSec
          ? null // Writes are manager-only
          : FloatingActionButton(
              onPressed: () => _openProductForm(),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add_rounded, color: Colors.white),
            ),
      body: Column(
        children: [
          // Search & Filter header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Rechercher un produit...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: provider.category,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.filter_alt_rounded, color: AppColors.primary),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Tout')),
                    DropdownMenuItem(value: 'parfum', child: Text('Parfums')),
                    DropdownMenuItem(value: 'chaussure', child: Text('Chaussures')),
                    DropdownMenuItem(value: 'tissu', child: Text('Tissus')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      provider.setCategory(v);
                    }
                  },
                ),
              ],
            ),
          ),
          
          Expanded(
            child: provider.loading && provider.items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const Center(child: Text('Aucun produit trouvé.'))
                    : RefreshIndicator(
                        onRefresh: () => provider.refresh(),
                        child: ListView.builder(
                          controller: _scrollCtrl,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filtered.length + (provider.hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= filtered.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }
                            final p = filtered[index];
                            final String catLabel = _mapCategoryToFrench(p.category);
                            final bool hasImg = p.images.isNotEmpty;
                            
                            // Image path resolution
                            final String? rawUrl = hasImg ? p.images.first.url : null;
                            final String? rawThumb = hasImg ? p.images.first.thumbUrl : null;
                            final String? imageUrl = rawUrl != null 
                                ? (rawUrl.startsWith('http') ? rawUrl : '${ApiClient.baseUrl}$rawUrl')
                                : null;
                            final String? thumbUrl = rawThumb != null && rawThumb.isNotEmpty
                                ? (rawThumb.startsWith('http') ? rawThumb : '${ApiClient.baseUrl}$rawThumb')
                                : imageUrl;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              child: InkWell(
                                onTap: () => _showProductDetails(p),
                                borderRadius: BorderRadius.circular(15),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Row(
                                  children: [
                                    // Thumbnail Image
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: thumbUrl != null
                                          ? ClipRRect(
                                              borderRadius: BorderRadius.circular(10),
                                              child: CachedNetworkImage(
                                                imageUrl: thumbUrl,
                                                fit: BoxFit.cover,
                                                placeholder: (_, __) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                                errorWidget: (_, __, ___) => const Icon(Icons.image_not_supported_rounded, color: Colors.grey),
                                              ),
                                            )
                                          : const Icon(Icons.image_outlined, color: Colors.grey),
                                    ),
                                    const SizedBox(width: 12),
                                    
                                    // Product Info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p.name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            catLabel,
                                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Text(
                                                'Stock: ${p.quantity} ',
                                                style: TextStyle(
                                                  color: p.isLowStock ? AppColors.error : Colors.grey[700],
                                                  fontWeight: p.isLowStock ? FontWeight.bold : FontWeight.normal,
                                                ),
                                              ),
                                              if (p.isLowStock)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.error.withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: const Text('Bas / Low', style: TextStyle(color: AppColors.error, fontSize: 9, fontWeight: FontWeight.bold)),
                                                )
                                            ],
                                          )
                                        ],
                                      ),
                                    ),
                                    
                                    // Price & Action buttons
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          formatFcfa(p.price.toInt()),
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        // Profit is financial data — manager only.
                                        if (!isSec)
                                          Text(
                                            'Bénéf: ${p.profit.toInt()} F',
                                            style: TextStyle(
                                              color: p.profit >= 0 ? AppColors.success : AppColors.error,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 11,
                                            ),
                                          ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Sell button (both roles can sell)
                                            if (p.quantity > 0)
                                              IconButton(
                                                icon: const Icon(Icons.shopping_cart_rounded, color: AppColors.success),
                                                tooltip: 'Vendre',
                                                constraints: const BoxConstraints(),
                                                padding: const EdgeInsets.all(4),
                                                onPressed: () => _recordSale(p),
                                              ),
                                            
                                            // Manager-only edits
                                            if (!isSec) ...[
                                              IconButton(
                                                icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                                                constraints: const BoxConstraints(),
                                                padding: const EdgeInsets.all(4),
                                                onPressed: () => _openProductForm(product: p),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                                                constraints: const BoxConstraints(),
                                                padding: const EdgeInsets.all(4),
                                                onPressed: () async {
                                                  final confirm = await showDialog<bool>(
                                                    context: context,
                                                    builder: (ctx) => AlertDialog(
                                                      title: const Text('Supprimer produit ?'),
                                                      content: Text('Voulez-vous supprimer "${p.name}" ?'),
                                                      actions: [
                                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                                                        ElevatedButton(
                                                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                                          onPressed: () => Navigator.pop(ctx, true),
                                                          child: const Text('Supprimer'),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                  if (confirm == true) {
                                                    await provider.deleteProduct(p.id);
                                                  }
                                                },
                                              ),
                                            ],
                                          ],
                                        )
                                      ],
                                    )
                                  ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
