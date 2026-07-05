import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../domain/entities/order.dart';

class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    required this.onTap,
    this.showCustomer = false,
  });

  final TailoringOrder order;
  final VoidCallback onTap;
  final bool showCustomer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = context.loc;
    final isFr = loc.locale.languageCode == 'fr';
    final lang = loc.locale.languageCode;

    return Material(
      color: theme.cardTheme.color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  _Thumbnail(
                      url:
                          order.fabricPhotoUrl ?? order.styleReferencePhotoUrl),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(loc.garmentName(order.garmentType),
                            style: theme.textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          showCustomer
                              ? order.customerName
                              : (isFr
                                  ? 'Livraison : ${DateFormatter.date(order.deliveryDate, locale: lang)}'
                                  : 'Delivery: ${DateFormatter.date(order.deliveryDate, locale: lang)}'),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(status: order.status),
                ],
              ),
              if (order.fabricDescription.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  order.fabricDescription,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Icon(Icons.event_outlined,
                      size: 14, color: theme.textTheme.bodySmall?.color),
                  const SizedBox(width: 4),
                  Text(
                    isFr
                        ? 'Pour le ${DateFormatter.date(order.deliveryDate, locale: lang)}'
                        : 'Due ${DateFormatter.date(order.deliveryDate, locale: lang)}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const Spacer(),
                  if (order.price != null)
                    Text(
                      isFr
                          ? '${order.price!.toStringAsFixed(2)} €'
                          : '\$${order.price!.toStringAsFixed(2)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(12);
    if (url == null || url!.isEmpty) {
      return Container(
        height: 52,
        width: 52,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.10),
          borderRadius: radius,
        ),
        child: const Icon(Icons.checkroom_outlined,
            color: AppColors.primary, size: 24),
      );
    }
    return ClipRRect(
      borderRadius: radius,
      child: CachedNetworkImage(
        imageUrl: url!,
        height: 52,
        width: 52,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          color: AppColors.surfaceAlt,
          height: 52,
          width: 52,
        ),
        errorWidget: (_, __, ___) => Container(
          color: AppColors.surfaceAlt,
          height: 52,
          width: 52,
          child: const Icon(Icons.broken_image_outlined, size: 22),
        ),
      ),
    );
  }
}
