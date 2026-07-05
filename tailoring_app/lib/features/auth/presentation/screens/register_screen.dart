import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _pass = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final auth = context.read<AuthProvider>();
    final bool ok = await auth.registerCustomer(
      name: _name.text,
      email: _email.text,
      phone: _phone.text,
      password: _pass.text,
    );
    if (!mounted) return;
    if (!ok) {
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
      appBar: AppBar(title: Text(context.loc.register)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(context.loc.register,
                    style: Theme.of(context).textTheme.displayMedium),
                const SizedBox(height: 6),
                Text(
                  // 'Save measurements once and reorder in seconds.'
                  context.loc.onbDesc1,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 28),
                AppTextField(
                  controller: _name,
                  label: context.loc.fullName,
                  hint: 'Jane Doe',
                  prefixIcon: Icons.person_outline_rounded,
                  textInputAction: TextInputAction.next,
                  validator: (v) => Validators.required(v, context,
                      label: context.loc.fullName),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _email,
                  label: context.loc.email,
                  hint: 'you@example.com',
                  prefixIcon: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (v) => Validators.email(v, context),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _phone,
                  label: context.loc.phone,
                  hint: '+1 555 123 4567',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  validator: (v) => Validators.phone(v, context),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _pass,
                  label: context.loc.password,
                  hint: '••••••••',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  validator: (v) => Validators.password(v, context),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _confirm,
                  label: context.loc.confirmPassword,
                  hint: '••••••••',
                  prefixIcon: Icons.lock_reset_outlined,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  validator: (v) =>
                      Validators.confirmPassword(v, _pass.text, context),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: context.loc.register,
                  loading: auth.busy,
                  onPressed: _submit,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      context.loc.alreadyHaveAccount,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: Text(context.loc.login),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
