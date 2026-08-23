import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../clients/data/clients_repository.dart';
import '../../../clients/domain/client.dart';
import '../../../ready_to_wear/data/pret_a_porter_repository.dart';
import '../../data/products_repository.dart';
import '../../data/sales_repository.dart';
import '../../domain/product.dart';
import '../../domain/product_category.dart';
import '../../domain/sale_cart.dart';
import 'sale_receipt_screen.dart';

/// One trip to the till.
///
/// Before this screen a sale was one product at a time, so a customer buying
/// two boubous, a cap, shoes, a perfume and a watch meant six separate sales
/// attached to nobody and six pieces of paper. Here the seller taps what the
/// customer is taking, names them (or not — a walk-in stays anonymous), and
/// gets ONE invoice.
///
/// Both roles use it: the secretary is the one standing at the counter.
class CounterSaleScreen extends StatefulWidget {
  const CounterSaleScreen({super.key});

  @override
  State<CounterSaleScreen> createState() => _CounterSaleScreenState();
}

class _CounterSaleScreenState extends State<CounterSaleScreen> {
  final SaleCart _cart = SaleCart();
  final SalesRepository _sales = SalesRepository();
  final ProductsRepository _products = ProductsRepository();
  final PretAPorterRepository _models = PretAPorterRepository();

  List<ProductCategory> _categories = <ProductCategory>[];
  List<Product> _catalogue = <Product>[];
  List<PretAPorterModel> _modelCatalogue = <PretAPorterModel>[];

  /// null = the ready-to-wear tab, otherwise a category slug.
  String? _tab;
  bool _readyToWearTab = false;
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _cart.addListener(_onCartChanged);
    _load();
  }

  @override
  void dispose() {
    _cart.removeListener(_onCartChanged);
    _cart.dispose();
    super.dispose();
  }

  void _onCartChanged() => setState(() {});

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait(<Future<dynamic>>[
        _sales.listCategories(),
        _products.list(limit: 200),
        _models.list(limit: 200),
      ]);
      if (!mounted) return;
      setState(() {
        _categories = results[0] as List<ProductCategory>;
        _catalogue = results[1] as List<Product>;
        _modelCatalogue = results[2] as List<PretAPorterModel>;
        _tab ??= _categories.isNotEmpty ? _categories.first.slug : null;
      });
    } catch (e) {
      if (mounted) _toast('Chargement impossible : $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ---------------------------------------------------------------------------

  List<Product> get _visibleProducts {
    final q = _search.trim().toLowerCase();
    return _catalogue
        .where((p) => p.category == _tab)
        .where((p) => q.isEmpty || p.name.toLowerCase().contains(q))
        .toList();
  }

  List<PretAPorterModel> get _visibleModels {
    final q = _search.trim().toLowerCase();
    return _modelCatalogue
        .where((m) => q.isEmpty || m.name.toLowerCase().contains(q))
        .toList();
  }

  void _addProduct(Product p) {
    // The shelf count is what the seller has to respect; the basket knows how
    // many are already in it so a second tap cannot quietly oversell.
    if (_cart.quantityOf('produit', p.id) >= p.quantity) {
      _toast('Il ne reste que ${p.quantity} « ${p.name} ».', error: true);
      return;
    }
    _cart.add(CartLine(
      kind: 'produit',
      itemId: p.id,
      name: p.name,
      unitPrice: p.price.toInt(),
      quantity: 1,
      imageUrl: p.images.isNotEmpty ? p.images.first.thumbUrl ?? p.images.first.url : null,
      stockLeft: p.quantity,
    ));
  }

  void _addModel(PretAPorterModel m) {
    _cart.add(CartLine(
      kind: 'pret_a_porter',
      itemId: m.id,
      name: m.name,
      unitPrice: m.price.toInt(),
      quantity: 1,
      imageUrl: _firstImage(m),
    ));
  }

  /// A model can carry a video as well as photos; only an image is worth
  /// showing on a till card.
  static String? _firstImage(PretAPorterModel m) {
    for (final ModelMedia media in m.media) {
      if (media.kind == 'image') return media.thumbUrl ?? media.url;
    }
    return null;
  }

  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendre'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Recharger',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: <Widget>[
                _searchBar(),
                _tabStrip(),
                Expanded(child: _grid()),
              ],
            ),
      bottomNavigationBar: _cart.isEmpty ? null : _basketBar(),
    );
  }

  Widget _searchBar() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: TextField(
          onChanged: (v) => setState(() => _search = v),
          decoration: InputDecoration(
            hintText: 'Chercher un article…',
            prefixIcon: const Icon(Icons.search_rounded),
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );

  Widget _tabStrip() => SizedBox(
        height: 52,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: <Widget>[
            for (final c in _categories)
              _tabChip(
                label: c.label,
                icon: c.iconData,
                selected: !_readyToWearTab && _tab == c.slug,
                onTap: () => setState(() {
                  _readyToWearTab = false;
                  _tab = c.slug;
                }),
              ),
            _tabChip(
              label: 'Prêt-à-porter',
              icon: Icons.checkroom_rounded,
              selected: _readyToWearTab,
              onTap: () => setState(() => _readyToWearTab = true),
            ),
          ],
        ),
      );

  Widget _tabChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) =>
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          avatar: Icon(icon,
              size: 18,
              color: selected ? Colors.white : AppColors.textSecondary),
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
        ),
      );

  Widget _grid() {
    final bool rtw = _readyToWearTab;
    final int count = rtw ? _visibleModels.length : _visibleProducts.length;
    if (count == 0) {
      return const EmptyState(
        title: 'Rien à vendre ici',
        message: 'Aucun article dans cette catégorie.',
        icon: Icons.inventory_2_outlined,
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisExtent: 208,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: count,
      itemBuilder: (_, i) => rtw
          ? _card(
              name: _visibleModels[i].name,
              price: _visibleModels[i].price.toInt(),
              imageUrl: _firstImage(_visibleModels[i]),
              inCart: _cart.quantityOf('pret_a_porter', _visibleModels[i].id),
              stockLeft: null,
              onTap: () => _addModel(_visibleModels[i]),
            )
          : _card(
              name: _visibleProducts[i].name,
              price: _visibleProducts[i].price.toInt(),
              imageUrl: _visibleProducts[i].images.isNotEmpty
                  ? _visibleProducts[i].images.first.thumbUrl ??
                      _visibleProducts[i].images.first.url
                  : null,
              inCart: _cart.quantityOf('produit', _visibleProducts[i].id),
              stockLeft: _visibleProducts[i].quantity,
              onTap: () => _addProduct(_visibleProducts[i]),
            ),
    );
  }

  Widget _card({
    required String name,
    required int price,
    required String? imageUrl,
    required int inCart,
    required int? stockLeft,
    required VoidCallback onTap,
  }) {
    final bool soldOut = stockLeft != null && stockLeft <= 0;
    return InkWell(
      onTap: soldOut ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: inCart > 0 ? AppColors.primary : AppColors.border,
            width: inCart > 0 ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  if (imageUrl != null)
                    CachedNetworkImage(
                      imageUrl: imageUrl.startsWith('http')
                          ? imageUrl
                          : '${ApiClient.baseUrl}$imageUrl',
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _imagePlaceholder(),
                      placeholder: (_, __) => _imagePlaceholder(),
                    )
                  else
                    _imagePlaceholder(),
                  if (soldOut)
                    Container(
                      color: Colors.black.withValues(alpha: 0.55),
                      alignment: Alignment.center,
                      child: const Text('Épuisé',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  if (inCart > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: CircleAvatar(
                        radius: 13,
                        backgroundColor: AppColors.primary,
                        child: Text('$inCart',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(formatFcfa(price),
                      style: const TextStyle(
                          color: AppColors.primary, fontWeight: FontWeight.bold)),
                  if (stockLeft != null)
                    Text('Reste $stockLeft',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() => Container(
        color: AppColors.background,
        alignment: Alignment.center,
        child: const Icon(Icons.image_outlined,
            size: 34, color: AppColors.textMuted),
      );

  // ---------------------------------------------------------------------------

  Widget _basketBar() => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              backgroundColor: AppColors.primary,
            ),
            onPressed: _openBasket,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(children: <Widget>[
                  const Icon(Icons.shopping_basket_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text('${_cart.itemCount} article(s)'),
                ]),
                Text(formatFcfa(_cart.total),
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      );

  Future<void> _openBasket() async {
    final SaleReceipt? done = await showModalBottomSheet<SaleReceipt>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _BasketSheet(cart: _cart, sales: _sales),
    );
    if (done == null || !mounted) return;

    _cart.clear();
    // Reload so the shelf counts on the cards match what just left the shop.
    await _load();
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => SaleReceiptScreen(receipt: done),
    ));
  }
}

// ---------------------------------------------------------------------------
// The basket: adjust quantities and prices, name the client, take the money.
// ---------------------------------------------------------------------------
class _BasketSheet extends StatefulWidget {
  const _BasketSheet({required this.cart, required this.sales});

  final SaleCart cart;
  final SalesRepository sales;

  @override
  State<_BasketSheet> createState() => _BasketSheetState();
}

class _BasketSheetState extends State<_BasketSheet> {
  final ClientsRepository _clients = ClientsRepository();
  final TextEditingController _clientSearch = TextEditingController();

  Client? _client;
  List<Client> _matches = <Client>[];
  bool _saving = false;

  @override
  void dispose() {
    _clientSearch.dispose();
    super.dispose();
  }

  Future<void> _searchClients(String q) async {
    if (q.trim().length < 2) {
      setState(() => _matches = <Client>[]);
      return;
    }
    try {
      final List<Client> found = await _clients.list(search: q.trim(), limit: 6);
      if (mounted) setState(() => _matches = found);
    } catch (_) {/* the sale works without a client */}
  }

  Future<void> _checkout() async {
    final cart = widget.cart;
    if (cart.isEmpty || _saving) return;
    if (cart.hasStockProblem) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Un article dépasse le stock disponible.'),
        backgroundColor: AppColors.error,
      ));
      return;
    }
    setState(() => _saving = true);
    try {
      final SaleReceipt receipt = await widget.sales.checkout(
        lines: cart.toApiLines(),
        clientId: _client?.id,
      );
      if (mounted) Navigator.of(context).pop(receipt);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Vente impossible : $e'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = widget.cart;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => ListenableBuilder(
          listenable: cart,
          builder: (context, __) => Column(
            children: <Widget>[
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                child: Row(
                  children: <Widget>[
                    Text('La vente',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const Spacer(),
                    TextButton(
                      onPressed: cart.isEmpty ? null : cart.clear,
                      child: const Text('Tout enlever'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: <Widget>[
                    for (int i = 0; i < cart.lines.length; i++)
                      _line(cart, i),
                    const SizedBox(height: 18),
                    _clientPicker(),
                    const SizedBox(height: 90),
                  ],
                ),
              ),
              _footer(cart),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(SaleCart cart, int i) {
    final CartLine l = cart.lines[i];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(l.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  GestureDetector(
                    onTap: () => _editPrice(cart, i),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(formatFcfa(l.unitPrice),
                            style: const TextStyle(color: AppColors.textSecondary)),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit_rounded,
                            size: 13, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                  if (l.exceedsStock)
                    Text('Plus que ${l.stockLeft} en stock',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.error)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline_rounded),
              onPressed: () => cart.setQuantity(i, l.quantity - 1),
            ),
            Text('${l.quantity}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded),
              onPressed: () => cart.setQuantity(i, l.quantity + 1),
            ),
            SizedBox(
              width: 78,
              child: Text(formatFcfa(l.lineTotal),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editPrice(SaleCart cart, int i) async {
    final controller =
        TextEditingController(text: '${cart.lines[i].unitPrice}');
    final int? newPrice = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Changer le prix'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Prix pour une pièce (FCFA)',
          ),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Retour')),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(int.tryParse(controller.text.trim())),
            child: const Text('Garder'),
          ),
        ],
      ),
    );
    if (newPrice != null && newPrice >= 0) cart.setUnitPrice(i, newPrice);
  }

  Widget _clientPicker() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('Le client (facultatif)',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          if (_client != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.person_rounded),
                title: Text(_client!.fullName),
                subtitle: Text(_client!.phone),
                trailing: IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(() => _client = null),
                ),
              ),
            )
          else ...<Widget>[
            TextField(
              controller: _clientSearch,
              onChanged: _searchClients,
              decoration: InputDecoration(
                hintText: 'Nom ou téléphone du client',
                prefixIcon: const Icon(Icons.person_search_rounded),
                isDense: true,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            for (final c in _matches)
              ListTile(
                dense: true,
                leading: const Icon(Icons.person_outline_rounded),
                title: Text(c.fullName),
                subtitle: Text(c.phone),
                onTap: () => setState(() {
                  _client = c;
                  _matches = <Client>[];
                  _clientSearch.clear();
                }),
              ),
          ],
        ],
      );

  Widget _footer(SaleCart cart) => Material(
        elevation: 8,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    const Text('À payer',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    Text(formatFcfa(cart.total),
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary)),
                  ],
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: AppColors.success,
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_rounded),
                  label: Text(_saving ? 'Enregistrement…' : 'Encaisser'),
                  onPressed: cart.isEmpty || _saving ? null : _checkout,
                ),
              ],
            ),
          ),
        ),
      );
}
