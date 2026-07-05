import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/auth_repository.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _current = TextEditingController();
  final TextEditingController _next = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  bool _obscure = true;
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await AuthRepository().changePassword(
        currentPassword: _current.text,
        newPassword: _next.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.loc.passwordChangedSuccess),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop();
    } on AuthFailure catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.error,
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

    return Scaffold(
      appBar: AppBar(title: Text(context.loc.changePassword)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(context.loc.updatePasswordTitle,
                    style: Theme.of(context).textTheme.displayMedium),
                const SizedBox(height: 6),
                Text(
                  context.loc.changePasswordSub,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 28),
                AppTextField(
                  controller: _current,
                  label: context.loc.oldPassword,
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  validator: (v) => Validators.password(v, context),
                  suffixIcon: toggle,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _next,
                  label: context.loc.newPassword,
                  prefixIcon: Icons.lock_reset_outlined,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  validator: (v) => Validators.password(v, context),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _confirm,
                  label: context.loc.confirmNewPassword,
                  prefixIcon: Icons.check_circle_outline,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  validator: (v) =>
                      Validators.confirmPassword(v, _next.text, context),
                ),
                const SizedBox(height: 28),
                PrimaryButton(
                  label: context.loc.updatePasswordBtn,
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
