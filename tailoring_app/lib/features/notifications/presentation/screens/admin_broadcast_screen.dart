import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../customers/data/customers_repository.dart';
import '../../data/notifications_repository.dart';

class AdminBroadcastScreen extends StatefulWidget {
  const AdminBroadcastScreen({super.key});

  @override
  State<AdminBroadcastScreen> createState() => _AdminBroadcastScreenState();
}

class _AdminBroadcastScreenState extends State<AdminBroadcastScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _body = TextEditingController();

  bool _toAll = true;
  AppUser? _selected;
  bool _sending = false;

  final NotificationsRepository _notifs = NotificationsRepository();
  final CustomersRepository _customers = CustomersRepository();

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickRecipient() async {
    final List<AppUser> all = await _customers.watchCustomers().first;
    if (!mounted) return;
    final AppUser? chosen = await showModalBottomSheet<AppUser>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CustomerPickerSheet(customers: all),
    );
    if (chosen != null) setState(() => _selected = chosen);
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_toAll && _selected == null) {
      _toast(context.loc.selectRecipient, error: true);
      return;
    }
    final auth = context.read<AuthProvider>();
    setState(() => _sending = true);
    try {
      final String title = _title.text.trim();
      final String body = _body.text.trim();

      if (_toAll) {
        final List<AppUser> all = await _customers.watchCustomers().first;
        final List<String> ids = all.map((u) => u.id).toList(growable: false);
        if (ids.isEmpty) {
          if (!mounted) return;
          _toast(context.loc.noCustomersFound, error: true);
          setState(() => _sending = false);
          return;
        }
        final int n = await _notifs.broadcast(
          recipientIds: ids,
          title: title,
          body: body,
          senderId: auth.user!.id,
        );
        if (!mounted) return;
        final isFr = context.loc.locale.languageCode == 'fr';
        _toast(isFr
            ? 'Envoyé à $n client${n == 1 ? '' : 's'}.'
            : 'Sent to $n customer${n == 1 ? '' : 's'}.');
      } else {
        await _notifs.sendToUser(
          recipientId: _selected!.id,
          title: title,
          body: body,
          senderId: auth.user!.id,
        );
        if (!mounted) return;
        final isFr = context.loc.locale.languageCode == 'fr';
        _toast(isFr
            ? 'Notification envoyée à ${_selected!.name}.'
            : 'Notification sent to ${_selected!.name}.');
      }
      _title.clear();
      _body.clear();
      setState(() => _selected = null);
    } catch (e) {
      _toast('${context.loc.somethingWentWrong}: $e', error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
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

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final isFr = loc.locale.languageCode == 'fr';
    return Scaffold(
      appBar: AppBar(title: Text(loc.broadcastNotification)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(loc.recipient,
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: <ButtonSegment<bool>>[
                    ButtonSegment<bool>(
                      value: true,
                      label: Text(loc.allCustomers),
                      icon: const Icon(Icons.campaign_outlined),
                    ),
                    ButtonSegment<bool>(
                      value: false,
                      label: Text(loc.specificCustomer),
                      icon: const Icon(Icons.person_pin_outlined),
                    ),
                  ],
                  selected: <bool>{_toAll},
                  onSelectionChanged: (s) {
                    setState(() {
                      _toAll = s.first;
                      _selected = null;
                    });
                  },
                ),
                if (!_toAll) ...<Widget>[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            _selected == null
                                ? loc.selectRecipient
                                : '${_selected!.name} · ${_selected!.phone.isEmpty ? _selected!.email : _selected!.phone}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        TextButton(
                          onPressed: _pickRecipient,
                          child:
                              Text(_selected == null ? loc.choose : loc.change),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                AppTextField(
                  controller: _title,
                  label: loc.notificationTitle,
                  hint: isFr
                      ? 'Votre commande est prête !'
                      : 'Your order is ready for pickup!',
                  prefixIcon: Icons.title_rounded,
                  validator: (v) => Validators.required(v, context,
                      label: loc.notificationTitle),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _body,
                  label: loc.notificationBody,
                  hint: isFr
                      ? 'Ajoutez une note pour vos clients…'
                      : 'Add a friendly note for your customers…',
                  maxLines: 5,
                  minLines: 3,
                  validator: (v) => Validators.required(v, context,
                      label: loc.notificationBody),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: loc.sendNotificationBtn,
                  icon: Icons.send_rounded,
                  loading: _sending,
                  onPressed: _send,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.info_outline,
                          color: AppColors.warning, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isFr
                              ? 'Les notifications in-app fonctionnent directement. Le push nécessite le déploiement de la Cloud Function dans /functions.'
                              : 'In-app notifications work out of the box. Push (heads-up) delivery requires the Cloud Function in /functions to be deployed.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
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

// ---- Customer picker sheet (slim, reused locally) ----

class _CustomerPickerSheet extends StatefulWidget {
  const _CustomerPickerSheet({required this.customers});
  final List<AppUser> customers;

  @override
  State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final List<AppUser> list = _q.isEmpty
        ? widget.customers
        : widget.customers
            .where((u) =>
                u.name.toLowerCase().contains(_q) ||
                u.phone.toLowerCase().contains(_q) ||
                u.email.toLowerCase().contains(_q))
            .toList(growable: false);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
              Text(loc.selectRecipient,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              TextField(
                onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: loc.searchCustomer,
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: list.isEmpty
                    ? Center(child: Text(loc.noCustomersFound))
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
                                u.name.isEmpty ? '?' : u.name[0].toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            title: Text(u.name),
                            subtitle: Text(u.phone.isEmpty ? u.email : u.phone),
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
