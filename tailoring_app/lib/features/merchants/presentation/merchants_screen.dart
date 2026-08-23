import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/couture_icons.dart';
import '../../../core/theme/couture_palette.dart';
import '../../../core/widgets/couture/couture_bits.dart';
import '../../../core/widgets/couture/couture_scaffold.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/formatted_number_field.dart';
import '../../settings/presentation/providers/shop_settings_provider.dart';
import '../data/merchant_invoice_service.dart';
import '../data/merchant_repository.dart';
import '../domain/merchant_models.dart';

class MerchantsScreen extends StatefulWidget {
  const MerchantsScreen({super.key});

  @override
  State<MerchantsScreen> createState() => _MerchantsScreenState();
}

class _MerchantsScreenState extends State<MerchantsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final MerchantRepository _repo = MerchantRepository();

  // Suppliers & Purchases state
  List<Supplier> _suppliers = <Supplier>[];
  List<SupplierPurchase> _purchases = <SupplierPurchase>[];
  bool _loadingSuppliers = true;

  // Wholesale Orders state
  List<WholesaleOrder> _wholesaleOrders = <WholesaleOrder>[];
  bool _loadingWholesale = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // The two tabs are chips under the band, so the chips have to know which
    // one is showing after a swipe as well as after a tap.
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loadingSuppliers = true;
      _loadingWholesale = true;
    });
    try {
      final sups = await _repo.listSuppliers();
      final purs = await _repo.listSupplierPurchases();
      final ords = await _repo.listWholesaleOrders();
      if (mounted) {
        setState(() {
          _suppliers = sups;
          _purchases = purs;
          _wholesaleOrders = ords;
          _loadingSuppliers = false;
          _loadingWholesale = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingSuppliers = false;
          _loadingWholesale = false;
        });
        _toast('Erreur: $e', error: true);
      }
    }
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error
          ? CouturePalette.terracottaDeep
          : CoutureScheme.of(context).goodInk,
    ));
  }

  int get _totalSupplierDebt => _purchases.fold(0, (sum, p) => sum + p.reste);
  int get _totalWholesaleReceivable =>
      _wholesaleOrders.fold(0, (sum, o) => sum + o.reste);

  @override
  Widget build(BuildContext context) {
    return CoutureScaffold(
      title: 'Gros et fournisseurs',
      subtitle: 'Ce que la boutique doit, ce qu\'on lui doit',
      actions: <Widget>[
        CoutureBandAction(
          icon: CoutureIcons.refresh,
          tooltip: 'Actualiser',
          onPressed: _loadAll,
        ),
      ],
      below: Padding(
        padding: const EdgeInsets.fromLTRB(CouturePalette.s4, CouturePalette.s3,
            CouturePalette.s4, CouturePalette.s3),
        child: Row(
          children: <Widget>[
            CoutureFilterChip(
              icon: CoutureIcons.storefront,
              label: 'Fournisseurs',
              selected: _tabController.index == 0,
              onTap: () => _tabController.animateTo(0),
            ),
            const SizedBox(width: CouturePalette.s2),
            CoutureFilterChip(
              icon: CoutureIcons.truck,
              label: 'Ventes en gros',
              selected: _tabController.index == 1,
              onTap: () => _tabController.animateTo(1),
            ),
          ],
        ),
      ),
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildSuppliersTab(),
          _buildWholesaleTab(),
        ],
      ),
    );
  }

  // ==========================================================================
  // TAB 1: FOURNISSEURS & ACHATS À CRÉDIT
  // ==========================================================================
  Widget _buildSuppliersTab() {
    if (_loadingSuppliers)
      return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Stat Summary Card
          Card(
            color: CoutureScheme.of(context).card,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: CoutureScheme.of(context).urgentWash,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(CoutureIcons.wallet,
                            color: CoutureScheme.of(context).urgentText,
                            size: 26),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ce que la boutique doit',
                              style: TextStyle(
                                  color: CoutureScheme.of(context).inkSoft,
                                  fontSize: 13)),
                          Text(formatFcfa(_totalSupplierDebt),
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: CoutureScheme.of(context).urgentText)),
                        ],
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _openAddSupplierPurchaseModal(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Nouvel Achat'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Répertoire des Fournisseurs (Directory)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Répertoire des Fournisseurs',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              TextButton.icon(
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Nouveau Fournisseur'),
                onPressed: _openAddSupplierModal,
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_suppliers.isEmpty)
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                    'Aucun fournisseur. Appuyez sur « Nouveau fournisseur ».',
                    style:
                        TextStyle(color: CoutureScheme.of(context).inkFaint)),
              ),
            )
          else
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _suppliers.length,
                itemBuilder: (ctx, i) {
                  final s = _suppliers[i];
                  return Container(
                    width: 230,
                    margin: const EdgeInsets.only(right: 12),
                    child: Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _openAddSupplierPurchaseModal(
                            preselectedSupplier: s),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(s.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    if (s.phone.isNotEmpty)
                                      Text('Tél: ${s.phone}',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: CoutureScheme.of(context)
                                                  .inkSoft)),
                                    const SizedBox(height: 4),
                                    Text('Dette: ${formatFcfa(s.totalDebt)}',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: s.totalDebt > 0
                                                ? CoutureScheme.of(context)
                                                    .urgentText
                                                : CoutureScheme.of(context)
                                                    .goodInk)),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert_rounded,
                                    size: 18),
                                onSelected: (val) {
                                  if (val == 'edit') _openEditSupplierModal(s);
                                  if (val == 'delete')
                                    _confirmDeleteSupplier(s);
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(children: [
                                        Icon(Icons.edit_rounded, size: 16),
                                        SizedBox(width: 8),
                                        Text('Modifier')
                                      ])),
                                  const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(children: [
                                        Icon(CoutureIcons.trash,
                                            color:
                                                CouturePalette.terracottaDeep,
                                            size: 16),
                                        SizedBox(width: 8),
                                        Text('Supprimer',
                                            style: TextStyle(
                                                color: CouturePalette
                                                    .terracottaDeep))
                                      ])),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 20),

          const Text('Historique des Achats à Crédit',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          if (_purchases.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('Aucun achat à crédit enregistré.')),
            )
          else
            ..._purchases.map((p) => _buildPurchaseCard(p)),
        ],
      ),
    );
  }

  Widget _buildPurchaseCard(SupplierPurchase p) {
    final isPaid = p.reste <= 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: isPaid
              ? CoutureScheme.of(context).goodWash
              : CoutureScheme.of(context).urgentWash,
          child: Icon(isPaid ? CoutureIcons.checkCircle : CoutureIcons.clock,
              color: isPaid
                  ? CoutureScheme.of(context).goodInk
                  : CoutureScheme.of(context).urgentText,
              size: 20),
        ),
        title: Text(p.supplierName,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p.description),
            const SizedBox(height: 4),
            Text(
                'Date: ${p.purchaseDate} · Total: ${formatFcfa(p.totalAmount)}',
                style: TextStyle(
                    fontSize: 12, color: CoutureScheme.of(context).inkSoft)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(isPaid ? 'Payé' : 'Reste ${formatFcfa(p.reste)}',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isPaid
                            ? CoutureScheme.of(context).goodInk
                            : CoutureScheme.of(context).urgentText)),
                if (!isPaid)
                  TextButton(
                    style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 24)),
                    onPressed: () => _openSupplierPaymentModal(p),
                    child: const Text('Régler'),
                  ),
              ],
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, size: 20),
              onSelected: (val) {
                if (val == 'edit') _openEditSupplierPurchaseModal(p);
                if (val == 'delete') _confirmDeleteSupplierPurchase(p);
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_rounded, size: 16),
                      SizedBox(width: 8),
                      Text('Modifier')
                    ])),
                const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(CoutureIcons.trash,
                          color: CouturePalette.terracottaDeep, size: 16),
                      SizedBox(width: 8),
                      Text('Supprimer',
                          style:
                              TextStyle(color: CouturePalette.terracottaDeep))
                    ])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // TAB 2: VENTES EN GROS (PRÊT-À-PORTER)
  // ==========================================================================
  Widget _buildWholesaleTab() {
    if (_loadingWholesale)
      return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary Card
          Card(
            color: CoutureScheme.of(context).card,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: CoutureScheme.of(context).goodWash,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(CoutureIcons.wallet,
                            color: CoutureScheme.of(context).goodInk, size: 26),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ce qu\'on doit à la boutique',
                              style: TextStyle(
                                  color: CoutureScheme.of(context).inkSoft,
                                  fontSize: 13)),
                          Text(formatFcfa(_totalWholesaleReceivable),
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: CoutureScheme.of(context).goodInk)),
                        ],
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _openAddWholesaleOrderModal,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Nouvelle Vente'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Text('Commandes & Distributions en Gros',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          if (_wholesaleOrders.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child:
                  Center(child: Text('Aucune commande en gros enregistrée.')),
            )
          else
            ..._wholesaleOrders.map((o) => _buildWholesaleCard(o)),
        ],
      ),
    );
  }

  Widget _buildWholesaleCard(WholesaleOrder o) {
    final isPaid = o.reste <= 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: isPaid
              ? CoutureScheme.of(context).goodWash
              : CoutureScheme.of(context).iconWash,
          child: Icon(CoutureIcons.storefront,
              color: isPaid
                  ? CoutureScheme.of(context).goodInk
                  : CoutureScheme.of(context).iconInk,
              size: 20),
        ),
        title: Text(o.merchantName,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
            'Date: ${o.orderDate} · Total: ${formatFcfa(o.totalAmount)} · Reste: ${formatFcfa(o.reste)}',
            style: const TextStyle(fontSize: 12)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const Text('Articles distribués:',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ...o.items.map((i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text('• ${i.model} x${i.qty}',
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 8),
                          Text(
                              '${formatFcfa(i.total)} (${formatFcfa(i.unitPrice)}/unité)'),
                        ],
                      ),
                    )),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      IconButton(
                        icon: Icon(CoutureIcons.printer,
                            color: CoutureScheme.of(context).iconInk),
                        tooltip: 'Imprimer Facture',
                        onPressed: () {
                          final settings = context.read<ShopSettingsProvider>();
                          MerchantInvoiceService.shareWholesaleInvoice(
                            shopName: settings.shopName,
                            order: o,
                            logoUrl: settings.logoUrl,
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(CoutureIcons.pencil,
                            color: CoutureScheme.of(context).inkSoft),
                        tooltip: 'Modifier Vente',
                        onPressed: () => _openEditWholesaleOrderModal(o),
                      ),
                      IconButton(
                        icon: Icon(CoutureIcons.trash,
                            color: CoutureScheme.of(context).urgentText),
                        tooltip: 'Supprimer Vente',
                        onPressed: () => _confirmDeleteWholesaleOrder(o),
                      ),
                      if (!isPaid)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.payments_rounded, size: 18),
                          label: const Text('Ajouter Règlement'),
                          onPressed: () => _openWholesalePaymentModal(o),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // EDIT & DELETE MODALS
  // ==========================================================================
  Future<void> _openEditSupplierModal(Supplier s) async {
    final formKey = GlobalKey<FormState>();
    String name = s.name;
    String phone = s.phone;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Modifier le Fournisseur'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: name,
                decoration:
                    const InputDecoration(labelText: 'Nom du Fournisseur'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requis' : null,
                onSaved: (v) => name = v?.trim() ?? '',
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: phone,
                decoration: const InputDecoration(labelText: 'Téléphone'),
                keyboardType: TextInputType.phone,
                onSaved: (v) => phone = v?.trim() ?? '',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              formKey.currentState!.save();
              try {
                await _repo.updateSupplier(s.id, name: name, phone: phone);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _loadAll();
                _toast('Fournisseur mis à jour.');
              } catch (e) {
                if (ctx.mounted) _toast('Erreur: $e', error: true);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteSupplier(Supplier s) async {
    final confirm = await confirmDeleteByTyping(
      context,
      itemName: s.name,
      itemLabel: 'ce fournisseur',
      historyNote:
          'Tous ses achats et historiques restent sauvegardés sur le serveur.',
    );
    if (confirm == true) {
      try {
        await _repo.deleteSupplier(s.id);
        _loadAll();
        _toast('Fournisseur supprimé.');
      } catch (e) {
        _toast('Erreur lors de la suppression: $e', error: true);
      }
    }
  }

  Future<void> _openEditSupplierPurchaseModal(SupplierPurchase p) async {
    final formKey = GlobalKey<FormState>();
    String description = p.description;
    int totalAmount = p.totalAmount;
    int advanceAmount = p.advanceAmount;
    final totalCtrl = TextEditingController(text: formatThousands(totalAmount));
    final advanceCtrl =
        TextEditingController(text: formatThousands(advanceAmount));

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Modifier Achat — ${p.supplierName}'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: description,
                  decoration: const InputDecoration(labelText: 'Description'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requis' : null,
                  onSaved: (v) => description = v?.trim() ?? '',
                ),
                const SizedBox(height: 12),
                FormattedNumberField(
                  controller: totalCtrl,
                  label: 'Montant Total (FCFA)',
                  validator: (v) => (v == null || v <= 0) ? 'Requis > 0' : null,
                  onChanged: (v) => totalAmount = v ?? 0,
                ),
                const SizedBox(height: 12),
                FormattedNumberField(
                  controller: advanceCtrl,
                  label: 'Acompte versé (FCFA)',
                  onChanged: (v) => advanceAmount = v ?? 0,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              formKey.currentState!.save();
              try {
                await _repo.updateSupplierPurchase(
                  p.id,
                  description: description,
                  totalAmount: totalAmount,
                  advanceAmount: advanceAmount,
                );
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _loadAll();
                _toast('Achat mis à jour.');
              } catch (e) {
                if (ctx.mounted) _toast('Erreur: $e', error: true);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteSupplierPurchase(SupplierPurchase p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer l\'achat'),
        content: Text(
            'Voulez-vous vraiment supprimer cet achat de ${formatFcfa(p.totalAmount)} chez ${p.supplierName} ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: CouturePalette.terracottaDeep,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _repo.deleteSupplierPurchase(p.id);
        _loadAll();
        _toast('Achat supprimé.');
      } catch (e) {
        _toast('Erreur: $e', error: true);
      }
    }
  }

  Future<void> _openEditWholesaleOrderModal(WholesaleOrder o) async {
    final formKey = GlobalKey<FormState>();
    String merchantName = o.merchantName;
    String merchantPhone = o.merchantPhone;
    String modelName = o.items.isNotEmpty ? o.items.first.model : '';
    int qty = o.items.isNotEmpty ? o.items.first.qty : 1;
    int unitPrice = o.items.isNotEmpty ? o.items.first.unitPrice : 0;
    int advanceAmount = o.advanceAmount;

    final priceCtrl = TextEditingController(text: formatThousands(unitPrice));
    final advanceCtrl =
        TextEditingController(text: formatThousands(advanceAmount));

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Modifier Vente en Gros'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: merchantName,
                  decoration:
                      const InputDecoration(labelText: 'Nom du Commerçant'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requis' : null,
                  onSaved: (v) => merchantName = v?.trim() ?? '',
                ),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: merchantPhone,
                  decoration: const InputDecoration(labelText: 'Téléphone'),
                  keyboardType: TextInputType.phone,
                  onSaved: (v) => merchantPhone = v?.trim() ?? '',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: modelName,
                  decoration:
                      const InputDecoration(labelText: 'Modèle / Vêtement'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requis' : null,
                  onSaved: (v) => modelName = v?.trim() ?? '',
                ),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: '$qty',
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantité'),
                  validator: (v) =>
                      (int.tryParse(v ?? '') ?? 0) <= 0 ? 'Qté > 0' : null,
                  onSaved: (v) => qty = int.tryParse(v ?? '') ?? 1,
                ),
                const SizedBox(height: 8),
                FormattedNumberField(
                  controller: priceCtrl,
                  label: 'Prix Unitaire en Gros (FCFA)',
                  validator: (v) => (v == null || v <= 0) ? 'Prix > 0' : null,
                  onChanged: (v) => unitPrice = v ?? 0,
                ),
                const SizedBox(height: 8),
                FormattedNumberField(
                  controller: advanceCtrl,
                  label: 'Acompte reçu (FCFA)',
                  onChanged: (v) => advanceAmount = v ?? 0,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              formKey.currentState!.save();
              final total = qty * unitPrice;
              try {
                await _repo.updateWholesaleOrder(
                  o.id,
                  merchantName: merchantName,
                  merchantPhone: merchantPhone,
                  items: [
                    WholesaleOrderItem(
                        model: modelName, qty: qty, unitPrice: unitPrice)
                  ],
                  totalAmount: total,
                  advanceAmount: advanceAmount,
                );
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _loadAll();
                _toast('Vente en gros mise à jour.');
              } catch (e) {
                if (ctx.mounted) _toast('Erreur: $e', error: true);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteWholesaleOrder(WholesaleOrder o) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer Vente en Gros'),
        content: Text(
            'Voulez-vous vraiment supprimer cette vente de ${formatFcfa(o.totalAmount)} pour ${o.merchantName} ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: CouturePalette.terracottaDeep,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _repo.deleteWholesaleOrder(o.id);
        _loadAll();
        _toast('Vente en gros supprimée.');
      } catch (e) {
        _toast('Erreur: $e', error: true);
      }
    }
  }

  Future<void> _openAddSupplierModal() async {
    final formKey = GlobalKey<FormState>();
    String name = '';
    String phone = '';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Nouveau Fournisseur'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration:
                    const InputDecoration(labelText: 'Nom du Fournisseur'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requis' : null,
                onSaved: (v) => name = v?.trim() ?? '',
              ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Téléphone'),
                keyboardType: TextInputType.phone,
                onSaved: (v) => phone = v?.trim() ?? '',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              formKey.currentState!.save();
              try {
                await _repo.createSupplier(name: name, phone: phone);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _loadAll();
                _toast('Fournisseur ajouté.');
              } catch (e) {
                if (ctx.mounted) _toast('Erreur: $e', error: true);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  Future<void> _openAddSupplierPurchaseModal(
      {Supplier? preselectedSupplier}) async {
    final formKey = GlobalKey<FormState>();
    final String supplierId = preselectedSupplier?.id ?? '';
    String supplierName = preselectedSupplier?.name ?? '';
    String description = '';
    int totalAmount = 0;
    int advanceAmount = 0;
    final totalCtrl = TextEditingController();
    final advanceCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(preselectedSupplier != null
            ? 'Nouvel Achat — ${preselectedSupplier.name}'
            : 'Nouvel Achat à Crédit'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (preselectedSupplier == null)
                  TextFormField(
                    initialValue: supplierName,
                    decoration:
                        const InputDecoration(labelText: 'Nom du Fournisseur'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requis' : null,
                    onSaved: (v) => supplierName = v?.trim() ?? '',
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  decoration: const InputDecoration(
                      labelText:
                          'Description des marchandises (Tissu, Bazin...)'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requis' : null,
                  onSaved: (v) => description = v?.trim() ?? '',
                ),
                const SizedBox(height: 12),
                FormattedNumberField(
                  controller: totalCtrl,
                  label: 'Montant Total (FCFA)',
                  validator: (v) => (v == null || v <= 0) ? 'Requis > 0' : null,
                  onChanged: (v) => totalAmount = v ?? 0,
                ),
                const SizedBox(height: 12),
                FormattedNumberField(
                  controller: advanceCtrl,
                  label: 'Acompte versé immédiatement (FCFA)',
                  onChanged: (v) => advanceAmount = v ?? 0,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              formKey.currentState!.save();
              try {
                await _repo.createSupplierPurchase(
                  supplierId: supplierId.isNotEmpty ? supplierId : null,
                  supplierName: supplierName,
                  description: description,
                  totalAmount: totalAmount,
                  advanceAmount: advanceAmount,
                );
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _loadAll();
                _toast('Achat à crédit enregistré.');
              } catch (e) {
                if (ctx.mounted) _toast('Erreur: $e', error: true);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  Future<void> _openSupplierPaymentModal(SupplierPurchase p) async {
    final formKey = GlobalKey<FormState>();
    int amount = p.reste;
    final amountCtrl = TextEditingController(text: formatThousands(amount));

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Règlement — ${p.supplierName}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Reste à payer actuel: ${formatFcfa(p.reste)}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              FormattedNumberField(
                controller: amountCtrl,
                label: 'Montant versé (FCFA)',
                validator: (v) =>
                    (v == null || v <= 0) ? 'Montant invalide' : null,
                onChanged: (v) => amount = v ?? 0,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              formKey.currentState!.save();
              try {
                await _repo.recordSupplierPayment(
                    purchaseId: p.id, amount: amount);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _loadAll();
                _toast('Paiement fournisseur enregistré.');
              } catch (e) {
                if (ctx.mounted) _toast('Erreur: $e', error: true);
              }
            },
            child: const Text('Valider le Règlement'),
          ),
        ],
      ),
    );
  }

  Future<void> _openAddWholesaleOrderModal() async {
    final formKey = GlobalKey<FormState>();
    String merchantName = '';
    String merchantPhone = '';
    String modelName = '';
    int qty = 1;
    int unitPrice = 0;
    int advanceAmount = 0;

    final priceCtrl = TextEditingController();
    final advanceCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Nouvelle Vente en Gros'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  decoration:
                      const InputDecoration(labelText: 'Nom du Commerçant'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requis' : null,
                  onSaved: (v) => merchantName = v?.trim() ?? '',
                ),
                const SizedBox(height: 8),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Téléphone'),
                  keyboardType: TextInputType.phone,
                  onSaved: (v) => merchantPhone = v?.trim() ?? '',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  decoration: const InputDecoration(
                      labelText: 'Modèle / Vêtement (Prêt-à-porter)'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requis' : null,
                  onSaved: (v) => modelName = v?.trim() ?? '',
                ),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: '1',
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantité'),
                  validator: (v) =>
                      (int.tryParse(v ?? '') ?? 0) <= 0 ? 'Qté > 0' : null,
                  onSaved: (v) => qty = int.tryParse(v ?? '') ?? 1,
                ),
                const SizedBox(height: 8),
                FormattedNumberField(
                  controller: priceCtrl,
                  label: 'Prix Unitaire en Gros (FCFA)',
                  validator: (v) => (v == null || v <= 0) ? 'Prix > 0' : null,
                  onChanged: (v) => unitPrice = v ?? 0,
                ),
                const SizedBox(height: 8),
                FormattedNumberField(
                  controller: advanceCtrl,
                  label: 'Acompte reçu (FCFA)',
                  onChanged: (v) => advanceAmount = v ?? 0,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              formKey.currentState!.save();
              final total = qty * unitPrice;
              try {
                await _repo.createWholesaleOrder(
                  merchantName: merchantName,
                  merchantPhone: merchantPhone,
                  items: [
                    WholesaleOrderItem(
                        model: modelName, qty: qty, unitPrice: unitPrice)
                  ],
                  totalAmount: total,
                  advanceAmount: advanceAmount,
                );
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _loadAll();
                _toast('Vente en gros enregistrée.');
              } catch (e) {
                if (ctx.mounted) _toast('Erreur: $e', error: true);
              }
            },
            child: const Text('Enregistrer Vente'),
          ),
        ],
      ),
    );
  }

  Future<void> _openWholesalePaymentModal(WholesaleOrder o) async {
    final formKey = GlobalKey<FormState>();
    int amount = o.reste;
    final amountCtrl = TextEditingController(text: formatThousands(amount));

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Règlement — ${o.merchantName}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Reste à payer actuel: ${formatFcfa(o.reste)}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              FormattedNumberField(
                controller: amountCtrl,
                label: 'Montant versé (FCFA)',
                validator: (v) =>
                    (v == null || v <= 0) ? 'Montant invalide' : null,
                onChanged: (v) => amount = v ?? 0,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              formKey.currentState!.save();
              try {
                await _repo.recordWholesalePayment(
                    orderId: o.id, amount: amount);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _loadAll();
                _toast('Règlement gros enregistré.');
              } catch (e) {
                if (ctx.mounted) _toast('Erreur: $e', error: true);
              }
            },
            child: const Text('Valider le Règlement'),
          ),
        ],
      ),
    );
  }
}
