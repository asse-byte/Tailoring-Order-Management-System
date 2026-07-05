import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';
import '../providers/auth_provider.dart';

/// One-time admin seeding screen.
///
/// Uses the hardcoded credentials from [AppConstants.seedAdminEmail] /
/// [AppConstants.seedAdminPassword]. Idempotent — safe to run multiple times.
class AdminSetupScreen extends StatelessWidget {
  const AdminSetupScreen({super.key});

  Future<void> _seed(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final bool ok = await auth.seedAdmin();
    if (!context.mounted) return;
    if (ok) {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.prefsKeyAdminSeeded, true);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.loc.adminSetupReady),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      // Router redirect will move us into /admin home.
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? context.loc.somethingWentWrong),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(context.loc.adminSetup)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                height: 64,
                width: 64,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.shield_moon_outlined,
                    color: AppColors.accentDark, size: 32),
              ),
              const SizedBox(height: 24),
              Text(context.loc.adminSetupTitle,
                  style: Theme.of(context).textTheme.displayMedium),
              const SizedBox(height: 8),
              Text(
                context.loc.adminSetupHint,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 28),
              _CredentialRow(
                label: context.loc.email,
                value: AppConstants.seedAdminEmail,
                icon: Icons.alternate_email_rounded,
              ),
              const SizedBox(height: 12),
              _CredentialRow(
                label: context.loc.password,
                value: AppConstants.seedAdminPassword,
                icon: Icons.lock_outline_rounded,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.warning_amber_rounded,
                        color: AppColors.warning, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.loc.changePasswordPrompt,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textPrimary,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              PrimaryButton(
                label: context.loc.adminSetupBtn,
                icon: Icons.shield_outlined,
                loading: auth.busy,
                onPressed: () => _seed(context),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.go('/login'),
                child: Text(context.loc.backToSignIn),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CredentialRow extends StatelessWidget {
  const _CredentialRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 2),
                SelectableText(
                  value,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
