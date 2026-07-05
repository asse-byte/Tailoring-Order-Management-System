import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

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
import '../../../clients/data/clients_repository.dart';
import '../../../clients/domain/client.dart';
import '../../data/orders_repository.dart';
import '../../data/orders_sync_service.dart';
import '../../domain/entities/order.dart';

/// Admin: create an order on behalf of a walk-in or existing customer.
class WalkInOrderScreen extends StatefulWidget {
  const WalkInOrderScreen({super.key});

  @override
  State<WalkInOrderScreen> createState() => _WalkInOrderScreenState();
}

class _WalkInOrderScreenState extends State<WalkInOrderScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Customer selection
  bool _useExisting = false;
  Client? _selectedCustomer;
  final TextEditingController _walkInName = TextEditingController();
  final TextEditingController _walkInPhone = TextEditingController();

  // Order fields
  String _garment = GarmentTypes.all.first;
  final TextEditingController _fabric = TextEditingController();
  final TextEditingController _instructions = TextEditingController();
  DateTime? _delivery;
  final TextEditingController _price = TextEditingController();
  File? _fabricPhoto;
  File? _stylePhoto;

  // Measurements
  final TextEditingController _chest = TextEditingController();
  final TextEditingController _waist = TextEditingController();
  final TextEditingController _hips = TextEditingController();
  final TextEditingController _shoulder = TextEditingController();
  final TextEditingController _sleeve = TextEditingController();
  final TextEditingController _height = TextEditingController();
  final TextEditingController _measureNotes = TextEditingController();

  bool _submitting = false;

  final ImagePicker _picker = ImagePicker();
  final OrdersRepository _ordersRepo = OrdersRepository();
  final ClientsRepository _clientsRepo = ClientsRepository();

  @override
  void dispose() {
    for (final c in <TextEditingController>[
      _walkInName,
      _walkInPhone,
      _fabric,
      _instructions,
      _price,
      _chest,
      _waist,
      _hips,
      _shoulder,
      _sleeve,
      _height,
      _measureNotes,
    ]) {
      c.dispose();
    }
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
        source: source, maxWidth: 1600, imageQuality: 80);
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

  Future<void> _showCustomerPicker() async {
    final List<Client> clients = await _clientsRepo.list(limit: 100);
    if (!mounted) return;
    final Client? chosen = await showModalBottomSheet<Client>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CustomerPickerSheet(customers: clients),
    );
    if (chosen != null) {
      setState(() {
        _selectedCustomer = chosen;
        _walkInName.text = chosen.fullName;
        _walkInPhone.text = chosen.phone;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_delivery == null) {
      _toast(context.loc.deliveryDateRequired, error: true);
      return;
    }
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;

    final String customerId =
        _selectedCustomer?.id ?? 'walkin_${const Uuid().v4()}';
    final String customerName = _walkInName.text.trim();

    setState(() => _submitting = true);
    try {
      final Map<String, dynamic> measurementsSnapshot = <String, dynamic>{
        'chest': double.tryParse(_chest.text),
        'waist': double.tryParse(_waist.text),
        'hips': double.tryParse(_hips.text),
        'shoulder': double.tryParse(_shoulder.text),
        'sleeveLength': double.tryParse(_sleeve.text),
        'height': double.tryParse(_height.text),
        'notes': _measureNotes.text.trim(),
      };
      final double? price = _price.text.trim().isEmpty
          ? null
          : double.tryParse(_price.text.trim());

      final TailoringOrder draft = TailoringOrder(
        id: '',
        customerId: customerId,
        customerName: customerName,
        garmentType: _garment,
        fabricDescription: _fabric.text.trim(),
        specialInstructions: _instructions.text.trim(),
        deliveryDate: _delivery!,
        price: price,
        status: AppConstants.statusPending,
        statusHistory: <StatusEvent>[
          StatusEvent(
            status: AppConstants.statusPending,
            changedAt: DateTime.now(),
            changedBy: auth.user!.id,
            note: _selectedCustomer != null
                ? 'Order created by admin for existing customer.'
                : 'Walk-in order created by admin.',
          ),
        ],
        measurementsSnapshot: measurementsSnapshot,
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
        context.pop();
        return;
      }

      final TailoringOrder created = await _ordersRepo.createOrder(draft);

      String? fabricUrl;
      String? styleUrl;
      if (_fabricPhoto != null) {
        fabricUrl = await _ordersRepo.uploadOrderImage(
          file: _fabricPhoto!,
          storageFolder: AppConstants.fabricPhotosPath,
          orderId: created.id,
        );
      }
      if (_stylePhoto != null) {
        styleUrl = await _ordersRepo.uploadOrderImage(
          file: _stylePhoto!,
          storageFolder: AppConstants.stylePhotosPath,
          orderId: created.id,
        );
      }
      if (fabricUrl != null || styleUrl != null) {
        await _ordersRepo.updateImageUrls(
          orderId: created.id,
          fabricUrl: fabricUrl,
          styleUrl: styleUrl,
        );
      }

      // Save measurements to the customer's profile if they're a registered user.
      if (_selectedCustomer != null) {
        final bool hasAny = measurementsSnapshot.entries
            .any((e) => e.key != 'notes' && e.value != null);
        if (hasAny) {
          final Map<String, num> measures = {};
          measurementsSnapshot.forEach((k, v) {
            if (k != 'notes' && v is num) {
              measures[k] = v;
            }
          });
          await _clientsRepo.saveMeasurements(
            _selectedCustomer!.id,
            _garment,
            measures,
          );
        }
      }

      if (!mounted) return;
      _toast(context.loc.walkInSuccess);
      context.pop();
    } catch (e) {
      _toast('${context.loc.somethingWentWrong}: $e', error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.loc.walkInTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Customer mode toggle
                SegmentedButton<bool>(
                  segments: <ButtonSegment<bool>>[
                    ButtonSegment<bool>(
                      value: false,
                      label: Text(context.loc.walkIn),
                      icon: const Icon(Icons.person_pin_outlined),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      label: Text(context.loc.existing),
                      icon: const Icon(Icons.people_outline),
                    ),
                  ],
                  selected: <bool>{_useExisting},
                  onSelectionChanged: (s) {
                    setState(() {
                      _useExisting = s.first;
                      _selectedCustomer = null;
                      _walkInName.clear();
                      _walkInPhone.clear();
                    });
                  },
                ),
                const SizedBox(height: 16),
                if (_useExisting)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            _selectedCustomer == null
                                ? context.loc.selectRecipient
                                : '${_selectedCustomer!.fullName} · ${_selectedCustomer!.phone}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        TextButton(
                          onPressed: _showCustomerPicker,
                          child: Text(_selectedCustomer == null
                              ? context.loc.choose
                              : context.loc.change),
                        ),
                      ],
                    ),
                  )
                else ...<Widget>[
                  AppTextField(
                    controller: _walkInName,
                    label: context.loc.customerName,
                    prefixIcon: Icons.person_outline_rounded,
                    validator: (v) => Validators.required(v, context,
                        label: context.loc.customerName),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _walkInPhone,
                    label: context.loc.phone,
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                ],
                const SizedBox(height: 24),
                Text(context.loc.garmentType,
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _garment,
                  items: GarmentTypes.all
                      .map((g) => DropdownMenuItem<String>(
                          value: g, child: Text(context.loc.garmentName(g))))
                      .toList(growable: false),
                  onChanged: (v) => setState(() => _garment = v ?? _garment),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _fabric,
                  label: context.loc.fabricDescription,
                  prefixIcon: Icons.texture_rounded,
                  maxLines: 3,
                  minLines: 2,
                  validator: (v) => Validators.required(v, context,
                      label: context.loc.fabricDescription),
                ),
                const SizedBox(height: 16),
                _PhotoTile(
                  title: context.loc.fabricPhotoOptional,
                  file: _fabricPhoto,
                  onPick: () => _showImageSourceDialog(true),
                  onClear: () => setState(() => _fabricPhoto = null),
                ),
                const SizedBox(height: 10),
                _PhotoTile(
                  title: context.loc.stylePhotoOptional,
                  file: _stylePhoto,
                  onPick: () => _showImageSourceDialog(false),
                  onClear: () => setState(() => _stylePhoto = null),
                ),
                const SizedBox(height: 16),
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
                          ? DateFormatter.date(_delivery!)
                          : context.loc.selectDate,
                      style: TextStyle(
                        color: _delivery != null
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _price,
                  label:
                      '${context.loc.price} (${context.loc.specialInstructionsOptional.toLowerCase().replaceAll('instructions', '')})',
                  prefixIcon: Icons.attach_money_rounded,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _instructions,
                  label: context.loc.specialInstructionsOptional,
                  maxLines: 3,
                  minLines: 2,
                ),
                const SizedBox(height: 24),
                Text(context.loc.bodyMeasurements,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                _MeasurePair(
                    _chest, _waist, context.loc.chest, context.loc.waist),
                const SizedBox(height: 12),
                _MeasurePair(
                    _hips, _shoulder, context.loc.hips, context.loc.shoulder),
                const SizedBox(height: 12),
                _MeasurePair(
                    _sleeve, _height, context.loc.sleeve, context.loc.height),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _measureNotes,
                  label: context.loc.notes,
                  maxLines: 2,
                ),
                const SizedBox(height: 28),
                PrimaryButton(
                  label: context.loc.submitOrder,
                  icon: Icons.check_rounded,
                  loading: _submitting,
                  onPressed: () {
                    if (_useExisting && _selectedCustomer == null) {
                      _toast(context.loc.selectRecipient, error: true);
                      return;
                    }
                    _submit();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---- Tiny widgets ----

class _MeasurePair extends StatelessWidget {
  const _MeasurePair(this.a, this.b, this.la, this.lb);
  final TextEditingController a, b;
  final String la, lb;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: AppTextField(
            controller: a,
            label: la,
            hint: 'in',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) => Validators.positiveNumber(v, context, label: la),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AppTextField(
            controller: b,
            label: lb,
            hint: 'in',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) => Validators.positiveNumber(v, context, label: lb),
          ),
        ),
      ],
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
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
                    height: 56,
                    width: 56,
                    color: AppColors.surfaceAlt,
                    child: const Icon(Icons.add_photo_alternate_outlined,
                        color: AppColors.textMuted),
                  )
                : Image.file(file!, height: 56, width: 56, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(
              child:
                  Text(title, style: Theme.of(context).textTheme.bodyMedium)),
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

class _CustomerPickerSheet extends StatefulWidget {
  const _CustomerPickerSheet({required this.customers});
  final List<Client> customers;

  @override
  State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final List<Client> list = _q.isEmpty
        ? widget.customers
        : widget.customers
            .where((u) =>
                u.fullName.toLowerCase().contains(_q) ||
                u.phone.toLowerCase().contains(_q))
            .toList(growable: false);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(context.loc.selectRecipient,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              TextField(
                onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: context.loc.searchCustomer,
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: list.isEmpty
                    ? Center(child: Text(context.loc.noCustomersFound))
                    : ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final u = list[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  AppColors.primary.withValues(alpha: 0.12),
                              child: Text(
                                u.fullName.isEmpty ? '?' : u.fullName[0].toUpperCase(),
                                style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            title: Text(u.fullName),
                            subtitle: Text(u.phone.isEmpty ? '—' : u.phone),
                            onTap: () => Navigator.pop(context, u),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
