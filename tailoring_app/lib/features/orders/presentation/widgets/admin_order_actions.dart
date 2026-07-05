import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/orders_repository.dart';
import '../../domain/entities/order.dart';

/// Admin-only block rendered at the bottom of the OrderDetailScreen.
class AdminOrderActions extends StatelessWidget {
  const AdminOrderActions({super.key, required this.order});
  final TailoringOrder order;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(title: context.loc.adminActions),
        const SizedBox(height: 12),
        _ActionsCard(order: order),
      ],
    );
  }
}

class _ActionsCard extends StatelessWidget {
  const _ActionsCard({required this.order});
  final TailoringOrder order;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final isFr = loc.locale.languageCode == 'fr';
    final auth = context.watch<AuthProvider>();
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
            label: loc.updateStatus,
            icon: Icons.timeline_rounded,
            onPressed: () => _openStatusSheet(context),
          ),
          const SizedBox(height: 10),
          SecondaryButton(
            label: isFr
                ? (order.price != null
                    ? 'Modifier prix & notes'
                    : 'Définir prix & notes')
                : (order.price != null
                    ? 'Edit price & notes'
                    : 'Set price & notes'),
            icon: Icons.edit_outlined,
            onPressed: () => _openPriceNotesSheet(context),
          ),
          if (!auth.isSecretary) ...<Widget>[
            const SizedBox(height: 10),
            TextButton.icon(
              icon: const Icon(Icons.delete_outline_rounded),
              label:
                  Text(isFr ? 'Supprimer cette commande' : 'Delete this order'),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openStatusSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _StatusUpdateSheet(order: order),
    );
  }

  Future<void> _openPriceNotesSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PriceNotesSheet(order: order),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final loc = context.loc;
    final isFr = loc.locale.languageCode == 'fr';
    final bool yes = await showConfirmDialog(
      context,
      title: isFr ? 'Supprimer cette commande ?' : 'Delete this order?',
      message: isFr
          ? 'Cette action est irréversible. La commande sera définitivement supprimée.'
          : 'This action cannot be undone. The order will be permanently deleted.',
      confirmLabel: isFr ? 'Supprimer la commande' : 'Delete order',
      destructive: true,
    );
    if (!yes || !context.mounted) return;

    try {
      await OrdersRepository().deleteOrder(order.id);
      if (!context.mounted) return;
      Navigator.of(context).pop(); // Go back to orders list
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isFr ? 'Commande supprimée.' : 'Order deleted.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              isFr ? 'Impossible de supprimer : $e' : 'Could not delete: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// ----- Status update bottom sheet -----

class _StatusUpdateSheet extends StatefulWidget {
  const _StatusUpdateSheet({required this.order});
  final TailoringOrder order;

  @override
  State<_StatusUpdateSheet> createState() => _StatusUpdateSheetState();
}

class _StatusUpdateSheetState extends State<_StatusUpdateSheet> {
  late String _selected = widget.order.status;
  final TextEditingController _noteCtrl = TextEditingController();
  bool _saving = false;

  static const List<({String key, String label})> _options =
      <({String key, String label})>[
    (key: AppConstants.statusPending, label: 'En cours'),
    (key: AppConstants.statusInProgress, label: 'Prêt'),
    (key: AppConstants.statusCompleted, label: 'Livré (Archiver)'),
  ];

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final loc = context.loc;
    final isFr = loc.locale.languageCode == 'fr';
    setState(() => _saving = true);
    final auth = context.read<AuthProvider>();
    try {
      await OrdersRepository().updateStatus(
        orderId: widget.order.id,
        newStatus: _selected,
        adminUserId: auth.user!.id,
        note: _noteCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isFr ? 'Statut mis à jour.' : 'Status updated.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isFr
              ? 'Impossible de mettre à jour : $e'
              : 'Could not update: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final isFr = loc.locale.languageCode == 'fr';
    final EdgeInsets inset = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: inset.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(loc.updateStatusTitle,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                isFr
                    ? 'Choisissez un nouveau statut. Le changement sera ajouté à l\'historique.'
                    : 'Pick a new status. The change will be added to the order history.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 18),
              ..._options.map((o) {
                String optionLabel;
                if (o.key == AppConstants.statusPending) {
                  optionLabel = loc.statusPending;
                } else if (o.key == AppConstants.statusInProgress) {
                  optionLabel = loc.statusInProgress;
                } else if (o.key == AppConstants.statusCompleted) {
                  optionLabel = loc.statusCompleted;
                } else {
                  optionLabel = loc.statusCancelled;
                }
                return RadioListTile<String>(
                  title: Row(
                    children: <Widget>[
                      StatusBadge(status: o.key, compact: true),
                      const SizedBox(width: 8),
                      Text(optionLabel),
                    ],
                  ),
                  value: o.key,
                  // ignore: deprecated_member_use
                  groupValue: _selected,
                  // ignore: deprecated_member_use
                  onChanged: (v) => setState(() => _selected = v ?? _selected),
                  contentPadding: EdgeInsets.zero,
                );
              }),
              const SizedBox(height: 8),
              AppTextField(
                controller: _noteCtrl,
                label: isFr ? 'Note (optionnel)' : 'Note (optional)',
                hint: isFr
                    ? 'ex: Tissu reçu, début de la coupe demain'
                    : 'e.g. Fabric received, starting cutting tomorrow',
                maxLines: 3,
                minLines: 2,
              ),
              const SizedBox(height: 18),
              PrimaryButton(
                label: loc.updateBtn,
                loading: _saving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----- Price + notes bottom sheet -----

class _PriceNotesSheet extends StatefulWidget {
  const _PriceNotesSheet({required this.order});
  final TailoringOrder order;

  @override
  State<_PriceNotesSheet> createState() => _PriceNotesSheetState();
}

class _PriceNotesSheetState extends State<_PriceNotesSheet> {
  late final TextEditingController _priceCtrl =
      TextEditingController(text: widget.order.price?.toStringAsFixed(2) ?? '');
  late final TextEditingController _notesCtrl =
      TextEditingController(text: widget.order.adminNotes);
  bool _saving = false;

  @override
  void dispose() {
    _priceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final loc = context.loc;
    final isFr = loc.locale.languageCode == 'fr';
    final double? price = _priceCtrl.text.trim().isEmpty
        ? null
        : double.tryParse(_priceCtrl.text.trim());
    if (price != null && price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isFr
              ? 'Le prix doit être positif ou nul.'
              : 'Price must be zero or positive.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await OrdersRepository().updatePriceAndNotes(
        orderId: widget.order.id,
        price: price,
        adminNotes: _notesCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isFr ? 'Enregistré.' : 'Saved.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              isFr ? 'Impossible d\'enregistrer : $e' : 'Could not save: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final isFr = loc.locale.languageCode == 'fr';
    final EdgeInsets inset = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: inset.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(isFr ? 'Prix & notes' : 'Price & notes',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 18),
              AppTextField(
                controller: _priceCtrl,
                label: loc.price,
                hint: '0.00',
                prefixIcon:
                    isFr ? Icons.euro_rounded : Icons.attach_money_rounded,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _notesCtrl,
                label: isFr ? 'Notes pour le client' : 'Notes for the customer',
                hint: isFr
                    ? 'ex: Veuillez apporter la bande de boutons correspondante lors du retrait.'
                    : 'e.g. Please bring the matching button strip on pickup day.',
                maxLines: 4,
                minLines: 3,
              ),
              const SizedBox(height: 18),
              PrimaryButton(
                label: loc.save,
                loading: _saving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
