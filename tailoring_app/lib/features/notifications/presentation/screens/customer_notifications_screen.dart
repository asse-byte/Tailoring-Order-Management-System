import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../../domain/entities/app_notification.dart';
import '../providers/notifications_provider.dart';

class CustomerNotificationsScreen extends StatelessWidget {
  const CustomerNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _Body();
  }
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<NotificationsProvider>();
    final loc = context.loc;
    final isFr = loc.locale.languageCode == 'fr';
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.notifications),
        actions: <Widget>[
          if (p.unreadCount > 0)
            TextButton.icon(
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: Text(isFr ? 'Tout lire' : 'Mark all'),
              onPressed: p.markAllRead,
            ),
        ],
      ),
      body: _content(p, context),
    );
  }

  Widget _content(NotificationsProvider p, BuildContext context) {
    final loc = context.loc;
    final isFr = loc.locale.languageCode == 'fr';
    if (p.loading) return LoadingShimmer.list(count: 3);
    if (p.error != null) {
      return EmptyState(
        title: isFr
            ? 'Impossible de charger les notifications'
            : 'Could not load notifications',
        message: p.error,
        icon: Icons.error_outline,
      );
    }
    if (p.items.isEmpty) {
      return EmptyState(
        title: isFr ? 'Vous êtes à jour' : 'You’re all caught up',
        message: isFr
            ? 'Les mises à jour de commande et annonces de la boutique s\'afficheront ici.'
            : 'Order updates and shop announcements will appear here.',
        icon: Icons.notifications_none_rounded,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: p.items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _NotificationTile(item: p.items[i]),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item});
  final AppNotification item;

  @override
  Widget build(BuildContext context) {
    final bool unread = !item.isRead;
    final loc = context.loc;
    final lang = loc.locale.languageCode;
    return Material(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          if (unread) {
            await context.read<NotificationsProvider>().markRead(item.id);
          }
          if (item.orderId != null && context.mounted) {
            context.push('/customer/order/${item.orderId}');
          }
        },
        onLongPress: () =>
            context.read<NotificationsProvider>().delete(item.id),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: unread
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : AppColors.border,
            ),
            color: unread ? AppColors.primary.withValues(alpha: 0.05) : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: unread
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  item.orderId != null
                      ? Icons.checkroom_outlined
                      : Icons.campaign_outlined,
                  color: unread ? AppColors.primary : AppColors.textMuted,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            item.title,
                            style: Theme.of(context).textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (unread)
                          Container(
                            height: 8,
                            width: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    if (item.body.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        item.body,
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      item.createdAt != null
                          ? DateFormatter.relative(item.createdAt!,
                              locale: lang)
                          : '',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
