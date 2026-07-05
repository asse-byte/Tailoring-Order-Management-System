import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../orders/data/orders_repository.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/presentation/widgets/order_card.dart';
import '../../data/customers_repository.dart';
import '../../domain/entities/measurements.dart';

/// Admin view of a single customer: profile, editable measurements, order history.
class AdminCustomerDetailScreen extends StatelessWidget {
  const AdminCustomerDetailScreen({super.key, required this.customerId});
  final String customerId;

  @override
  Widget build(BuildContext context) {
    final CustomersRepository customers = CustomersRepository();
    final loc = context.loc;
    return Scaffold(
      appBar: AppBar(title: Text(loc.customerDetail)),
      body: StreamBuilder<AppUser?>(
        stream: customers.watchUser(customerId),
        builder: (context, userSnap) {
          if (userSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final AppUser? user = userSnap.data;
          if (user == null) {
            return EmptyState(
              title: loc.customerNotFound,
              message: loc.customerNotFoundDesc,
              icon: Icons.person_off_outlined,
            );
          }
          return _Body(user: user);
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final CustomersRepository customers = CustomersRepository();
    final loc = context.loc;
    final isFr = loc.locale.languageCode == 'fr';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: <Widget>[
        _ProfileHeader(user: user),
        const SizedBox(height: 24),
        SectionHeader(
          title: loc.savedMeasurements,
          subtitle: isFr
              ? 'Enregistré sur le profil du client (en pouces).'
              : 'Saved on the customer’s profile (in inches).',
        ),
        const SizedBox(height: 12),
        StreamBuilder<Measurements>(
          stream: customers.watchMeasurements(user.id),
          builder: (context, mSnap) {
            if (!mSnap.hasData) {
              return LoadingShimmer.box(
                  height: 220, borderRadius: BorderRadius.circular(16));
            }
            return _MeasurementsEditor(
              userId: user.id,
              initial: mSnap.data!,
            );
          },
        ),
        const SizedBox(height: 24),
        SectionHeader(title: loc.orderHistory),
        const SizedBox(height: 12),
        _OrderHistory(customerId: user.id),
      ],
    );
  }
}

// ---------- Profile header ----------

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final isFr = loc.locale.languageCode == 'fr';
    final lang = loc.locale.languageCode;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: <Widget>[
          _BigAvatar(url: user.profilePhotoUrl, name: user.name),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(user.name,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                _IconRow(icon: Icons.alternate_email_rounded, text: user.email),
                if (user.phone.isNotEmpty)
                  _IconRow(icon: Icons.phone_outlined, text: user.phone),
                if (user.createdAt != null)
                  _IconRow(
                    icon: Icons.event_outlined,
                    text: isFr
                        ? 'Inscrit le ${DateFormatter.date(user.createdAt!, locale: lang)}'
                        : 'Joined ${DateFormatter.date(user.createdAt!, locale: lang)}',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BigAvatar extends StatelessWidget {
  const _BigAvatar({required this.url, required this.name});
  final String? url;
  final String name;

  @override
  Widget build(BuildContext context) {
    final String initial = name.isEmpty ? '?' : name.trim()[0].toUpperCase();
    final Widget fallback = Container(
      height: 64,
      width: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
    if (url == null || url!.isEmpty) return fallback;
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url!,
        height: 64,
        width: 64,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => fallback,
      ),
    );
  }
}

class _IconRow extends StatelessWidget {
  const _IconRow({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Measurements editor ----------

class _MeasurementsEditor extends StatefulWidget {
  const _MeasurementsEditor({required this.userId, required this.initial});
  final String userId;
  final Measurements initial;

  @override
  State<_MeasurementsEditor> createState() => _MeasurementsEditorState();
}

class _MeasurementsEditorState extends State<_MeasurementsEditor> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _chest = TextEditingController();
  final TextEditingController _waist = TextEditingController();
  final TextEditingController _hips = TextEditingController();
  final TextEditingController _shoulder = TextEditingController();
  final TextEditingController _sleeve = TextEditingController();
  final TextEditingController _height = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _chest.text = widget.initial.chest?.toString() ?? '';
    _waist.text = widget.initial.waist?.toString() ?? '';
    _hips.text = widget.initial.hips?.toString() ?? '';
    _shoulder.text = widget.initial.shoulder?.toString() ?? '';
    _sleeve.text = widget.initial.sleeveLength?.toString() ?? '';
    _height.text = widget.initial.height?.toString() ?? '';
    _notes.text = widget.initial.notes;
  }

  @override
  void dispose() {
    for (final c in <TextEditingController>[
      _chest,
      _waist,
      _hips,
      _shoulder,
      _sleeve,
      _height,
      _notes
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final loc = context.loc;
    final isFr = loc.locale.languageCode == 'fr';
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await CustomersRepository().saveMeasurements(
        Measurements(
          userId: widget.userId,
          chest: double.tryParse(_chest.text),
          waist: double.tryParse(_waist.text),
          hips: double.tryParse(_hips.text),
          shoulder: double.tryParse(_shoulder.text),
          sleeveLength: double.tryParse(_sleeve.text),
          height: double.tryParse(_height.text),
          notes: _notes.text.trim(),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.measurementsSaved),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              isFr ? 'Impossible d\'enregistrer : $e' : 'Could not save: $e'),
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
    final loc = context.loc;
    final isFr = loc.locale.languageCode == 'fr';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: <Widget>[
            _Pair(_chest, _waist, loc.chest, loc.waist),
            const SizedBox(height: 12),
            _Pair(_hips, _shoulder, loc.hips, loc.shoulder),
            const SizedBox(height: 12),
            _Pair(_sleeve, _height, loc.sleeve, loc.height),
            const SizedBox(height: 12),
            AppTextField(
              controller: _notes,
              label: loc.notes,
              hint: loc.notesHint,
              maxLines: 3,
              minLines: 2,
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: isFr ? 'Enregistrer les mesures' : 'Save measurements',
              icon: Icons.save_outlined,
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _Pair extends StatelessWidget {
  const _Pair(this.a, this.b, this.la, this.lb);
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

// ---------- Order history ----------

class _OrderHistory extends StatelessWidget {
  const _OrderHistory({required this.customerId});
  final String customerId;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return StreamBuilder<List<TailoringOrder>>(
      stream: OrdersRepository().watchCustomerOrders(customerId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Column(
            children: List<Widget>.generate(
              2,
              (_) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: LoadingShimmer.orderCard(),
              ),
            ),
          );
        }
        final List<TailoringOrder> orders = snap.data ?? <TailoringOrder>[];
        if (orders.isEmpty) {
          return EmptyState(
            title: loc.noOrdersYet,
            message: loc.noOrdersCustomerDesc,
            icon: Icons.checkroom_outlined,
          );
        }
        return Column(
          children: orders
              .map((o) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: OrderCard(
                      order: o,
                      onTap: () => context.push('/admin/order/${o.id}'),
                    ),
                  ))
              .toList(growable: false),
        );
      },
    );
  }
}
