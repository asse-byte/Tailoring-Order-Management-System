import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_colors.dart';

/// Status pill used across orders, history, and dashboard cards.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status, this.compact = false});

  final String status;
  final bool compact;

  ({Color bg, Color fg, String label, IconData icon}) _styleFor(String s) {
    switch (s) {
      case AppConstants.statusPending:
        return (
          bg: AppColors.statusPending.withValues(alpha: 0.14),
          fg: AppColors.statusPending,
          label: 'Pending',
          icon: Icons.schedule_rounded,
        );
      case AppConstants.statusInProgress:
        return (
          bg: AppColors.statusInProgress.withValues(alpha: 0.14),
          fg: AppColors.statusInProgress,
          label: 'In Progress',
          icon: Icons.handyman_outlined,
        );
      case AppConstants.statusCompleted:
        return (
          bg: AppColors.statusCompleted.withValues(alpha: 0.14),
          fg: AppColors.statusCompleted,
          label: 'Completed',
          icon: Icons.check_circle_outline,
        );
      case AppConstants.statusCancelled:
        return (
          bg: AppColors.statusCancelled.withValues(alpha: 0.14),
          fg: AppColors.statusCancelled,
          label: 'Cancelled',
          icon: Icons.cancel_outlined,
        );
      default:
        return (
          bg: AppColors.surfaceAlt,
          fg: AppColors.textSecondary,
          label: s,
          icon: Icons.info_outline,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _styleFor(status);
    final double hPad = compact ? 8 : 10;
    final double vPad = compact ? 4 : 6;
    final double fontSize = compact ? 11 : 12;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(s.icon, size: compact ? 12 : 14, color: s.fg),
          SizedBox(width: compact ? 4 : 6),
          Text(
            s.label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: s.fg,
            ),
          ),
        ],
      ),
    );
  }
}
