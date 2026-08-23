import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/couture_icons.dart';
import '../../../../core/theme/couture_palette.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../settings/presentation/providers/shop_settings_provider.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final auth = context.read<AuthProvider>();
    final bool ok = await auth.signIn(_emailCtrl.text, _passCtrl.text);
    if (!mounted) return;
    if (!ok) {
      _showError(auth.error ?? context.loc.somethingWentWrong);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: CouturePalette.terracottaDeep,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final shopSettings = context.watch<ShopSettingsProvider>();
    final String shopName = shopSettings.shopName;
    final String? logoUrl = shopSettings.logoUrl;

    final CoutureScheme c = CoutureScheme.of(context);
    final Color band = shopSettings.themeColor;

    return Scaffold(
      backgroundColor: c.paper,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(CouturePalette.s6,
                CouturePalette.s8, CouturePalette.s6, CouturePalette.s8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // The shop, not the app. A tailoring shop's login screen
                    // should look like its own front door.
                    Center(
                      child: Container(
                        height: 92,
                        width: 92,
                        decoration: BoxDecoration(
                          color: band,
                          shape: BoxShape.circle,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: (logoUrl != null && logoUrl.isNotEmpty)
                            ? Image.network(
                                logoUrl.startsWith('http')
                                    ? logoUrl
                                    : '${ApiClient.baseUrl}$logoUrl',
                                fit: BoxFit.cover,
                                loadingBuilder: (BuildContext context,
                                    Widget child, ImageChunkEvent? progress) {
                                  if (progress == null) return child;
                                  return const Center(
                                    child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white),
                                    ),
                                  );
                                },
                                errorBuilder: (_, __, ___) =>
                                    _initial(shopName),
                              )
                            : _initial(shopName),
                      ),
                    ),
                    const SizedBox(height: CouturePalette.s4),
                    Text(
                      shopName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'CormorantGaramond',
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                        color: c.ink,
                      ),
                    ),
                    const SizedBox(height: CouturePalette.s1 + 2),
                    Text(
                      'ATELIER DE COUTURE',
                      textAlign: TextAlign.center,
                      style: CouturePalette.sectionLabel
                          .copyWith(color: c.inkFaint),
                    ),
                    const SizedBox(
                        height: CouturePalette.s8 + CouturePalette.s2),
                    AppTextField(
                      controller: _emailCtrl,
                      label: context.loc.username,
                      hint: 'gerant',
                      prefixIcon: CoutureIcons.user,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.next,
                      validator: (String? v) => Validators.required(v, context),
                    ),
                    const SizedBox(height: CouturePalette.s4),
                    AppTextField(
                      controller: _passCtrl,
                      label: context.loc.password,
                      hint: '••••••••',
                      prefixIcon: CoutureIcons.lock,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      validator: (String? v) => Validators.password(v, context),
                      suffixIcon: IconButton(
                        tooltip: _obscure ? 'Montrer' : 'Cacher',
                        icon: Icon(
                          _obscure ? CoutureIcons.eye : CoutureIcons.eyeSlash,
                          size: 19,
                          color: c.inkFaint,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    const SizedBox(height: CouturePalette.s6),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: band,
                        foregroundColor:
                            ThemeData.estimateBrightnessForColor(band) ==
                                    Brightness.light
                                ? CouturePalette.ink
                                : Colors.white,
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                      ),
                      onPressed: auth.busy ? null : _submit,
                      child: auth.busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(context.loc.login,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// No logo uploaded: the shop's initial on its own colour, which is still
  /// unmistakably this shop and never someone else's branding.
  Widget _initial(String shopName) => Center(
        child: Text(
          shopName.isNotEmpty ? shopName.characters.first.toUpperCase() : 'C',
          style: const TextStyle(
            fontFamily: 'CormorantGaramond',
            fontSize: 42,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            height: 1,
          ),
        ),
      );
}
