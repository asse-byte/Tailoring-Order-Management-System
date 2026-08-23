import 'package:flutter/material.dart';

import '../../../../core/theme/couture_icons.dart';
import '../../../../core/theme/couture_palette.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/couture/couture_bits.dart';
import '../../domain/entities/order.dart';

/// One order in a list. Redesigned onto "Indigo & Terre".
///
/// The card answers, in this order, the three questions actually asked at the
/// counter: what is it and for whom, when is it promised, and what is still
/// owed. The old card led with the fabric and put the amount owed in a red
/// chip beside the total, where the two numbers competed; the balance now sits
/// on its own line and only appears when there is one.
class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    required this.onTap,
  });

  final TailoringOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final CoutureScheme c = CoutureScheme.of(context);
    final DateTime? keyDate =
        order.isLivre ? order.deliveredDate : order.expectedDate;
    final String dateLabel = order.isLivre ? 'Livré le' : 'À rendre le';

    // Late, or due within three days: the only thing on this card allowed to
    // use the warm colour. Same rule as the agenda.
    final int? daysLeft = (!order.isLivre && keyDate != null)
        ? DateTime(keyDate.year, keyDate.month, keyDate.day)
            .difference(DateTime.now().dateOnly)
            .inDays
        : null;
    final bool pressing = daysLeft != null && daysLeft <= 3;

    return CoutureCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CoutureWash(
                icon: CoutureIcons.coatHanger,
                tone: pressing ? CoutureTone.urgent : CoutureTone.normal,
              ),
              const SizedBox(width: CouturePalette.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      order.activeItems.length > 1
                          ? '${order.garmentType} +${order.activeItems.length - 1}'
                          : order.garmentType,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: c.ink,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.clientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: c.inkSoft),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: CouturePalette.s2),
              CoutureStatusPill(status: order.status, compact: true),
            ],
          ),
          const SizedBox(height: CouturePalette.s3),
          Row(
            children: <Widget>[
              Icon(
                CoutureIcons.calendarBlank,
                size: 14,
                color: pressing ? c.urgentText : c.inkFaint,
              ),
              const SizedBox(width: CouturePalette.s1 + 1),
              Expanded(
                child: Text(
                  keyDate != null
                      ? '$dateLabel ${DateFormatter.date(keyDate, locale: 'fr')}'
                      : 'Pas de date',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: pressing ? FontWeight.w600 : FontWeight.w400,
                    color: pressing ? c.urgentText : c.inkFaint,
                  ),
                ),
              ),
              Text(
                formatFcfa(order.total),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: c.ink,
                ),
              ),
            ],
          ),
          if (order.reste > 0) ...<Widget>[
            const SizedBox(height: CouturePalette.s2),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: CouturePalette.s2 + 2, vertical: 6),
              decoration: BoxDecoration(
                color: c.urgentWash,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                'Le client doit encore ${formatFcfa(order.reste)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: c.urgentText,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

extension _DateOnly on DateTime {
  DateTime get dateOnly => DateTime(year, month, day);
}
