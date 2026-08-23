import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/empty_state.dart';
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
      backgroundColor: error ? AppColors.error : AppColors.success,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Les ventes'),
        actions: <Widget>[
          IconButton(
            tooltip: _range == null ? 'Choisir des dates' : 'Changer les dates',
            icon: Icon(_range == null
                ? Icons.date_range_rounded
                : Icons.event_available_rounded),
            onPressed: _pickRange,
          ),
          if (_range != null)
            IconButton(
              tooltip: 'Toutes les dates',
              icon: const Icon(Icons.clear_rounded),
              onPressed: () {
                setState(() => _range = null);
                _load();
              },
            ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: TextField(
              onSubmitted: (v) {
                setState(() => _search = v);
                _load();
              },
              decoration: InputDecoration(
                hintText: 'Chercher par nom de client',
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          _summaryStrip(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? const EmptyState(
                        title: 'Aucune vente',
                        message: 'Rien pour cette recherche.',
                        icon: Icons.receipt_long_outlined,
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) => _row(_items[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _summaryStrip() => Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text('$_totalCount vente(s)',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(formatFcfa(_totalAmount),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.primary)),
          ],
        ),
      );

  Widget _row(SaleReceipt r) => Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: r.voided
                ? AppColors.error.withValues(alpha: 0.15)
                : AppColors.primary.withValues(alpha: 0.12),
            child: Icon(
              r.voided ? Icons.block_rounded : Icons.receipt_long_rounded,
              color: r.voided ? AppColors.error : AppColors.primary,
              size: 20,
            ),
          ),
          title: Text(
            (r.clientName ?? '').isEmpty ? 'Client de passage' : r.clientName!,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text('${_day(r.soldAt)} · ${r.itemsCount} article(s)'),
          trailing: Text(
            formatFcfa(r.total),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: r.voided ? AppColors.textMuted : AppColors.textPrimary,
              decoration: r.voided ? TextDecoration.lineThrough : null,
            ),
          ),
          onTap: () => _openDetail(r.id),
        ),
      );

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
      backgroundColor: error ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final r = _receipt;
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (_, __) {},
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Détail de la vente'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(_changed),
          ),
        ),
        body: _loading || r == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: <Widget>[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            (r.clientName ?? '').isEmpty
                                ? 'Client de passage'
                                : r.clientName!,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          if ((r.clientPhone ?? '').isNotEmpty)
                            Text(r.clientPhone!,
                                style: const TextStyle(
                                    color: AppColors.textSecondary)),
                          const SizedBox(height: 6),
                          Text('Vendu le ${_SalesHistoryScreenState._day(r.soldAt)}',
                              style: const TextStyle(
                                  color: AppColors.textSecondary)),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              const Text('Total',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                              Text(formatFcfa(r.total),
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Les articles',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  for (final l in r.lines) _lineTile(l),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: AppColors.primary,
                    ),
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Renvoyer la facture'),
                    onPressed: () => _share(r),
                  ),
                  const SizedBox(height: 8),
                  if (!r.voided)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.error,
                          minimumSize: const Size.fromHeight(48)),
                      icon: const Icon(Icons.block_rounded),
                      label: const Text('Annuler toute la vente'),
                      onPressed: () => _cancelAll(r),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _lineTile(SaleReceiptLine l) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          title: Text(
            l.itemName,
            style: TextStyle(
              decoration: l.voided ? TextDecoration.lineThrough : null,
              color: l.voided ? AppColors.textMuted : null,
            ),
          ),
          subtitle: Text(l.voided
              ? 'Annulé'
              : '${l.qty} × ${formatFcfa(l.unitPrice)}'
                  '${l.corrected ? '  ·  modifié' : ''}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(formatFcfa(l.voided ? 0 : l.total),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              if (!l.voided)
                IconButton(
                  tooltip: 'Modifier',
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  onPressed: () => _editLine(l),
                ),
            ],
          ),
        ),
      );

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
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
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
