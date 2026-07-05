import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/orders_repository.dart';
import '../../domain/entities/order.dart';
import '../widgets/status_timeline.dart';

class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({
    super.key,
    required this.orderId,
    this.adminActions,
  });

  final String orderId;

  /// Slot for admin-only widgets (status updater, price editor) — wired in Step 4.
  final Widget Function(BuildContext, TailoringOrder)? adminActions;

  @override
  Widget build(BuildContext context) {
    final OrdersRepository repo = OrdersRepository();
    final auth = context.watch<AuthProvider>();
    final bool isAdmin = auth.isAdmin;
    final loc = context.loc;
    final isFr = loc.locale.languageCode == 'fr';

    return Scaffold(
      appBar: AppBar(title: Text(loc.orderDetailTitle)),
      body: StreamBuilder<TailoringOrder?>(
        stream: repo.watchOrder(orderId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final TailoringOrder? order = snap.data;
          if (order == null) {
            return EmptyState(
              title: isFr ? 'Commande introuvable' : 'Order not found',
              message: isFr
                  ? 'Cette commande a peut-être été supprimée.'
                  : 'This order may have been deleted.',
              icon: Icons.error_outline,
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _Header(order: order, isAdmin: isAdmin),
                const SizedBox(height: 20),
                _ImagesRow(order: order),
                const SizedBox(height: 20),
                SectionHeader(title: isFr ? 'Infos de commande' : 'Order info'),
                const SizedBox(height: 12),
                _InfoCard(order: order),
                if (order.specialInstructions.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 20),
                  SectionHeader(title: loc.specialInstructions),
                  const SizedBox(height: 8),
                  _NoteBlock(text: order.specialInstructions),
                ],
                if (order.adminNotes.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 20),
                  SectionHeader(
                      title:
                          isFr ? 'Notes du tailleur' : 'Notes from the tailor'),
                  const SizedBox(height: 8),
                  _NoteBlock(
                    text: order.adminNotes,
                    color: AppColors.accent.withValues(alpha: 0.10),
                    border: AppColors.accent.withValues(alpha: 0.4),
                  ),
                ],
                const SizedBox(height: 20),
                SectionHeader(
                    title: isFr ? 'Mesures utilisées' : 'Measurements used'),
                const SizedBox(height: 12),
                _MeasurementsGrid(snapshot: order.measurementsSnapshot),
                const SizedBox(height: 20),
                SectionHeader(
                    title: isFr ? 'Historique des statuts' : 'Status timeline'),
                const SizedBox(height: 12),
                StatusTimeline(history: order.statusHistory),
                if (adminActions != null) ...<Widget>[
                  const SizedBox(height: 20),
                  adminActions!(context, order),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.order, required this.isAdmin});
  final TailoringOrder order;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final isFr = loc.locale.languageCode == 'fr';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(loc.garmentName(order.garmentType),
                  style: Theme.of(context).textTheme.displayMedium),
            ),
            StatusBadge(status: order.status),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          isAdmin
              ? (isFr
                  ? 'Client : ${order.customerName}'
                  : 'Customer: ${order.customerName}')
              : (isFr
                  ? 'Commande #${order.id.substring(0, 8)}'
                  : 'Order #${order.id.substring(0, 8)}'),
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _ImagesRow extends StatelessWidget {
  const _ImagesRow({required this.order});
  final TailoringOrder order;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final isFr = loc.locale.languageCode == 'fr';
    final List<({String? url, String label, IconData icon})> tiles =
        <({String? url, String label, IconData icon})>[
      (
        url: order.fabricPhotoUrl,
        label: isFr ? 'Tissu' : 'Fabric',
        icon: Icons.texture_rounded
      ),
      (
        url: order.styleReferencePhotoUrl,
        label: isFr ? 'Référence style' : 'Style reference',
        icon: Icons.style_rounded,
      ),
    ];
    return Row(
      children: <Widget>[
        for (int i = 0; i < tiles.length; i++) ...<Widget>[
          Expanded(child: _ImageTile(data: tiles[i])),
          if (i != tiles.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({required this.data});
  final ({String? url, String label, IconData icon}) data;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final isFr = loc.locale.languageCode == 'fr';
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: data.url == null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(data.icon, color: AppColors.textMuted),
                    const SizedBox(height: 6),
                    Text(
                      isFr
                          ? 'Aucun(e) ${data.label.toLowerCase()}'
                          : 'No ${data.label.toLowerCase()}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              )
            : CachedNetworkImage(
                imageUrl: data.url!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    const Icon(Icons.broken_image_outlined),
              ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.order});
  final TailoringOrder order;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final isFr = loc.locale.languageCode == 'fr';
    final lang = loc.locale.languageCode;

    final List<({String label, String value, IconData icon})> rows =
        <({String label, String value, IconData icon})>[
      (
        label: isFr ? 'Date de livraison' : 'Delivery date',
        value: DateFormatter.date(order.deliveryDate, locale: lang),
        icon: Icons.event_outlined
      ),
      (
        label: isFr ? 'Description du tissu' : 'Fabric',
        value: order.fabricDescription.isEmpty ? '—' : order.fabricDescription,
        icon: Icons.texture_rounded
      ),
      (
        label: loc.price,
        value: order.price != null
            ? (isFr
                ? '${order.price!.toStringAsFixed(2)} €'
                : '\$${order.price!.toStringAsFixed(2)}')
            : (isFr ? 'Non assigné' : 'Not yet assigned'),
        icon: Icons.payments_outlined
      ),
      if (order.createdAt != null)
        (
          label: isFr ? 'Créée le' : 'Placed',
          value: DateFormatter.dateTime(order.createdAt!, locale: lang),
          icon: Icons.history_rounded
        ),
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
}

class _NoteBlock extends StatelessWidget {
  const _NoteBlock({required this.text, this.color, this.border});
  final String text;
  final Color? color;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color ?? AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border ?? AppColors.border),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _MeasurementsGrid extends StatelessWidget {
  const _MeasurementsGrid({required this.snapshot});
  final Map<String, dynamic> snapshot;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final List<({String label, String value})> entries =
        <({String label, String value})>[
      (label: loc.chest, value: _fmt(snapshot['chest'])),
      (label: loc.waist, value: _fmt(snapshot['waist'])),
      (label: loc.hips, value: _fmt(snapshot['hips'])),
      (label: loc.shoulder, value: _fmt(snapshot['shoulder'])),
      (label: loc.sleeve, value: _fmt(snapshot['sleeveLength'])),
      (label: loc.height, value: _fmt(snapshot['height'])),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: entries
          .map((e) => Container(
                width: (MediaQuery.of(context).size.width - 60) / 3,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(e.label, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text(e.value,
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
              ))
          .toList(growable: false),
    );
  }

  String _fmt(dynamic v) {
    if (v == null) return '—';
    if (v is num) return '${v.toStringAsFixed(1)} in';
    return v.toString();
  }
}
