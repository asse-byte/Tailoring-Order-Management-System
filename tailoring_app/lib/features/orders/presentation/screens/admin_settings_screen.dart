import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/language_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../settings/presentation/providers/shop_settings_provider.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ShopSettingsProvider>().fetchPrivateSettings();
      }
    });
  }

  Future<void> _changeShopName(BuildContext context) async {
    final provider = context.read<ShopSettingsProvider>();
    final controller = TextEditingController(text: provider.shopName);
    final formKey = GlobalKey<FormState>();

    final bool? save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.loc.editShopName),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(labelText: context.loc.shopNameLabel),
            validator: (v) => v == null || v.trim().isEmpty ? context.loc.requiredField : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.loc.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: Text(context.loc.save),
          ),
        ],
      ),
    );

    if (save == true) {
      final success = await provider.updateShopName(controller.text.trim());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Nom de la boutique mis à jour.' : 'Échec de la mise à jour.'),
            backgroundColor: success ? Colors.green : AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _changeLogo(BuildContext context) async {
    final provider = context.read<ShopSettingsProvider>();

    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (!context.mounted) return;

    if (file != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Téléversement du logo...'), duration: Duration(seconds: 1)),
      );
      final success = await provider.uploadAndSetLogo(file);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? context.loc.logoUploadedSuccess : context.loc.logoUploadFailed),
            backgroundColor: success ? Colors.green : AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _changeDefaultPieceRate(BuildContext context) async {
    final provider = context.read<ShopSettingsProvider>();
    final controller = TextEditingController(text: provider.defaultPieceRate.toString());
    final formKey = GlobalKey<FormState>();

    final bool? save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.loc.editDefaultPieceRate),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: context.loc.defaultPieceRateLabel),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return context.loc.requiredField;
              final parsed = int.tryParse(v);
              if (parsed == null || parsed < 0) return context.loc.validationPositiveNumber;
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.loc.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: Text(context.loc.save),
          ),
        ],
      ),
    );

    if (save == true) {
      final success = await provider.updateDefaultPieceRate(int.parse(controller.text));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Tarif par pièce mis à jour.' : 'Échec de la mise à jour.'),
            backgroundColor: success ? Colors.green : AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final shopSettings = context.watch<ShopSettingsProvider>();

    if (auth.isSecretary) {
      return Scaffold(
        appBar: AppBar(title: Text(context.loc.settings)),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Accès refusé. Cette page est réservée aux administrateurs.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.error,
              ),
            ),
          ),
        ),
      );
    }

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
          const SizedBox(height: 24),
          Text(
            context.loc.shopSettings,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.store_rounded,
            title: context.loc.shopNameLabel,
            subtitle: shopSettings.shopName,
            color: AppColors.primary,
            onTap: () => _changeShopName(context),
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.image_rounded,
            title: context.loc.editShopLogo,
            subtitle: shopSettings.logoUrl != null ? 'Logo téléversé' : 'Aucun logo (Placeholder actif)',
            color: AppColors.accent,
            onTap: () => _changeLogo(context),
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.monetization_on_rounded,
            title: context.loc.editDefaultPieceRate,
            subtitle: '${shopSettings.defaultPieceRate} FCFA',
            color: Colors.green,
            onTap: () => _changeDefaultPieceRate(context),
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
