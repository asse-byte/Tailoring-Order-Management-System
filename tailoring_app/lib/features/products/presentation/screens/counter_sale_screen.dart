import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/couture_icons.dart';
import '../../../../core/theme/couture_palette.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/couture/couture_bits.dart';
import '../../../../core/widgets/couture/couture_scaffold.dart';
import '../../../../core/widgets/formatted_number_field.dart';
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
  const CounterSaleScreen({
    super.key,
    this.salesRepository,
    this.productsRepository,
    this.modelsRepository,
  });

  // Injectable only so this screen can be rendered in a test without a server.
  // Every caller in the app passes nothing and gets the real ones.
  final SalesRepository? salesRepository;
  final ProductsRepository? productsRepository;
  final PretAPorterRepository? modelsRepository;

  @override
  State<CounterSaleScreen> createState() => _CounterSaleScreenState();
}

class _CounterSaleScreenState extends State<CounterSaleScreen> {
  final SaleCart _cart = SaleCart();
  late final SalesRepository _sales =
      widget.salesRepository ?? SalesRepository();
  late final ProductsRepository _products =
      widget.productsRepository ?? ProductsRepository();
  late final PretAPorterRepository _models =
      widget.modelsRepository ?? PretAPorterRepository();

  /// One page of the visible tab, not the whole shop.
  ///
  /// The first version pulled 200 products and 200 models in one request and
  /// filtered them in memory. That is slow to open on a phone and, worse,
  /// silently wrong: a shop with more than 200 products simply could not sell
  /// the rest, and a search only ever looked at what happened to be loaded.
  /// Each tab now pages in as the seller scrolls, and the search goes to the
  /// server.
  static const int _pageSize = 40;

  final ScrollController _scroll = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();

  List<ProductCategory> _categories = <ProductCategory>[];
  List<Product> _catalogue = <Product>[];
  List<PretAPorterModel> _modelCatalogue = <PretAPorterModel>[];

  /// The category slug currently shown; ignored while [_readyToWearTab] is on.
  String? _tab;
  bool _readyToWearTab = false;
  bool _loading = true;
  bool _loadingMore = false;
  bool _endReached = false;
  String _search = '';
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _cart.addListener(_onCartChanged);
    _scroll.addListener(_onScroll);
    _bootstrap();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _scroll.dispose();
    _cart.removeListener(_onCartChanged);
    _cart.dispose();
    super.dispose();
  }

  void _onCartChanged() => setState(() {});

  void _onScroll() {
    if (!_scroll.hasClients || _loading || _loadingMore || _endReached) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  /// Categories first, because the first tab decides what to fetch.
  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    try {
      final cats = await _sales.listCategories();
      if (!mounted) return;
      setState(() {
        _categories = cats;
        _tab ??= cats.isNotEmpty ? cats.first.slug : null;
      });
      await _reload();
    } catch (e) {
      if (mounted) {
        _toast('Chargement impossible : $e', error: true);
        setState(() => _loading = false);
      }
    }
  }

  /// Throw away the current tab's page and fetch page 1 — on a tab switch, a
  /// new search term, or a pull to refresh.
  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _endReached = false;
      _catalogue = <Product>[];
      _modelCatalogue = <PretAPorterModel>[];
    });
    await _fetchPage(offset: 0);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    await _fetchPage(
        offset: _readyToWearTab ? _modelCatalogue.length : _catalogue.length);
    if (mounted) setState(() => _loadingMore = false);
  }

  Future<void> _fetchPage({required int offset}) async {
    try {
      if (_readyToWearTab) {
        final page = await _models.list(
            search: _search, limit: _pageSize, offset: offset);
        if (!mounted) return;
        setState(() {
          _modelCatalogue.addAll(page);
          _endReached = page.length < _pageSize;
        });
      } else {
        final page = await _products.list(
            category: _tab, search: _search, limit: _pageSize, offset: offset);
        if (!mounted) return;
        setState(() {
          _catalogue.addAll(page);
          _endReached = page.length < _pageSize;
        });
      }
    } catch (e) {
      if (mounted) _toast('Chargement impossible : $e', error: true);
    }
  }

  /// Typing shouldn't fire a request per keystroke at the counter.
  void _onSearchChanged(String value) {
    _search = value;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _reload();
    });
  }

  void _switchTab({String? slug, bool readyToWear = false}) {
    if (readyToWear == _readyToWearTab && slug == _tab) return;
    setState(() {
      _readyToWearTab = readyToWear;
      if (!readyToWear) _tab = slug;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _reload();
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    final CoutureScheme c = CoutureScheme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? CouturePalette.terracottaDeep : c.goodInk,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ---------------------------------------------------------------------------
  // The server already filtered by tab and search, so these are just the page.
  List<Product> get _visibleProducts => _catalogue;

  List<PretAPorterModel> get _visibleModels => _modelCatalogue;

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
      imageUrl: p.images.isNotEmpty
          ? p.images.first.thumbUrl ?? p.images.first.url
          : null,
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
    return CoutureScaffold(
      title: 'Vendre',
      subtitle: 'Touchez ce que le client emporte',
      actions: <Widget>[
        CoutureBandAction(
          icon: CoutureIcons.refresh,
          tooltip: 'Recharger',
          onPressed: _reload,
        ),
      ],
      below: _loading ? null : _header(),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: <Widget>[
                Expanded(child: _grid()),
                if (_loadingMore)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                if (_cart.isNotEmpty) _basketBar(),
              ],
            ),
    );
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(
            CouturePalette.s3, CouturePalette.s3, CouturePalette.s3, 0),
        child: Column(
          children: <Widget>[
            CoutureSearchField(
              controller: _searchCtrl,
              hint: 'Chercher un article',
              onChanged: (String v) {
                _onSearchChanged(v);
                setState(() {});
              },
              onClear: () {
                _searchCtrl.clear();
                _onSearchChanged('');
                setState(() {});
              },
            ),
            const SizedBox(height: CouturePalette.s3),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length + 1,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: CouturePalette.s2),
                itemBuilder: (_, int i) {
                  if (i == _categories.length) {
                    return CoutureFilterChip(
                      label: 'Prêt-à-porter',
                      icon: CoutureIcons.coatHanger,
                      selected: _readyToWearTab,
                      onTap: () => _switchTab(readyToWear: true),
                    );
                  }
                  final ProductCategory cat = _categories[i];
                  return CoutureFilterChip(
                    label: cat.label,
                    icon: cat.iconData,
                    selected: !_readyToWearTab && _tab == cat.slug,
                    onTap: () => _switchTab(slug: cat.slug),
                  );
                },
              ),
            ),
            const SizedBox(height: CouturePalette.s3),
          ],
        ),
      );

  Widget _grid() {
    final bool rtw = _readyToWearTab;
    final int count = rtw ? _visibleModels.length : _visibleProducts.length;
    if (count == 0) {
      return const CoutureEmpty(
        icon: CoutureIcons.package,
        title: 'Rien à vendre ici',
        message: 'Cette catégorie est vide, ou la recherche ne donne rien.',
      );
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: GridView.builder(
        controller: _scroll,
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
    final CoutureScheme c = CoutureScheme.of(context);
    final bool soldOut = stockLeft != null && stockLeft <= 0;
    return InkWell(
      onTap: soldOut ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: inCart > 0 ? c.iconInk : c.line,
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
                      child: const Text(
                        'Épuisé',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  if (inCart > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: CircleAvatar(
                        radius: 13,
                        backgroundColor: c.iconInk,
                        child: Text('$inCart',
                            style: TextStyle(
                                color: c.card,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
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
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: c.ink)),
                  const SizedBox(height: 2),
                  Text(formatFcfa(price),
                      style: TextStyle(
                          fontSize: 13.5,
                          color: c.ink,
                          fontWeight: FontWeight.w700)),
                  // Nothing under a sold-out card: the "Épuisé" band already
                  // says it, and "Plus que 0" reads like a stock figure.
                  if (stockLeft != null && !soldOut)
                    Text(
                      stockLeft <= 3
                          ? 'Plus que $stockLeft'
                          : '$stockLeft en boutique',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            stockLeft <= 3 ? FontWeight.w600 : FontWeight.w400,
                        color: stockLeft <= 3 ? c.urgentText : c.inkFaint,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    final CoutureScheme c = CoutureScheme.of(context);
    return Container(
      color: c.quiet,
      alignment: Alignment.center,
      child: Icon(CoutureIcons.images, size: 30, color: c.inkFaint),
    );
  }

  // ---------------------------------------------------------------------------

  /// The basket bar is the warm colour, like the till button on the home
  /// screen: on this screen it is the one thing that finishes the job.
  Widget _basketBar() {
    final CoutureScheme c = CoutureScheme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(CouturePalette.s3, CouturePalette.s2,
            CouturePalette.s3, CouturePalette.s3),
        child: FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(58),
            backgroundColor: c.urgentInk,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: _openBasket,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(children: <Widget>[
                const Icon(CoutureIcons.shoppingBag, size: 20),
                const SizedBox(width: CouturePalette.s2),
                Text(
                  _cart.itemCount == 1
                      ? '1 article'
                      : '${_cart.itemCount} articles',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ]),
              Text(formatFcfa(_cart.total),
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openBasket() async {
    final SaleReceipt? done = await showModalBottomSheet<SaleReceipt>(
      context: context,
      isScrollControlled: true,
      // Material 3 tints a bottom sheet with the primary colour, which turned
      // the basket faintly lilac. The basket is paper, like everything else.
      backgroundColor: CoutureScheme.of(context).paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _BasketSheet(cart: _cart, sales: _sales),
    );
    if (done == null || !mounted) return;

    _cart.clear();
    // Reload so the shelf counts on the cards match what just left the shop.
    await _reload();
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
      final List<Client> found =
          await _clients.list(search: q.trim(), limit: 6);
      if (mounted) setState(() => _matches = found);
    } catch (_) {/* the sale works without a client */}
  }

  Future<void> _checkout() async {
    final cart = widget.cart;
    if (cart.isEmpty || _saving) return;
    if (cart.hasStockProblem) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Un article dépasse ce qu\'il reste en boutique.'),
        backgroundColor: CouturePalette.terracottaDeep,
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
          content: Text('La vente n\'est pas passée : $e'),
          backgroundColor: CouturePalette.terracottaDeep,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = widget.cart;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                  color: CoutureScheme.of(context).line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
                child: Row(
                  children: <Widget>[
                    Text(
                      'La vente',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: CoutureScheme.of(context).ink,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: cart.isEmpty ? null : cart.clear,
                      style: TextButton.styleFrom(
                          foregroundColor: CoutureScheme.of(context).inkSoft),
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
                    for (int i = 0; i < cart.lines.length; i++) _line(cart, i),
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
    final CoutureScheme c = CoutureScheme.of(context);
    final CartLine l = cart.lines[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: CouturePalette.s2),
      child: CoutureCard(
        padding: const EdgeInsets.fromLTRB(CouturePalette.s3, 10, 4, 10),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(l.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: c.ink)),
                  const SizedBox(height: 2),
                  // The unit price is tappable because VIP discounts are a real
                  // part of how these shops sell (owner decision 2026-08-03).
                  GestureDetector(
                    onTap: () => _editPrice(cart, i),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(formatFcfa(l.unitPrice),
                            style: TextStyle(fontSize: 12.5, color: c.inkSoft)),
                        const SizedBox(width: 4),
                        Icon(CoutureIcons.pencil, size: 12, color: c.inkFaint),
                      ],
                    ),
                  ),
                  if (l.exceedsStock)
                    Text('Il n\'en reste que ${l.stockLeft}',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: c.urgentText)),
                ],
              ),
            ),
            _StepButton(
              icon: CoutureIcons.minus,
              tooltip: 'Un de moins',
              onTap: () => cart.setQuantity(i, l.quantity - 1),
            ),
            SizedBox(
              width: 26,
              child: Text('${l.quantity}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700, color: c.ink)),
            ),
            _StepButton(
              icon: CoutureIcons.plus,
              tooltip: 'Un de plus',
              onTap: () => cart.setQuantity(i, l.quantity + 1),
            ),
            SizedBox(
              width: 92,
              child: Text(
                formatFcfa(l.lineTotal),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: c.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editPrice(SaleCart cart, int i) async {
    // Grouped thousands like every other money field in the app: 45,000 is read
    // correctly at a glance, 45000 is not. Display only — `parseThousands`
    // strips the commas before the number goes anywhere near the cart.
    final TextEditingController controller =
        TextEditingController(text: formatThousands(cart.lines[i].unitPrice));
    final CoutureScheme c = CoutureScheme.of(context);
    final int? newPrice = await showDialog<int>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: c.card,
        title: Text('Changer le prix',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w600, color: c.ink)),
        content: FormattedNumberField(
          controller: controller,
          label: 'Prix d\'une pièce',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(foregroundColor: c.inkSoft),
            child: const Text('Retour'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: c.iconInk),
            onPressed: () =>
                Navigator.of(ctx).pop(parseThousands(controller.text)),
            child: const Text('Garder'),
          ),
        ],
      ),
    );
    if (newPrice != null && newPrice >= 0) cart.setUnitPrice(i, newPrice);
  }

  Widget _clientPicker() {
    final CoutureScheme c = CoutureScheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('LE CLIENT — SI VOUS LE CONNAISSEZ',
            style: CouturePalette.sectionLabel.copyWith(color: c.inkFaint)),
        const SizedBox(height: CouturePalette.s2),
        if (_client != null)
          CoutureCard(
            padding: const EdgeInsets.fromLTRB(
                CouturePalette.s3, CouturePalette.s2, 4, CouturePalette.s2),
            child: Row(
              children: <Widget>[
                const CoutureWash(
                    icon: CoutureIcons.user, size: 38, iconSize: 19),
                const SizedBox(width: CouturePalette.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(_client!.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: c.ink)),
                      Text(_client!.phone,
                          style: TextStyle(fontSize: 12.5, color: c.inkSoft)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Enlever le client',
                  icon: Icon(CoutureIcons.close, size: 18, color: c.inkFaint),
                  onPressed: () => setState(() => _client = null),
                ),
              ],
            ),
          )
        else ...<Widget>[
          CoutureSearchField(
            controller: _clientSearch,
            hint: 'Nom ou téléphone du client',
            onChanged: (String v) {
              _searchClients(v);
              setState(() {});
            },
            onClear: () {
              _clientSearch.clear();
              setState(() => _matches = <Client>[]);
            },
          ),
          for (final Client match in _matches)
            ListTile(
              dense: true,
              leading: Icon(CoutureIcons.user, size: 20, color: c.inkSoft),
              title: Text(match.fullName,
                  style: TextStyle(fontSize: 14, color: c.ink)),
              subtitle: Text(match.phone,
                  style: TextStyle(fontSize: 12, color: c.inkSoft)),
              onTap: () => setState(() {
                _client = match;
                _matches = <Client>[];
                _clientSearch.clear();
              }),
            ),
        ],
      ],
    );
  }

  Widget _footer(SaleCart cart) {
    final CoutureScheme c = CoutureScheme.of(context);
    return Material(
      color: c.card,
      elevation: 8,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(CouturePalette.s4,
              CouturePalette.s3, CouturePalette.s4, CouturePalette.s3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('Le client paie',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: c.inkSoft)),
                  Text(formatFcfa(cart.total),
                      style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                          color: c.ink)),
                ],
              ),
              const SizedBox(height: CouturePalette.s3),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  backgroundColor: c.urgentInk,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(CoutureIcons.checkCircle, size: 20),
                label: Text(
                  _saving ? 'Un instant…' : 'Encaisser',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                onPressed: cart.isEmpty || _saving ? null : _checkout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The + / − beside a basket line. A plain IconButton is a 48-px hit area with
/// a 24-px glyph floating in it; this keeps the target and shows where it is.
class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final CoutureScheme c = CoutureScheme.of(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 34,
          height: 34,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: c.quiet,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: c.inkList),
        ),
      ),
    );
  }
}
