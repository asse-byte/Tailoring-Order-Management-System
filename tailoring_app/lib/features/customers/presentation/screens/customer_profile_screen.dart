import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/language_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/measurements.dart';
import '../providers/customer_profile_provider.dart';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();

  // Measurements controllers
  final TextEditingController _chest = TextEditingController();
  final TextEditingController _waist = TextEditingController();
  final TextEditingController _hips = TextEditingController();
  final TextEditingController _shoulder = TextEditingController();
  final TextEditingController _sleeve = TextEditingController();
  final TextEditingController _height = TextEditingController();
  final TextEditingController _notes = TextEditingController();

  File? _newPhoto;
  bool _hydrated = false;

  @override
  void dispose() {
    for (final c in <TextEditingController>[
      _name,
      _phone,
      _chest,
      _waist,
      _hips,
      _shoulder,
      _sleeve,
      _height,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _hydrate(CustomerProfileProvider p) {
    if (_hydrated) return;
    if (p.user == null) return;
    // Wait until the measurements stream has emitted at least once
    // (the empty placeholder we seed has userId == '').
    if (p.measurements.userId.isEmpty) return;
    _name.text = p.user!.name;
    _phone.text = p.user!.phone;
    final m = p.measurements;
    _chest.text = m.chest?.toString() ?? '';
    _waist.text = m.waist?.toString() ?? '';
    _hips.text = m.hips?.toString() ?? '';
    _shoulder.text = m.shoulder?.toString() ?? '';
    _sleeve.text = m.sleeveLength?.toString() ?? '';
    _height.text = m.height?.toString() ?? '';
    _notes.text = m.notes;
    _hydrated = true;
  }

  Future<void> _pickPhoto() async {
    final XFile? x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 82,
    );
    if (x != null) setState(() => _newPhoto = File(x.path));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final p = context.read<CustomerProfileProvider>();

    final bool profileOk = await p.saveProfile(
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      newPhoto: _newPhoto,
    );

    final Measurements m = Measurements(
      userId: p.user!.id,
      chest: double.tryParse(_chest.text),
      waist: double.tryParse(_waist.text),
      hips: double.tryParse(_hips.text),
      shoulder: double.tryParse(_shoulder.text),
      sleeveLength: double.tryParse(_sleeve.text),
      height: double.tryParse(_height.text),
      notes: _notes.text.trim(),
    );
    final bool measureOk = await p.saveMeasurements(m);

    if (!mounted) return;
    final bool ok = profileOk && measureOk;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? context.loc.profileSaved
            : (p.error ?? context.loc.profileSaveFailed)),
        backgroundColor: ok ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (ok) setState(() => _newPhoto = null);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<CustomerProfileProvider>();
    final auth = context.read<AuthProvider>();
    _hydrate(p);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.profile),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: context.loc.signOut,
            onPressed: () async {
              final bool yes = await showConfirmDialog(
                context,
                title: context.loc.signOutConfirmTitle,
                message: context.loc.signOutConfirmCustomer,
                confirmLabel: context.loc.signOut,
                destructive: true,
              );
              if (yes) await auth.signOut();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _AvatarPicker(
                  url: p.user?.profilePhotoUrl,
                  pickedFile: _newPhoto,
                  onTap: _pickPhoto,
                ),
                const SizedBox(height: 24),
                AppTextField(
                  controller: _name,
                  label: context.loc.fullName,
                  prefixIcon: Icons.person_outline_rounded,
                  validator: (v) => Validators.required(v, context,
                      label: context.loc.fullName),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _phone,
                  label: context.loc.phone,
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (v) => Validators.phone(v, context),
                ),
                const SizedBox(height: 24),
                const _LanguageSelector(),
                const SizedBox(height: 28),
                SectionHeader(
                  title: context.loc.bodyMeasurements,
                  subtitle: context.loc.measurementsSubtitle,
                ),
                const SizedBox(height: 16),
                _MeasurePair(
                  left: _MeasureField(
                      controller: _chest, label: context.loc.chest),
                  right: _MeasureField(
                      controller: _waist, label: context.loc.waist),
                ),
                const SizedBox(height: 12),
                _MeasurePair(
                  left:
                      _MeasureField(controller: _hips, label: context.loc.hips),
                  right: _MeasureField(
                      controller: _shoulder, label: context.loc.shoulder),
                ),
                const SizedBox(height: 12),
                _MeasurePair(
                  left: _MeasureField(
                      controller: _sleeve, label: context.loc.sleeve),
                  right: _MeasureField(
                      controller: _height, label: context.loc.height),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _notes,
                  label: context.loc.notes,
                  hint: context.loc.notesHint,
                  maxLines: 3,
                  minLines: 2,
                ),
                const SizedBox(height: 32),
                PrimaryButton(
                  label: context.loc.saveChanges,
                  icon: Icons.check_rounded,
                  loading: p.saving,
                  onPressed: _save,
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  icon: const Icon(Icons.lock_reset_outlined, size: 18),
                  label: Text(context.loc.changePassword),
                  onPressed: () => context.push('/customer/change-password'),
                ),
              ],
            ),
          ),
        ),
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

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({
    required this.url,
    required this.pickedFile,
    required this.onTap,
  });

  final String? url;
  final File? pickedFile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget avatarChild;
    if (pickedFile != null) {
      avatarChild = ClipOval(
        child:
            Image.file(pickedFile!, height: 96, width: 96, fit: BoxFit.cover),
      );
    } else if (url != null && url!.isNotEmpty) {
      avatarChild = ClipOval(
        child: CachedNetworkImage(
          imageUrl: url!,
          height: 96,
          width: 96,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => const Icon(Icons.person, size: 40),
        ),
      );
    } else {
      avatarChild =
          const Icon(Icons.person, size: 44, color: AppColors.primary);
    }

    return Center(
      child: Stack(
        children: <Widget>[
          Container(
            height: 96,
            width: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.10),
              border: Border.all(color: AppColors.border),
            ),
            alignment: Alignment.center,
            child: avatarChild,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt_outlined,
                    color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MeasurePair extends StatelessWidget {
  const _MeasurePair({required this.left, required this.right});
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) => Row(
        children: <Widget>[
          Expanded(child: left),
          const SizedBox(width: 12),
          Expanded(child: right),
        ],
      );
}

class _MeasureField extends StatelessWidget {
  const _MeasureField({required this.controller, required this.label});
  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      label: label,
      hint: 'in',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (v) => Validators.positiveNumber(v, context, label: label),
    );
  }
}
