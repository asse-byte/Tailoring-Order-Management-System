import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../domain/entities/order.dart';

class StatusTimeline extends StatelessWidget {
  const StatusTimeline({super.key, required this.history});
  final List<StatusEvent> history;

  ({Color color, IconData icon, String label}) _meta(
      String s, AppLocalizations loc) {
    switch (s) {
      case AppConstants.statusPending:
        return (
          color: AppColors.statusPending,
          icon: Icons.schedule_rounded,
          label: loc.statusPending,
        );
      case AppConstants.statusInProgress:
        return (
          color: AppColors.statusInProgress,
          icon: Icons.handyman_outlined,
          label: loc.statusInProgress,
        );
      case AppConstants.statusCompleted:
        return (
          color: AppColors.statusCompleted,
          icon: Icons.check_circle_outline,
          label: loc.statusCompleted,
        );
      case AppConstants.statusCancelled:
        return (
          color: AppColors.statusCancelled,
          icon: Icons.cancel_outlined,
          label: loc.statusCancelled,
        );
      default:
        return (
          color: AppColors.textSecondary,
          icon: Icons.info_outline,
          label: s
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final isFr = loc.locale.languageCode == 'fr';
    final lang = loc.locale.languageCode;

    if (history.isEmpty) {
      return Text(
        isFr
            ? 'Aucun historique de statut pour le moment.'
            : 'No status history yet.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    final List<StatusEvent> sorted = <StatusEvent>[...history]
      ..sort((a, b) => b.changedAt.compareTo(a.changedAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List<Widget>.generate(sorted.length, (i) {
        final StatusEvent e = sorted[i];
        final bool isLast = i == sorted.length - 1;
        final m = _meta(e.status, loc);

        String displayNote = e.note;
        if (isFr) {
          if (e.note == 'Order created by admin for existing customer.') {
            displayNote =
                "Commande créée par l'administrateur pour un client existant.";
          } else if (e.note == 'Walk-in order created by admin.') {
            displayNote = "Commande sur place créée par l'administrateur.";
          } else if (e.note == 'Order placed by customer.') {
            displayNote = "Commande passée par le client.";
          }
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Column(
                children: <Widget>[
                  Container(
                    height: 28,
                    width: 28,
                    decoration: BoxDecoration(
                      color: m.color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(m.icon, size: 16, color: m.color),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: AppColors.border,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16, top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(m.label,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        DateFormatter.dateTime(e.changedAt, locale: lang),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (displayNote.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          displayNote,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
