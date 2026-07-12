import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/garment_types.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/formatted_number_field.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../settings/presentation/providers/shop_settings_provider.dart';
import '../../../staff/data/staff_repository.dart';
import '../../data/invoice_service.dart';
import '../../data/orders_repository.dart';
import '../../domain/entities/order.dart';

/// Détail d'une commande + actions (statut, prix/avance/notes, suppression
/// réservée au gérant). Utilisé pour les commandes actives ET l'Historique.
class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});
  final String orderId;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final OrdersRepository _repo = OrdersRepository();
  final StaffRepository _staffRepo = StaffRepository();
  TailoringOrder? _order;
  List<StaffContact> _tailors = <StaffContact>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _loadTailors();
  }

  Future<void> _loadTailors() async {
    try {
      final all = await _staffRepo.listContacts();
      if (!mounted) return;
      setState(() => _tailors =
          all.where((s) => s.type == 'couturier' && s.active).toList());
    } catch (_) {/* optional */}
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _order = await _repo.getById(widget.orderId);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _changeStatus() async {
    final TailoringOrder order = _order!;
    String selected = order.status;
    const List<({String key, String label, String hint})> options =
        <({String key, String label, String hint})>[
      (key: AppConstants.statusEnAttente, label: 'En attente', hint: ''),
      (key: AppConstants.statusEnCours, label: 'En cours', hint: ''),
      (key: AppConstants.statusTermine, label: 'Terminé', hint: 'Prêt à livrer'),
      (
        key: AppConstants.statusLivre,
        label: 'Livré',
        hint: 'Déplace la commande vers l\'Historique'
      ),
    ];

    final String? chosen = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: StatefulBuilder(
          builder: (ctx, setSheetState) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Modifier le statut',
                    style: Theme.of(ctx).textTheme.headlineSmall),
                const SizedBox(height: 12),
                ...options.map((o) => RadioListTile<String>(
                      title: Row(
                        children: <Widget>[
                          StatusBadge(status: o.key, compact: true),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(o.hint.isEmpty ? o.label : o.hint),
                          ),
                        ],
                      ),
                      value: o.key,
                      // ignore: deprecated_member_use
                      groupValue: selected,
                      // ignore: deprecated_member_use
                      onChanged: (v) =>
                          setSheetState(() => selected = v ?? selected),
                      contentPadding: EdgeInsets.zero,
                    )),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'Mettre à jour',
                  onPressed: () => Navigator.pop(ctx, selected),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (chosen == null || chosen == order.status || !mounted) return;
    try {
      _order = await _repo.update(order.id, status: chosen);
      if (!mounted) return;
      setState(() {});
      _toast(chosen == AppConstants.statusLivre
          ? 'Commande livrée — déplacée vers l\'Historique.'
          : 'Statut mis à jour.');
    } catch (e) {
      if (mounted) _toast('Impossible de mettre à jour : $e', error: true);
    }
  }

  Future<void> _editDetails() async {
    final TailoringOrder order = _order!;
    final formKey = GlobalKey<FormState>();
    final advanceCtrl = TextEditingController(text: formatThousands(order.advance));
    final fabricCtrl = TextEditingController(text: order.fabric);
    final notesCtrl = TextEditingController(text: order.notes);
    String? tailorId = order.tailorId;

    final bool? saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          child: StatefulBuilder(
            builder: (ctx, setSheet) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Modifier la commande',
                        style: Theme.of(ctx).textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    Text(
                      'Le prix des articles se modifie ligne par ligne (avec motif).',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String?>(
                      initialValue: tailorId,
                      decoration: const InputDecoration(
                        labelText: 'Couturier',
                        prefixIcon: Icon(Icons.badge_outlined, size: 20),
                      ),
                      items: <DropdownMenuItem<String?>>[
                        const DropdownMenuItem<String?>(
                            value: null, child: Text('Aucun / à assigner')),
                        ..._tailors.map((t) => DropdownMenuItem<String?>(
                            value: t.id, child: Text(t.fullName))),
                      ],
                      onChanged: (v) => setSheet(() => tailorId = v),
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: fabricCtrl,
                      label: 'Tissu',
                      maxLines: 2,
                      minLines: 1,
                    ),
                    const SizedBox(height: 12),
                    FormattedNumberField(
                      controller: advanceCtrl,
                      label: 'Avance (FCFA)',
                      validator: (v) => (v == null || v < 0) ? 'Invalide' : null,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: notesCtrl,
                      label: 'Notes',
                      maxLines: 3,
                      minLines: 2,
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: 'Enregistrer',
                      onPressed: () {
                        if (formKey.currentState!.validate()) {
                          Navigator.pop(ctx, true);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (saved != true || !mounted) return;
    try {
      _order = await _repo.update(
        order.id,
        tailorId: tailorId,
        fabric: fabricCtrl.text.trim(),
        advance: parseThousands(advanceCtrl.text) ?? 0,
        notes: notesCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {});
      _toast('Enregistré.');
    } catch (e) {
      if (mounted) _toast('Impossible d\'enregistrer : $e', error: true);
    }
  }

  // ---- line items (append-only corrections) --------------------------------

  Future<void> _addLine() async {
    final formKey = GlobalKey<FormState>();
    String garment = GarmentTypes.all.first;
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController();

    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Ajouter un article'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              DropdownButtonFormField<String>(
                initialValue: garment,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Type'),
                items: GarmentTypes.all
                    .map((g) => DropdownMenuItem<String>(value: g, child: Text(g)))
                    .toList(growable: false),
                onChanged: (v) => garment = v ?? garment,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantité'),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return (n == null || n < 1) ? 'Quantité invalide' : null;
                },
              ),
              const SizedBox(height: 12),
              FormattedNumberField(
                controller: priceCtrl,
                label: 'Prix unitaire (FCFA)',
                validator: (v) => (v == null || v < 0) ? 'Prix invalide' : null,
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      _order = await _repo.addItem(
        _order!.id,
        NewOrderItem(
          garmentType: garment,
          quantity: int.tryParse(qtyCtrl.text.trim()) ?? 1,
          unitPrice: parseThousands(priceCtrl.text) ?? 0,
        ),
      );
      if (!mounted) return;
      setState(() {});
      _toast('Article ajouté.');
    } catch (e) {
      if (mounted) _toast('Impossible d\'ajouter : $e', error: true);
    }
  }

  Future<void> _correctLine(OrderItemLine line) async {
    final formKey = GlobalKey<FormState>();
    final qtyCtrl = TextEditingController(text: line.quantity.toString());
    final priceCtrl = TextEditingController(text: formatThousands(line.unitPrice));
    final reasonCtrl = TextEditingController();
    bool voided = false;

    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Corriger : ${line.garmentType}'),
        content: StatefulBuilder(
          builder: (ctx, setDlg) => Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  controller: qtyCtrl,
                  enabled: !voided,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantité'),
                  validator: (v) {
                    if (voided) return null;
                    final n = int.tryParse(v ?? '');
                    return (n == null || n < 1) ? 'Quantité invalide' : null;
                  },
                ),
                const SizedBox(height: 12),
                FormattedNumberField(
                  controller: priceCtrl,
                  label: 'Prix unitaire (FCFA)',
                  enabled: !voided,
                  validator: (v) =>
                      (!voided && (v == null || v < 0)) ? 'Prix invalide' : null,
                ),
                const SizedBox(height: 4),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: voided,
                  title: const Text('Retirer cet article (annuler)'),
                  onChanged: (v) => setDlg(() => voided = v ?? false),
                ),
                TextFormField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(labelText: 'Motif (obligatoire)'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Motif requis' : null,
                ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      _order = await _repo.correctItem(
        _order!.id,
        line.id,
        newQuantity: voided ? null : int.tryParse(qtyCtrl.text.trim()),
        newUnitPrice: voided ? null : parseThousands(priceCtrl.text),
        voided: voided,
        reason: reasonCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {});
      _toast('Correction enregistrée.');
    } catch (e) {
      if (mounted) _toast('Impossible de corriger : $e', error: true);
    }
  }

  Future<void> _shareInvoice() async {
    final shop = context.read<ShopSettingsProvider>();
    _toast('Génération de la facture…');
    try {
      await InvoiceService.shareInvoice(
        order: _order!,
        shopName: shop.shopName,
        promoGroupLink: shop.promoGroupLink,
        logoUrl: shop.logoUrl,
      );
    } catch (e) {
      if (mounted) _toast('Impossible de générer la facture : $e', error: true);
    }
  }

  Future<void> _sendWhatsApp() async {
    final shop = context.read<ShopSettingsProvider>();
    final ok = await InvoiceService.sendWhatsApp(
      order: _order!,
      shopName: shop.shopName,
      promoGroupLink: shop.promoGroupLink,
    );
    if (!ok && mounted) {
      _toast('Numéro de téléphone du client manquant ou invalide.',
          error: true);
    }
  }

  Future<void> _confirmDelete() async {
    final bool yes = await showConfirmDialog(
      context,
      title: 'Supprimer cette commande ?',
      message:
          'Cette action est irréversible. La commande sera définitivement supprimée.',
      confirmLabel: 'Supprimer la commande',
      destructive: true,
    );
    if (!yes || !mounted) return;
    try {
      await _repo.delete(_order!.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      _toast('Commande supprimée.');
    } catch (e) {
      if (mounted) _toast('Impossible de supprimer : $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Détails de la commande')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _order == null
              ? EmptyState(
                  title: 'Commande introuvable',
                  message: _error ?? 'Cette commande a peut-être été supprimée.',
                  icon: Icons.error_outline,
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    children: <Widget>[
                      _header(_order!),
                      const SizedBox(height: 20),
                      Row(
                        children: <Widget>[
                          const SectionHeader(title: 'Articles'),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _addLine,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Ajouter'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _lineItemsCard(_order!),
                      const SizedBox(height: 20),
                      const SectionHeader(title: 'Infos de commande'),
                      const SizedBox(height: 12),
                      _infoCard(_order!),
                      if (_order!.notes.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 20),
                        const SectionHeader(title: 'Notes'),
                        const SizedBox(height: 8),
                        _noteBlock(_order!.notes),
                      ],
                      const SizedBox(height: 20),
                      const SectionHeader(title: 'Mesures de référence'),
                      const SizedBox(height: 12),
                      _measurements(_order!.measurementsSnapshot),
                      const SizedBox(height: 24),
                      const SectionHeader(title: 'Actions'),
                      const SizedBox(height: 12),
                      _actions(auth),
                    ],
                  ),
                ),
    );
  }

  Widget _header(TailoringOrder order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(order.garmentType,
                  style: Theme.of(context).textTheme.displayMedium),
            ),
            StatusBadge(status: order.status),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Client : ${order.clientName}'
          '${order.clientPhone.isNotEmpty ? ' · ${order.clientPhone}' : ''}',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _lineItemsCard(TailoringOrder order) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: <Widget>[
          for (final line in order.items)
            ListTile(
              dense: true,
              title: Text(
                line.garmentType,
                style: TextStyle(
                  decoration: line.voided ? TextDecoration.lineThrough : null,
                  color: line.voided ? AppColors.textMuted : null,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                '${line.quantity} × ${formatFcfa(line.unitPrice)}'
                '${line.corrected ? '  · corrigé' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    formatFcfa(line.lineTotal),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: line.voided ? AppColors.textMuted : AppColors.primary,
                    ),
                  ),
                  if (!line.voided)
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Corriger',
                      onPressed: () => _correctLine(line),
                    ),
                ],
              ),
            ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: <Widget>[
                Text('Total', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Text(
                  formatFcfa(order.total),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(TailoringOrder order) {
    final List<({String label, String value, IconData icon})> rows =
        <({String label, String value, IconData icon})>[
      (
        label: 'Couturier',
        value: (order.tailorName == null || order.tailorName!.isEmpty)
            ? 'Non assigné'
            : order.tailorName!,
        icon: Icons.badge_outlined
      ),
      (
        label: 'Tissu',
        value: order.fabric.isEmpty ? '—' : order.fabric,
        icon: Icons.texture_rounded
      ),
      (
        label: 'Début',
        value: order.startDate != null
            ? DateFormatter.date(order.startDate!, locale: 'fr')
            : '—',
        icon: Icons.play_arrow_outlined
      ),
      (
        label: 'Livraison prévue',
        value: order.expectedDate != null
            ? DateFormatter.date(order.expectedDate!, locale: 'fr')
            : '—',
        icon: Icons.event_outlined
      ),
      if (order.deliveredDate != null)
        (
          label: 'Livrée le',
          value: DateFormatter.date(order.deliveredDate!, locale: 'fr'),
          icon: Icons.local_shipping_outlined
        ),
      (label: 'Total', value: formatFcfa(order.total), icon: Icons.payments_outlined),
      (
        label: 'Avance',
        value: formatFcfa(order.advance),
        icon: Icons.account_balance_wallet_outlined
      ),
      (label: 'Reste', value: formatFcfa(order.reste), icon: Icons.pending_outlined),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < rows.length; i++) ...<Widget>[
            Row(
              children: <Widget>[
                Icon(rows[i].icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(rows[i].label,
                      style: Theme.of(context).textTheme.bodySmall),
                ),
                Flexible(
                  child: Text(
                    rows[i].value,
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            if (i != rows.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1),
              ),
          ],
        ],
      ),
    );
  }

  Widget _noteBlock(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }

  /// Snapshot flexible : { type de vêtement → { champ → valeur } }.
  Widget _measurements(Map<String, dynamic> snapshot) {
    final List<Widget> sections = <Widget>[];
    snapshot.forEach((garment, values) {
      if (values is! Map || values.isEmpty) return;
      sections.add(Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(garment, style: Theme.of(context).textTheme.titleSmall),
      ));
      sections.add(Wrap(
        spacing: 10,
        runSpacing: 10,
        children: values.entries
            .map<Widget>((e) => Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('${e.key}',
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 4),
                      Text('${e.value}',
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                ))
            .toList(growable: false),
      ));
      sections.add(const SizedBox(height: 12));
    });
    if (sections.isEmpty) {
      return Text('Aucune mesure enregistrée pour ce client.',
          style: Theme.of(context).textTheme.bodySmall);
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: sections);
  }

  Widget _actions(AuthProvider auth) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PrimaryButton(
            label: 'Modifier le statut',
            icon: Icons.timeline_rounded,
            onPressed: _changeStatus,
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Modifier couturier, avance & notes'),
            onPressed: _editDetails,
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Facture'),
                  onPressed: _shareInvoice,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
                  label: const Text('WhatsApp'),
                  onPressed: _sendWhatsApp,
                ),
              ),
            ],
          ),
          if (auth.isAdmin) ...<Widget>[
            const SizedBox(height: 10),
            TextButton.icon(
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Supprimer cette commande'),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              onPressed: _confirmDelete,
            ),
          ],
        ],
      ),
    );
  }
}
