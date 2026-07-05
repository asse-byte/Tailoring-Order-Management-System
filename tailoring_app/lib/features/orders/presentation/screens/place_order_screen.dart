import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/garment_types.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/connectivity_helper.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../customers/presentation/providers/customer_profile_provider.dart';
import '../../data/orders_repository.dart';
import '../../data/orders_sync_service.dart';
import '../../domain/entities/order.dart';
import '../providers/customer_tab_controller.dart';

class PlaceOrderScreen extends StatefulWidget {
  const PlaceOrderScreen({super.key});

  @override
  State<PlaceOrderScreen> createState() => _PlaceOrderScreenState();
}

class _PlaceOrderScreenState extends State<PlaceOrderScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _fabricCtrl = TextEditingController();
  final TextEditingController _instructionsCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final OrdersRepository _repo = OrdersRepository();

  String _garment = GarmentTypes.all.first;
  DateTime? _delivery;
  File? _fabricPhoto;
  File? _stylePhoto;
  bool _submitting = false;

  @override
  void dispose() {
    _fabricCtrl.dispose();
    _instructionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _delivery ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _delivery = picked);
  }

  Future<File?> _pickImage(ImageSource source) async {
    final XFile? x = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 80,
    );
    return x == null ? null : File(x.path);
  }

  void _showImageSourceDialog(bool isFabric) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(context.loc.camera),
              onTap: () async {
                Navigator.pop(ctx);
                final f = await _pickImage(ImageSource.camera);
                if (f != null) {
                  setState(() {
                    if (isFabric) {
                      _fabricPhoto = f;
                    } else {
                      _stylePhoto = f;
                    }
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(context.loc.gallery),
              onTap: () async {
                Navigator.pop(ctx);
                final f = await _pickImage(ImageSource.gallery);
                if (f != null) {
                  setState(() {
                    if (isFabric) {
                      _fabricPhoto = f;
                    } else {
                      _stylePhoto = f;
                    }
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_delivery == null) {
      _toast(context.loc.deliveryDateRequired, error: true);
      return;
    }
    final auth = context.read<AuthProvider>();
    final profile = context.read<CustomerProfileProvider>();
    final user = auth.user;
    if (user == null) return;

    if (profile.measurements.isEmpty) {
      _toast(context.loc.addMeasurementsFirst, error: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      // Build the order draft.
      final TailoringOrder draft = TailoringOrder(
        id: '',
        customerId: user.id,
        customerName: user.name,
        garmentType: _garment,
        fabricDescription: _fabricCtrl.text.trim(),
        specialInstructions: _instructionsCtrl.text.trim(),
        deliveryDate: _delivery!,
        status: AppConstants.statusPending,
        statusHistory: <StatusEvent>[
          StatusEvent(
            status: AppConstants.statusPending,
            changedAt: DateTime.now(),
            changedBy: user.id,
            note: 'Order placed by customer.',
          ),
        ],
        measurementsSnapshot: profile.measurements.toSnapshot(),
      );

      // ----- Offline path -----
      if (!ConnectivityHelper.instance.isOnline) {
        await OrdersSyncService.instance.queueOffline(
          order: draft,
          fabricPhoto: _fabricPhoto,
          stylePhoto: _stylePhoto,
        );
        if (!mounted) return;
        _toast(context.loc.orderSuccessOffline);
      } else {
        // ----- Online path: create + upload + patch -----
        TailoringOrder created = await _repo.createOrder(draft);

        String? fabricUrl;
        String? styleUrl;
        if (_fabricPhoto != null) {
          fabricUrl = await _repo.uploadOrderImage(
            file: _fabricPhoto!,
            storageFolder: AppConstants.fabricPhotosPath,
            orderId: created.id,
          );
        }
        if (_stylePhoto != null) {
          styleUrl = await _repo.uploadOrderImage(
            file: _stylePhoto!,
            storageFolder: AppConstants.stylePhotosPath,
            orderId: created.id,
          );
        }
        if (fabricUrl != null || styleUrl != null) {
          created = created.copyWith(
            fabricPhotoUrl: fabricUrl ?? created.fabricPhotoUrl,
            styleReferencePhotoUrl: styleUrl ?? created.styleReferencePhotoUrl,
          );
          await _repo.updateImageUrls(
            orderId: created.id,
            fabricUrl: fabricUrl,
            styleUrl: styleUrl,
          );
        }

        if (!mounted) return;
        _toast(context.loc.orderSuccess);
      }
      // Reset form + jump back to Orders tab.
      _formKey.currentState?.reset();
      _fabricCtrl.clear();
      _instructionsCtrl.clear();
      setState(() {
        _delivery = null;
        _fabricPhoto = null;
        _stylePhoto = null;
        _garment = GarmentTypes.all.first;
      });
      context.read<CustomerTabController>().goTo(0);
    } catch (e) {
      _toast('${context.loc.somethingWentWrong}: $e', error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<CustomerProfileProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(context.loc.newOrderTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (profile.measurements.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.straighten_rounded,
                            color: AppColors.warning),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            context.loc.profileMeasurementsWarning,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                Text(context.loc.garmentType,
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _garment,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.checkroom_outlined, size: 20),
                  ),
                  items: GarmentTypes.all
                      .map((g) => DropdownMenuItem<String>(
                          value: g, child: Text(context.loc.garmentName(g))))
                      .toList(growable: false),
                  onChanged: (v) => setState(() => _garment = v ?? _garment),
                ),
                const SizedBox(height: 18),
                AppTextField(
                  controller: _fabricCtrl,
                  label: context.loc.fabricDescription,
                  hint: context.loc.fabricDescHint,
                  prefixIcon: Icons.texture_rounded,
                  maxLines: 3,
                  minLines: 2,
                  validator: (v) => Validators.required(v, context,
                      label: context.loc.fabricDescription),
                ),
                const SizedBox(height: 18),
                _PhotoPickerTile(
                  title: context.loc.fabricPhotoOptional,
                  file: _fabricPhoto,
                  onPick: () => _showImageSourceDialog(true),
                  onClear: () => setState(() => _fabricPhoto = null),
                ),
                const SizedBox(height: 12),
                _PhotoPickerTile(
                  title: context.loc.stylePhotoOptional,
                  file: _stylePhoto,
                  onPick: () => _showImageSourceDialog(false),
                  onClear: () => setState(() => _stylePhoto = null),
                ),
                const SizedBox(height: 18),
                Text(context.loc.deliveryDate,
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.event_outlined, size: 20),
                    ),
                    child: Text(
                      _delivery != null
                          ? DateFormatter.date(_delivery!,
                              locale: context.loc.locale.languageCode)
                          : context.loc.selectDate,
                      style: TextStyle(
                        color: _delivery != null
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                AppTextField(
                  controller: _instructionsCtrl,
                  label: context.loc.specialInstructionsOptional,
                  hint: context.loc.specialInstructionsHint,
                  maxLines: 4,
                  minLines: 3,
                ),
                const SizedBox(height: 28),
                PrimaryButton(
                  label: context.loc.submitOrder,
                  icon: Icons.send_rounded,
                  loading: _submitting,
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

class _PhotoPickerTile extends StatelessWidget {
  const _PhotoPickerTile({
    required this.title,
    required this.file,
    required this.onPick,
    required this.onClear,
  });

  final String title;
  final File? file;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: file == null
                ? Container(
                    height: 60,
                    width: 60,
                    color: AppColors.surfaceAlt,
                    child: const Icon(Icons.add_photo_alternate_outlined,
                        color: AppColors.textMuted),
                  )
                : Image.file(file!, height: 60, width: 60, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.bodyMedium),
          ),
          if (file != null)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: onClear,
            )
          else
            TextButton(
              onPressed: onPick,
              child: Text(context.loc.choose),
            ),
        ],
      ),
    );
  }
}
