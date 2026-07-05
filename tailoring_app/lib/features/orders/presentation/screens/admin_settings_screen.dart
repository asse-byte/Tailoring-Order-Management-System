import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/language_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Admin settings: profile card, broadcast notification, sign out, language selector.
class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(context.loc.settings)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Text(
                    (auth.user?.name.isNotEmpty ?? false)
                        ? auth.user!.name[0].toUpperCase()
                        : 'A',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(auth.user?.name ?? 'Admin',
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(auth.user?.email ?? '',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _ActionTile(
            icon: Icons.campaign_outlined,
            title: context.loc.broadcastNotification,
            subtitle: context.loc.broadcastSubtitle,
            color: AppColors.primary,
            onTap: () => context.push('/admin/broadcast'),
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.bar_chart_outlined,
            title: context.loc.reportsExports,
            subtitle: context.loc.reportsSubtitle,
            color: AppColors.statusInProgress,
            onTap: () => context.push('/admin/reports'),
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.lock_reset_outlined,
            title: context.loc.changePassword,
            subtitle: context.loc.changePasswordSubtitle,
            color: AppColors.accentDark,
            onTap: () => context.push('/admin/change-password'),
          ),
          const SizedBox(height: 16),
          const _LanguageSelector(),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            icon: const Icon(Icons.logout_rounded),
            label: Text(context.loc.signOut),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error, width: 1.4),
            ),
            onPressed: () async {
              final bool yes = await showConfirmDialog(
                context,
                title: context.loc.signOutConfirmTitle,
                message: context.loc.signOutConfirmAdmin,
                confirmLabel: context.loc.signOut,
                destructive: true,
              );
              if (yes) await auth.signOut();
            },
          ),
        ],
      ),
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector();

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          initialValue: lang.locale.languageCode,
          decoration: InputDecoration(
            labelText: context.loc.language,
            prefixIcon:
                const Icon(Icons.translate_rounded, color: AppColors.primary),
            border: InputBorder.none,
          ),
          items: [
            DropdownMenuItem(
              value: 'en',
              child: Text(context.loc.english),
            ),
            DropdownMenuItem(
              value: 'fr',
              child: Text(context.loc.french),
            ),
          ],
          onChanged: (val) {
            if (val != null) {
              lang.changeLocale(Locale(val));
            }
          },
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: <Widget>[
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
