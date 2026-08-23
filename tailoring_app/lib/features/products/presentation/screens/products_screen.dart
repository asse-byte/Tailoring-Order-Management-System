import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:printing/printing.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/couture_icons.dart';
import '../../../../core/theme/couture_palette.dart';
import '../../../../core/widgets/couture/couture_bits.dart';
import '../../../../core/widgets/couture/couture_scaffold.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/confirm_delete_dialog.dart';
import '../../../../core/widgets/formatted_number_field.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/products_provider.dart';
import '../../data/sales_repository.dart';
import '../../domain/product.dart';
import '../../domain/product_category.dart';
import '../../data/products_repository.dart';
import '../../../settings/presentation/providers/shop_settings_provider.dart';
import '../../../orders/data/invoice_service.dart';

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
    _loadCategories();
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

  /// The shop's own product types. Fetched, never hardcoded: since migration
  /// 026 the manager adds types (montres, bonnets, whatever else) from inside
  /// the app, and a literal list here would silently hide them.
  List<ProductCategory> _categories = <ProductCategory>[];

  Future<void> _loadCategories() async {
    try {
      final List<ProductCategory> cats =
          await SalesRepository().listCategories();
      if (mounted) setState(() => _categories = cats);
    } catch (_) {/* the screen still lists products without the filter */}
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >
        _scrollCtrl.position.maxScrollExtent - 200) {
      context.read<ProductsProvider>().loadProducts();
    }
  }

  /// The label the shop gave this type. Falls back to the raw slug for a type
  /// that was deleted after a product kept pointing at it.
  String _mapCategoryToFrench(String cat) {
    for (final ProductCategory c in _categories) {
      if (c.slug == cat) return c.label;
    }
    return cat;
  }

  Future<void> _recordSale(Product product) async {
    final formKey = GlobalKey<FormState>();
    int qty = 1;
    final priceCtrl =
        TextEditingController(text: formatThousands(product.price.toInt()));

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Vendre - ${product.name}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Quantité à vendre',
                  suffixText: 'unités',
                ),
                keyboardType: TextInputType.number,
                initialValue: '1',
                validator: (v) {
                  final val = int.tryParse(v ?? '');
                  if (val == null || val < 1) return 'Quantité invalide';
                  if (val > product.quantity)
                    return 'Stock insuffisant (${product.quantity} dispo)';
                  return null;
                },
                onSaved: (v) => qty = int.tryParse(v ?? '') ?? 1,
              ),
              const SizedBox(height: 12),
              FormattedNumberField(
                controller: priceCtrl,
                label: 'Prix de vente unitaire (FCFA)',
                validator: (val) {
                  if (val == null || val < 0) return 'Prix invalide';
                  return null;
                },
              ),
            ],
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
                final customPrice =
                    parseThousands(priceCtrl.text) ?? product.price.toInt();
                Navigator.pop(ctx);
                final success =
                    await context.read<ProductsProvider>().sellProduct(
                          product.id,
                          qty,
                          unitPrice: customPrice,
                        );
                if (success && mounted) {
                  final settings = context.read<ShopSettingsProvider>();
                  final total = qty * customPrice;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Vente enregistrée avec succès !'),
                      backgroundColor: CoutureScheme.of(context).goodInk,
                      duration: const Duration(seconds: 8),
                      action: SnackBarAction(
                        label: 'Imprimer reçu',
                        textColor: Colors.white,
                        onPressed: () async {
                          final pdfBytes =
                              await InvoiceService.buildSaleReceiptPdf(
                            itemName: product.name,
                            itemKind: _mapCategoryToFrench(product.category),
                            qty: qty,
                            unitPrice: customPrice,
                            total: total,
                            shopName: settings.shopName,
                          );
                          await Printing.layoutPdf(
                            onLayout: (format) async => pdfBytes,
                            name: 'recu_vente_${product.name}.pdf',
                          );
                        },
                      ),
                    ),
                  );
                } else if (mounted) {
                  final err = context.read<ProductsProvider>().error ??
                      'Une erreur est survenue.';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(err),
                        backgroundColor: CouturePalette.terracottaDeep),
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
    final bool isManager = !context.read<AuthProvider>().isSecretary;
    final formKey = GlobalKey<FormState>();
    String name = product?.name ?? '';
    String category = product?.category ??
        (_categories.isNotEmpty ? _categories.first.slug : 'parfum');
    double price = product?.price ?? 0.0;
    double costPrice = product?.costPrice ?? 0.0;
    int quantity = product?.quantity ?? 0;
    int lowStockThreshold = product?.lowStockThreshold ?? 3;
    final priceCtrl = TextEditingController(
        text: price > 0 ? formatThousands(price.toInt()) : '');
    final costCtrl = TextEditingController(
        text: costPrice > 0 ? formatThousands(costPrice.toInt()) : '');
    final qtyCtrl = TextEditingController(
        text: product != null ? formatThousands(quantity) : '');
    final thresholdCtrl =
        TextEditingController(text: formatThousands(lowStockThreshold));
    XFile? selectedImage;
    Uint8List? selectedBytes; // in-memory preview, works on web + mobile
    bool uploadingImage = false;
    final String? currentImageUrl =
        product?.images.isNotEmpty == true ? product!.images.first.url : null;
    final String? currentThumbUrl = product?.images.isNotEmpty == true
        ? product!.images.first.thumbUrl
        : null;

    final ImagePicker picker = ImagePicker();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(product == null ? 'Nouveau Produit' : 'Modifier Produit'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: name,
                    decoration:
                        const InputDecoration(labelText: 'Nom du produit'),
                    validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                    onSaved: (v) => name = v ?? '',
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Catégorie'),
                    items: <DropdownMenuItem<String>>[
                      for (final ProductCategory c in _categories)
                        DropdownMenuItem<String>(
                            value: c.slug, child: Text(c.label)),
                    ],
                    onChanged: (v) =>
                        setDlgState(() => category = v ?? category),
                  ),
                  const SizedBox(height: 12),
                  FormattedNumberField(
                    controller: priceCtrl,
                    label: 'Prix de vente (FCFA)',
                    validator: (v) => v == null ? 'Prix invalide' : null,
                    onChanged: (v) =>
                        setDlgState(() => price = (v ?? 0).toDouble()),
                  ),
                  // Prix d'achat + profit = financial data, manager only.
                  if (isManager) ...[
                    const SizedBox(height: 12),
                    FormattedNumberField(
                      controller: costCtrl,
                      label: 'Prix d\'achat (FCFA)',
                      validator: (v) =>
                          v == null ? 'Prix d\'achat invalide' : null,
                      onChanged: (v) =>
                          setDlgState(() => costPrice = (v ?? 0).toDouble()),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Bénéfice unitaire: ${formatFcfa((price - costPrice).toInt())}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: (price - costPrice) >= 0
                              ? CoutureScheme.of(context).goodInk
                              : CouturePalette.terracottaDeep,
                        ),
                      ),
                    ),
                  ],
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
                                child: Image.memory(selectedBytes!,
                                    fit: BoxFit.cover),
                              )
                            : (currentImageUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: CachedNetworkImage(
                                      imageUrl: currentImageUrl
                                              .startsWith('http')
                                          ? currentImageUrl
                                          : '${ApiClient.baseUrl}$currentImageUrl',
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => const Center(
                                          child: CircularProgressIndicator()),
                                      errorWidget: (_, __, ___) =>
                                          const Icon(CoutureIcons.images),
                                    ),
                                  )
                                : Icon(CoutureIcons.images,
                                    color: CoutureScheme.of(context).inkFaint)),
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
                                      final XFile? file =
                                          await picker.pickImage(
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
                              icon: const Icon(CoutureIcons.images, size: 16),
                              label: const Text('Choisir une image'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
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
                          final uploaded =
                              await provider.uploadImage(selectedImage!);
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
                            SnackBar(
                                content: Text(provider.error ??
                                    'Enregistrement impossible'),
                                backgroundColor: CouturePalette.terracottaDeep),
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
                        icon: const Icon(CoutureIcons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _detailRow('Catégorie', _mapCategoryToFrench(p.category)),
                  _detailRow('Prix de vente', formatFcfa(p.price.toInt())),
                  _detailRow('Stock actuel', '${p.quantity} unités'),
                  if (isManager) ...[
                    _detailRow(
                        'Prix d\'achat', formatFcfa(p.costPrice.toInt())),
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
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
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
                            style: const TextStyle(
                                color: CouturePalette.terracottaDeep),
                          );
                        }
                        final stats = snapshot.data!;
                        final int totalSold = stats['total_sold'] as int;
                        final int totalRevenue = stats['total_revenue'] as int;
                        final int totalProfit = stats['total_profit'] as int;

                        return Column(
                          children: [
                            _detailRow('Quantité vendue', '$totalSold unités'),
                            _detailRow(
                                'Ventes totales', formatFcfa(totalRevenue)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Gain total'),
                                Text(
                                  formatFcfa(totalProfit),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: totalProfit >= 0
                                        ? CoutureScheme.of(context).goodInk
                                        : CouturePalette.terracottaDeep,
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
          Text(label,
              style: TextStyle(color: CoutureScheme.of(context).inkSoft)),
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
      final matchesSearch =
          p.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesSearch;
    }).toList();

    final shopName = context.watch<ShopSettingsProvider>().shopName;

    final CoutureScheme c = CoutureScheme.of(context);

    return CoutureScaffold(
      title: 'Produits',
      subtitle: shopName.isEmpty ? 'Ce que la boutique vend' : shopName,
      actions: <Widget>[
        CoutureBandAction(
          icon: CoutureIcons.refresh,
          tooltip: 'Actualiser',
          onPressed: () => provider.refresh(),
        ),
      ],
      // Catalog management is open to both roles; only cost_price/profit stay
      // manager-only (hidden in the form + card).
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openProductForm(),
        backgroundColor: c.urgentInk,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(CoutureIcons.plus, size: 20),
        label: const Text('Nouveau produit',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      below: Padding(
        padding: const EdgeInsets.fromLTRB(
            CouturePalette.s4, CouturePalette.s3, CouturePalette.s4, 0),
        child: Column(
          children: <Widget>[
            CoutureSearchField(
              controller: _searchCtrl,
              hint: 'Nom du produit',
              onChanged: (String v) => setState(() => _searchQuery = v),
              onClear: () {
                _searchCtrl.clear();
                setState(() => _searchQuery = '');
              },
            ),
            const SizedBox(height: CouturePalette.s3),
            // The shop's own types, as chips: a dropdown hid them behind a tap
            // and told nobody how many types the shop even has.
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length + 1,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: CouturePalette.s2),
                itemBuilder: (_, int i) {
                  if (i == 0) {
                    return CoutureFilterChip(
                      label: 'Tout',
                      selected: provider.category == 'all',
                      onTap: () => provider.setCategory('all'),
                    );
                  }
                  final ProductCategory cat = _categories[i - 1];
                  return CoutureFilterChip(
                    label: cat.label,
                    icon: cat.iconData,
                    selected: provider.category == cat.slug,
                    onTap: () => provider.setCategory(cat.slug),
                  );
                },
              ),
            ),
            const SizedBox(height: CouturePalette.s3),
          ],
        ),
      ),
      child: provider.loading && provider.items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : filtered.isEmpty
              ? const CoutureEmpty(
                  icon: CoutureIcons.shoppingBag,
                  title: 'Aucun produit',
                  message:
                      'Appuyez sur « Nouveau produit » pour en ajouter un.',
                )
              : RefreshIndicator(
                  onRefresh: () => provider.refresh(),
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                        CouturePalette.s4, 0, CouturePalette.s4, 96),
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
                      final String? rawThumb =
                          hasImg ? p.images.first.thumbUrl : null;
                      final String? imageUrl = rawUrl != null
                          ? (rawUrl.startsWith('http')
                              ? rawUrl
                              : '${ApiClient.baseUrl}$rawUrl')
                          : null;
                      final String? thumbUrl =
                          rawThumb != null && rawThumb.isNotEmpty
                              ? (rawThumb.startsWith('http')
                                  ? rawThumb
                                  : '${ApiClient.baseUrl}$rawThumb')
                              : imageUrl;

                      return Padding(
                        padding:
                            const EdgeInsets.only(bottom: CouturePalette.s2),
                        child: CoutureCard(
                          onTap: () => _showProductDetails(p),
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: [
                              // Thumbnail Image
                              Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  color: c.quiet,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: thumbUrl != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: CachedNetworkImage(
                                          imageUrl: thumbUrl,
                                          fit: BoxFit.cover,
                                          placeholder: (_, __) => const Center(
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2)),
                                          errorWidget: (_, __, ___) => Icon(
                                              CoutureIcons.images,
                                              color: c.inkFaint),
                                        ),
                                      )
                                    : Icon(CoutureIcons.images,
                                        color: c.inkFaint),
                              ),
                              const SizedBox(width: CouturePalette.s3),

                              // Product Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                          color: c.ink),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      catLabel,
                                      style: TextStyle(
                                          color: c.inkFaint, fontSize: 12),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      p.quantity == 0
                                          ? 'Épuisé'
                                          : p.isLowStock
                                              ? 'Plus que ${p.quantity}'
                                              : '${p.quantity} en boutique',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: p.isLowStock
                                            ? c.urgentText
                                            : c.inkSoft,
                                        fontWeight: p.isLowStock
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Price & Action buttons
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    formatFcfa(p.price.toInt()),
                                    style: TextStyle(
                                      color: c.ink,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  // Profit is financial data — manager only.
                                  if (!isSec)
                                    Text(
                                      'Bénéfice ${formatFcfa(p.profit.toInt())}',
                                      style: TextStyle(
                                        color: p.profit >= 0
                                            ? c.goodInk
                                            : c.urgentText,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Sell button (both roles can sell)
                                      if (p.quantity > 0)
                                        IconButton(
                                          icon: Icon(CoutureIcons.cashRegister,
                                              size: 19, color: c.goodInk),
                                          tooltip: 'Vendre',
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(5),
                                          onPressed: () => _recordSale(p),
                                        ),

                                      // Catalog edits: both roles.
                                      IconButton(
                                        icon: Icon(CoutureIcons.pencil,
                                            size: 18, color: c.inkSoft),
                                        tooltip: 'Modifier',
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(5),
                                        onPressed: () =>
                                            _openProductForm(product: p),
                                      ),
                                      IconButton(
                                        icon: Icon(CoutureIcons.trash,
                                            size: 18, color: c.urgentText),
                                        tooltip: 'Supprimer',
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(5),
                                        onPressed: () async {
                                          final confirm =
                                              await confirmDeleteByTyping(
                                            context,
                                            itemName: p.name,
                                            itemLabel: 'ce produit',
                                            historyNote: 'Les ventes déjà '
                                                'enregistrées de ce produit restent '
                                                'conservées dans les Finances (au nom '
                                                'et prix mémorisés).',
                                          );
                                          if (confirm) {
                                            await provider.deleteProduct(p.id);
                                          }
                                        },
                                      ),
                                    ],
                                  )
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
