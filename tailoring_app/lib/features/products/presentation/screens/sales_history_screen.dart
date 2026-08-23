import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/couture_icons.dart';
import '../../../../core/theme/couture_palette.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/couture/couture_bits.dart';
import '../../../../core/widgets/couture/couture_scaffold.dart';
import '../../../settings/presentation/providers/shop_settings_provider.dart';
import '../../data/receipt_invoice_service.dart';
import '../../data/sales_repository.dart';

/// Every sale the shop has made, and what is in each one.
///
/// Both roles since the owner's decision of 2026-08-23: the secretary sells at
/// the counter, so finding a sale she made and fixing it is hers. The purchase
/// cost is stripped server-side, so she sees what the shop took and never what
/// it paid.
///
/// Editing works the way the seller expects — change a quantity, cancel a sale
/// — while underneath it is always an append-only correction with a reason, and
/// the stock difference goes back on the shelf in the same transaction.
class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  final SalesRepository _repo = SalesRepository();
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  List<SaleReceipt> _items = <SaleReceipt>[];
  int _totalAmount = 0;
  int _totalCount = 0;
  bool _loading = true;
  String _search = '';
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// The list used to search only when the keyboard's Enter was pressed, which
  /// nobody at a counter does. It searches as you pause typing now, like the
  /// clients list and the till — one request per pause, not per keystroke.
  void _onSearchChanged(String value) {
    _search = value;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _load();
    });
  }

  String? _fmt(DateTime? d) => d == null
      ? null
      : '${d.year}-${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _repo.listReceipts(
        search: _search,
        from: _fmt(_range?.start),
        to: _fmt(_range?.end),
      );
      if (!mounted) return;
      setState(() {
        _items = res.items;
        _totalAmount = res.totalAmount;
        _totalCount = res.totalCount;
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
      backgroundColor: error
          ? CouturePalette.terracottaDeep
          : CoutureScheme.of(context).goodInk,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _pickRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _range,
    );
    if (picked != null) {
      setState(() => _range = picked);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CoutureScaffold(
      title: 'Les ventes',
      subtitle: 'Ce qui est sorti de la boutique',
      actions: <Widget>[
        if (_range != null)
          CoutureBandAction(
            icon: CoutureIcons.filterOff,
            tooltip: 'Toutes les dates',
            onPressed: () {
              setState(() => _range = null);
              _load();
            },
          ),
        CoutureBandAction(
          icon: CoutureIcons.refresh,
          tooltip: 'Actualiser',
          onPressed: _load,
        ),
      ],
      below: _header(),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const CoutureEmpty(
                  icon: CoutureIcons.receipt,
                  title: 'Aucune vente',
                  message: 'Rien pour cette recherche, ou pour ces dates.',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                        CouturePalette.s4,
                        CouturePalette.s1,
                        CouturePalette.s4,
                        CouturePalette.s6),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: CouturePalette.s2),
                    itemBuilder: (_, int i) => _row(_items[i]),
                  ),
                ),
    );
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(
            CouturePalette.s4, CouturePalette.s3, CouturePalette.s4, 0),
        child: Column(
          children: <Widget>[
            CoutureSearchField(
              controller: _searchCtrl,
              hint: 'Nom du client',
              onChanged: (String v) {
                _onSearchChanged(v);
                setState(() {});
              },
              onSubmitted: (_) => _load(),
              onClear: () {
                _searchCtrl.clear();
                _onSearchChanged('');
                setState(() {});
              },
            ),
            const SizedBox(height: CouturePalette.s3),
            Align(
              alignment: Alignment.centerLeft,
              child: CoutureFilterChip(
                icon: CoutureIcons.calendarBlank,
                label: _range == null
                    ? 'Choisir des dates'
                    : '${_SalesHistoryScreenState._day(_range!.start.toIso8601String())} – ${_SalesHistoryScreenState._day(_range!.end.toIso8601String())}',
                selected: _range != null,
                onTap: _pickRange,
              ),
            ),
            const SizedBox(height: CouturePalette.s3),
            _summaryStrip(),
            const SizedBox(height: CouturePalette.s3),
          ],
        ),
      );

  /// The day's takings, in the words the shop uses. Both roles see this: it is
  /// what the shop TOOK, never what it paid — the purchase cost never leaves
  /// the server for the secretary.
  Widget _summaryStrip() {
    final CoutureScheme c = CoutureScheme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          vertical: CouturePalette.s3, horizontal: CouturePalette.s4),
      decoration: BoxDecoration(
        color: c.iconWash,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            _totalCount == 1 ? '1 vente' : '$_totalCount ventes',
            style: TextStyle(
                fontSize: 13.5, fontWeight: FontWeight.w600, color: c.iconInk),
          ),
          Text(formatFcfa(_totalAmount),
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: c.iconInk)),
        ],
      ),
    );
  }

  Widget _row(SaleReceipt r) {
    final CoutureScheme c = CoutureScheme.of(context);
    return CoutureCard(
      onTap: () => _openDetail(r.id),
      padding: const EdgeInsets.fromLTRB(CouturePalette.s3, CouturePalette.s3,
          CouturePalette.s3, CouturePalette.s3),
      child: Row(
        children: <Widget>[
          CoutureWash(
            icon: r.voided ? CoutureIcons.prohibit : CoutureIcons.receipt,
            tone: r.voided ? CoutureTone.urgent : CoutureTone.normal,
            size: 40,
            iconSize: 20,
          ),
          const SizedBox(width: CouturePalette.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  (r.clientName ?? '').isEmpty
                      ? 'Client de passage'
                      : r.clientName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600, color: c.ink),
                ),
                const SizedBox(height: 1),
                Text(
                  '${_day(r.soldAt)} · '
                  '${r.itemsCount == 1 ? '1 article' : '${r.itemsCount} articles'}'
                  '${r.voided ? ' · annulée' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12.5,
                      color: r.voided ? c.urgentText : c.inkSoft),
                ),
              ],
            ),
          ),
          const SizedBox(width: CouturePalette.s2),
          Text(
            formatFcfa(r.total),
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: r.voided ? c.inkFaint : c.ink,
              decoration: r.voided ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      ),
    );
  }

  static String _day(String raw) {
    final DateTime? d = DateTime.tryParse(raw);
    if (d == null) return raw;
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> _openDetail(String id) async {
    final bool? changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => _SaleDetailScreen(receiptId: id)),
    );
    if (changed == true) await _load();
  }
}

// ---------------------------------------------------------------------------
// One sale, in full, with the two things a manager actually needs to do to it:
// fix a quantity, or cancel it.
// ---------------------------------------------------------------------------
class _SaleDetailScreen extends StatefulWidget {
  const _SaleDetailScreen({required this.receiptId});

  final String receiptId;

  @override
  State<_SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends State<_SaleDetailScreen> {
  final SalesRepository _repo = SalesRepository();

  SaleReceipt? _receipt;
  bool _loading = true;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await _repo.getReceipt(widget.receiptId);
      if (mounted) setState(() => _receipt = r);
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
      backgroundColor: error
          ? CouturePalette.terracottaDeep
          : CoutureScheme.of(context).goodInk,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final r = _receipt;
    final CoutureScheme c = CoutureScheme.of(context);
    return CoutureScaffold(
      title: 'La vente',
      subtitle: r == null ? null : _SalesHistoryScreenState._day(r.soldAt),
      onBack: () => Navigator.of(context).pop(_changed),
      child: _loading || r == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(CouturePalette.s4,
                  CouturePalette.s4, CouturePalette.s4, CouturePalette.s8),
              children: <Widget>[
                CoutureCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          CoutureWash(
                            icon: r.voided
                                ? CoutureIcons.prohibit
                                : CoutureIcons.user,
                            tone: r.voided
                                ? CoutureTone.urgent
                                : CoutureTone.normal,
                            size: 40,
                            iconSize: 20,
                          ),
                          const SizedBox(width: CouturePalette.s3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  (r.clientName ?? '').isEmpty
                                      ? 'Client de passage'
                                      : r.clientName!,
                                  style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      color: c.ink),
                                ),
                                if ((r.clientPhone ?? '').isNotEmpty)
                                  Text(r.clientPhone!,
                                      style: TextStyle(
                                          fontSize: 13, color: c.inkSoft)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (r.voided) ...<Widget>[
                        const SizedBox(height: CouturePalette.s3),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: c.urgentWash,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text('Cette vente a été annulée',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: c.urgentText)),
                        ),
                      ],
                      Divider(height: 26, color: c.line),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text('Le client a payé',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: c.inkSoft)),
                          Text(formatFcfa(r.total),
                              style: TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w700,
                                  color: c.ink)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: CouturePalette.s6),
                Text('LES ARTICLES',
                    style: CouturePalette.sectionLabel
                        .copyWith(color: c.inkFaint)),
                const SizedBox(height: CouturePalette.s2),
                for (final SaleReceiptLine l in r.lines) _lineTile(l),
                const SizedBox(height: CouturePalette.s6),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: c.iconInk,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                  ),
                  icon: const Icon(CoutureIcons.share, size: 19),
                  label: const Text('Renvoyer la facture',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  onPressed: () => _share(r),
                ),
                const SizedBox(height: CouturePalette.s2),
                if (!r.voided)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                        foregroundColor: c.urgentText,
                        minimumSize: const Size.fromHeight(48)),
                    icon: const Icon(CoutureIcons.prohibit, size: 18),
                    label: const Text('Annuler toute la vente'),
                    onPressed: () => _cancelAll(r),
                  ),
              ],
            ),
    );
  }

  Widget _lineTile(SaleReceiptLine l) {
    final CoutureScheme c = CoutureScheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: CouturePalette.s2),
      child: CoutureCard(
        padding: const EdgeInsets.fromLTRB(CouturePalette.s3, CouturePalette.s3,
            CouturePalette.s2, CouturePalette.s3),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l.itemName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: l.voided ? c.inkFaint : c.ink,
                      decoration: l.voided ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    l.voided
                        ? 'Annulé — remis en stock'
                        : '${l.qty} × ${formatFcfa(l.unitPrice)}'
                            '${l.corrected ? ' · modifié' : ''}',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: l.voided ? c.urgentText : c.inkSoft),
                  ),
                ],
              ),
            ),
            Text(formatFcfa(l.voided ? 0 : l.total),
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: l.voided ? c.inkFaint : c.ink)),
            if (!l.voided)
              IconButton(
                tooltip: 'Corriger',
                icon: Icon(CoutureIcons.pencil, size: 17, color: c.inkSoft),
                onPressed: () => _editLine(l),
              )
            else
              const SizedBox(width: CouturePalette.s2),
          ],
        ),
      ),
    );
  }

  /// Changing a quantity is a correction row underneath, never an edit of the
  /// original sale, and the difference goes back on the shelf. The seller only
  /// sees "how many, and why".
  Future<void> _editLine(SaleReceiptLine l) async {
    final qtyCtrl = TextEditingController(text: '${l.qty}');
    final reasonCtrl = TextEditingController();

    final bool ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l.itemName),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Combien ?'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Pourquoi ?',
                    hintText: 'Exemple : le client en a rendu un',
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Retour')),
              FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Enregistrer')),
            ],
          ),
        ) ??
        false;
    if (!ok) return;

    final int? qty = int.tryParse(qtyCtrl.text.trim());
    final String reason = reasonCtrl.text.trim();
    if (qty == null || qty < 1) {
      _toast('Mettez un nombre à partir de 1.', error: true);
      return;
    }
    if (reason.isEmpty) {
      _toast('Écrivez pourquoi vous changez cette vente.', error: true);
      return;
    }
    try {
      await _repo.correctLine(l.id, newQty: qty, reason: reason);
      _changed = true;
      await _load();
      if (mounted) _toast('Vente modifiée.');
    } catch (e) {
      _toast('Modification impossible : $e', error: true);
    }
  }

  /// Cancelling voids every line, which is also what puts all the goods back
  /// in stock. The money is removed from the takings of the day it was taken.
  Future<void> _cancelAll(SaleReceipt r) async {
    final reasonCtrl = TextEditingController();
    final bool ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Annuler cette vente ?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Les articles reviennent en stock et l’argent est retiré '
                  'des recettes. La vente reste visible, marquée annulée.',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: reasonCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Pourquoi ?',
                    hintText: 'Exemple : le client a tout rendu',
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Retour')),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: CouturePalette.terracottaDeep),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Oui, annuler'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;

    final String reason = reasonCtrl.text.trim();
    if (reason.isEmpty) {
      _toast('Écrivez pourquoi vous annulez.', error: true);
      return;
    }
    try {
      for (final l in r.lines.where((l) => !l.voided)) {
        await _repo.correctLine(l.id, voided: true, reason: reason);
      }
      _changed = true;
      await _load();
      if (mounted) _toast('Vente annulée, articles remis en stock.');
    } catch (e) {
      _toast('Annulation impossible : $e', error: true);
    }
  }

  Future<void> _share(SaleReceipt r) async {
    final shop = context.read<ShopSettingsProvider>();
    try {
      await const ReceiptInvoiceService().shareInvoice(
        r,
        shopName: shop.shopName,
        logoUrl: shop.logoUrl,
        promoLink: shop.promoGroupLink,
      );
    } catch (e) {
      _toast('Facture impossible : $e', error: true);
    }
  }
}
