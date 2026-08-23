import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/language_provider.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/couture_icons.dart';
import '../../../../core/theme/couture_palette.dart';
import '../../../../core/widgets/couture/couture_scaffold.dart';
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
            validator: (v) => v == null || v.trim().isEmpty
                ? context.loc.requiredField
                : null,
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
            content: Text(success
                ? 'Nom de la boutique mis à jour.'
                : 'Échec de la mise à jour.'),
            backgroundColor: success
                ? CoutureScheme.of(context).goodInk
                : CoutureScheme.of(context).urgentText,
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
        const SnackBar(
            content: Text('Téléversement du logo...'),
            duration: Duration(seconds: 1)),
      );
      final success = await provider.uploadAndSetLogo(file);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? context.loc.logoUploadedSuccess
                : context.loc.logoUploadFailed),
            backgroundColor: success
                ? CoutureScheme.of(context).goodInk
                : CoutureScheme.of(context).urgentText,
          ),
        );
      }
    }
  }

  Future<void> _changePromoLink(BuildContext context) async {
    final provider = context.read<ShopSettingsProvider>();
    final controller = TextEditingController(text: provider.promoGroupLink);
    final bool? save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lien du groupe promo'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'Lien (WhatsApp, Facebook…)',
            hintText: 'https://chat.whatsapp.com/…',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.loc.cancel)),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.loc.save)),
        ],
      ),
    );
    if (save == true) {
      final ok = await provider.updatePromoGroupLink(controller.text.trim());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? 'Lien mis à jour.' : 'Échec de la mise à jour.'),
            backgroundColor: ok
                ? CoutureScheme.of(context).goodInk
                : CoutureScheme.of(context).urgentText,
          ),
        );
      }
    }
  }

  Future<void> _changeThemeColor(BuildContext context) async {
    final provider = context.read<ShopSettingsProvider>();
    const List<String> palette = <String>[
      '#1E293B',
      '#0F172A',
      '#334155',
      '#475569',
      '#64748B',
      '#94A3B8',
      '#000000',
      '#27272A',
      '#3F3F46',
      '#52525B',
    ];
    final String? chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Couleur du thème'),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: palette.map((hex) {
            final Color c =
                Color(int.parse('FF${hex.substring(1)}', radix: 16));
            final bool selected = provider.themeColorHex.toUpperCase() == hex;
            return GestureDetector(
              onTap: () => Navigator.pop(ctx, hex),
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: selected
                          ? CoutureScheme.of(context).ink
                          : Colors.transparent,
                      width: 3),
                ),
                child: selected
                    ? const Icon(CoutureIcons.checkCircle, color: Colors.white)
                    : null,
              ),
            );
          }).toList(),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.loc.cancel)),
        ],
      ),
    );
    if (chosen != null) {
      final ok = await provider.updateThemeColor(chosen);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok
              ? 'Couleur du thème mise à jour.'
              : 'Échec de la mise à jour.'),
          backgroundColor: ok
              ? CoutureScheme.of(context).goodInk
              : CoutureScheme.of(context).urgentText,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final shopSettings = context.watch<ShopSettingsProvider>();
    // The secretary gets a reduced page: her own account (password, language,
    // theme mode, sign out) + read-only shop identity. Everything that is shop
    // branding or financial (name/logo/promo/theme colour, default piece rate,
    // reports) stays manager-only — see CLAUDE.md rule 1.
    final bool isSec = auth.isSecretary;

    return CoutureScaffold(
      title: 'Réglages',
      subtitle: isSec ? 'Votre compte' : 'La boutique et les comptes',
      child: ListView(
        padding: const EdgeInsets.all(CouturePalette.s4 + 4),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CoutureScheme.of(context).card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: CoutureScheme.of(context).line),
            ),
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 26,
                  backgroundColor:
                      shopSettings.themeColor.withValues(alpha: 0.15),
                  child: Text(
                    (auth.user?.name.isNotEmpty ?? false)
                        ? auth.user!.name[0].toUpperCase()
                        : (isSec ? 'S' : 'A'),
                    style: TextStyle(
                      color: shopSettings.themeColor,
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
                      Text(auth.user?.name ?? (isSec ? 'Secrétaire' : 'Gérant'),
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: CoutureScheme.of(context).ink,
                                  )),
                      Text(auth.user?.email ?? '',
                          style: TextStyle(
                              color: CoutureScheme.of(context).inkSoft,
                              fontSize: 12.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _ActionTile(
            icon: Icons.lock_reset_outlined,
            title: context.loc.changePassword,
            subtitle: context.loc.changePasswordSubtitle,
            color: CoutureScheme.of(context).iconInk,
            onTap: () => context.push('/admin/change-password'),
          ),
          const SizedBox(height: 24),
          Text(
            context.loc.shopSettings,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: CoutureScheme.of(context).ink,
                ),
          ),
          const SizedBox(height: 10),
          if (isSec)
            // Read-only shop identity: informative, not editable, and carries
            // no financial figure.
            _ActionTile(
              icon: CoutureIcons.storefront,
              title: context.loc.shopNameLabel,
              subtitle: shopSettings.shopName,
              color: CoutureScheme.of(context).iconInk,
              onTap: null,
            )
          else ...[
            _ActionTile(
              icon: CoutureIcons.storefront,
              title: context.loc.shopNameLabel,
              subtitle: shopSettings.shopName,
              color: CoutureScheme.of(context).iconInk,
              onTap: () => _changeShopName(context),
            ),
            const SizedBox(height: 10),
            _ActionTile(
              icon: CoutureIcons.images,
              title: context.loc.editShopLogo,
              subtitle: shopSettings.logoUrl != null
                  ? 'Logo téléversé'
                  : 'Aucun logo (Placeholder actif)',
              color: CoutureScheme.of(context).iconInk,
              onTap: () => _changeLogo(context),
            ),
            const SizedBox(height: 10),
            _ActionTile(
              icon: Icons.mark_chat_read_rounded,
              title: 'Service WhatsApp Automatique',
              subtitle: 'Envoi 100% automatique en arrière-plan (Actif)',
              color: const Color(0xFF25D366),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    title: const Row(
                      children: [
                        Icon(CoutureIcons.checkCircle,
                            color: Color(0xFF25D366)),
                        SizedBox(width: 8),
                        Text('WhatsApp Automatique'),
                      ],
                    ),
                    content: const Text(
                      'Le service d\'envoi automatique WhatsApp en arrière-plan est activé et prêt sur le serveur.\n\n'
                      'Lors du passage d\'une commande à "Terminé", la notification est envoyée immédiatement et automatiquement au numéro du client sans appuyer sur aucun bouton.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Fermer'),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _ActionTile(
              icon: CoutureIcons.share,
              title: 'Lien du groupe promo',
              subtitle: shopSettings.promoGroupLink.isEmpty
                  ? 'Non défini (affiché sur les factures)'
                  : shopSettings.promoGroupLink,
              color: AppColors.info,
              onTap: () => _changePromoLink(context),
            ),
            const SizedBox(height: 10),
            _ActionTile(
              icon: CoutureIcons.images,
              title: 'Couleur du thème',
              subtitle: shopSettings.themeColorHex,
              color: shopSettings.themeColor,
              onTap: () => _changeThemeColor(context),
            ),
            const SizedBox(height: 10),
            _ActionTile(
              icon: Icons.assessment_rounded,
              title: 'Rapport & statistiques',
              subtitle: 'Rapport mensuel / annuel imprimable',
              color: CoutureScheme.of(context).iconInk,
              onTap: () => context.push('/admin/reports'),
            ),
          ],
          const SizedBox(height: 16),
          const _LanguageSelector(),
          const SizedBox(height: 16),
          const _ThemeModeSelector(),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            icon: const Icon(CoutureIcons.signOut),
            label: Text(context.loc.signOut),
            style: OutlinedButton.styleFrom(
              foregroundColor: CoutureScheme.of(context).urgentText,
              side: BorderSide(
                  color: CoutureScheme.of(context).urgentText, width: 1.4),
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
    final shopSettings = context.watch<ShopSettingsProvider>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: CoutureScheme.of(context).card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CoutureScheme.of(context).line),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          initialValue: lang.locale.languageCode,
          decoration: InputDecoration(
            labelText: context.loc.language,
            labelStyle: TextStyle(color: CoutureScheme.of(context).inkSoft),
            prefixIcon:
                Icon(Icons.translate_rounded, color: shopSettings.themeColor),
            border: InputBorder.none,
          ),
          dropdownColor: CoutureScheme.of(context).card,
          style:
              TextStyle(color: CoutureScheme.of(context).ink, fontSize: 14.5),
          items: [
            DropdownMenuItem(
              value: 'en',
              child: Text(context.loc.english,
                  style: TextStyle(color: CoutureScheme.of(context).ink)),
            ),
            DropdownMenuItem(
              value: 'fr',
              child: Text(context.loc.french,
                  style: TextStyle(color: CoutureScheme.of(context).ink)),
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
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  /// Null renders a read-only tile (no ripple, no chevron).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CoutureScheme.of(context).card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: CoutureScheme.of(context).line),
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
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: CoutureScheme.of(context).ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: CoutureScheme.of(context).inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(CoutureIcons.caretRight,
                    color: CoutureScheme.of(context).inkSoft),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeModeSelector extends StatelessWidget {
  const _ThemeModeSelector();

  @override
  Widget build(BuildContext context) {
    final themeProv = context.watch<ThemeProvider>();
    final shopSettings = context.watch<ShopSettingsProvider>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: CoutureScheme.of(context).card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CoutureScheme.of(context).line),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<ThemeMode>(
          initialValue: themeProv.themeMode,
          dropdownColor: CoutureScheme.of(context).card,
          style:
              TextStyle(color: CoutureScheme.of(context).ink, fontSize: 14.5),
          decoration: InputDecoration(
            labelText: "Mode d'affichage / Theme Mode",
            labelStyle: TextStyle(color: CoutureScheme.of(context).inkSoft),
            prefixIcon: Icon(CoutureIcons.gear, color: shopSettings.themeColor),
            border: InputBorder.none,
          ),
          items: [
            DropdownMenuItem(
              value: ThemeMode.system,
              child: Text('Système / System',
                  style: TextStyle(color: CoutureScheme.of(context).ink)),
            ),
            DropdownMenuItem(
              value: ThemeMode.light,
              child: Text('Clair / Light',
                  style: TextStyle(color: CoutureScheme.of(context).ink)),
            ),
            DropdownMenuItem(
              value: ThemeMode.dark,
              child: Text('Sombre / Dark',
                  style: TextStyle(color: CoutureScheme.of(context).ink)),
            ),
          ],
          onChanged: (ThemeMode? val) {
            if (val != null) {
              themeProv.setThemeMode(val);
            }
          },
        ),
      ),
    );
  }
}
