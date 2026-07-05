import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
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
    // Successful sign-in is handled by the router redirect.
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: [
                    Container(
                      height: 72,
                      width: 72,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.accent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          )
                        ],
                      ),
                      child: const Icon(
                        Icons.content_cut_rounded,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Couture Mali',
                            style: TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.5,
                              height: 1.1,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            'Premium Tailoring',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: AppColors.accent.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                Text(context.loc.welcomeBack,
                    style: Theme.of(context).textTheme.displayMedium),
                const SizedBox(height: 6),
                Text(
                  context.loc.signInSubtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 36),
                AppTextField(
                  controller: _emailCtrl,
                  label: context.loc.email,
                  hint: 'you@example.com',
                  prefixIcon: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (v) => Validators.email(v, context),
                ),
                const SizedBox(height: 18),
                AppTextField(
                  controller: _passCtrl,
                  label: context.loc.password,
                  hint: '••••••••',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
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
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push('/forgot-password'),
                    child: Text(context.loc.forgotPassword),
                  ),
                ),
                const SizedBox(height: 8),
                PrimaryButton(
                  label: context.loc.login,
                  loading: auth.busy,
                  onPressed: _submit,
                ),
                const Divider(height: 32),
                Center(
                  child: TextButton.icon(
                    icon: const Icon(Icons.shield_moon_outlined, size: 18),
                    label: Text(context.loc.adminSetup),
                    onPressed: () => context.push('/admin-setup'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
