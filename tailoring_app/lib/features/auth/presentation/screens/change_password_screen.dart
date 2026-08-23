import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/couture_icons.dart';
import '../../../../core/theme/couture_palette.dart';
import '../../../../core/widgets/couture/couture_scaffold.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../providers/auth_provider.dart';
import '../../data/auth_repository.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameCtrl = TextEditingController(
      text: context.read<AuthProvider>().user?.email ?? '');
  final TextEditingController _current = TextEditingController();
  final TextEditingController _next = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  bool _obscure = true;
  bool _saving = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final String nextUsername = _usernameCtrl.text.trim();
    final String currentUsername =
        context.read<AuthProvider>().user?.email ?? '';
    final String nextPassword = _next.text;

    if (nextUsername == currentUsername && nextPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Aucun changement détecté."),
          backgroundColor: CoutureScheme.of(context).urgentText,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await AuthRepository().changePassword(
        currentPassword: _current.text,
        newPassword: nextPassword.isNotEmpty ? nextPassword : null,
        newUsername: nextUsername != currentUsername ? nextUsername : null,
      );
      if (!mounted) return;

      // Update local provider state
      await context.read<AuthProvider>().refreshSession();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Profil mis à jour avec succès !"),
          backgroundColor: CoutureScheme.of(context).goodInk,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop();
    } on AuthFailure catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: CoutureScheme.of(context).urgentText,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final IconButton toggle = IconButton(
      icon: Icon(
        _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        size: 20,
      ),
      onPressed: () => setState(() => _obscure = !_obscure),
    );

    return CoutureScaffold(
      title: 'Mon compte',
      subtitle: 'Nom et mot de passe',
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(CouturePalette.s6,
              CouturePalette.s4, CouturePalette.s6, CouturePalette.s8),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Mettez à jour vos identifiants ou votre mot de passe.',
                  style: TextStyle(
                      color: CoutureScheme.of(context).inkSoft, fontSize: 14),
                ),
                const SizedBox(height: 28),
                AppTextField(
                  controller: _usernameCtrl,
                  label: "Nom d'utilisateur",
                  prefixIcon: CoutureIcons.user,
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? "Le nom d'utilisateur est obligatoire"
                      : null,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _current,
                  label: context.loc.oldPassword,
                  prefixIcon: CoutureIcons.lock,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  validator: (v) => Validators.password(v, context),
                  suffixIcon: toggle,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _next,
                  label: 'Nouveau mot de passe (optionnel)',
                  prefixIcon: Icons.lock_reset_outlined,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.isEmpty) return null;
                    return Validators.password(v, context);
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _confirm,
                  label: 'Confirmer le nouveau mot de passe',
                  prefixIcon: Icons.check_circle_outline,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  validator: (v) {
                    if (_next.text.isEmpty) return null;
                    return Validators.confirmPassword(v, _next.text, context);
                  },
                ),
                const SizedBox(height: 28),
                PrimaryButton(
                  label: 'Mettre à jour le profil',
                  icon: Icons.shield_outlined,
                  loading: _saving,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
