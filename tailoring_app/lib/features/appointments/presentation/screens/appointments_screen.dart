import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/appointments_repository.dart';
import '../../../settings/presentation/providers/shop_settings_provider.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  final AppointmentsRepository _repo = AppointmentsRepository();

  List<Appointment> _appointments = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.list();
      // Sort appointments by date chronological
      list.sort((a, b) => DateTime.parse(a.scheduledAt).compareTo(DateTime.parse(b.scheduledAt)));
      setState(() {
        _appointments = list;
      });
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shopName = context.watch<ShopSettingsProvider>().shopName;
    return Scaffold(
      appBar: AppBar(
        title: Text('$shopName - Calendrier'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadAppointments,
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Erreur: $_error'))
              : _appointments.isEmpty
                  ? const Center(child: Text('Aucun rendez-vous planifié.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _appointments.length,
                      itemBuilder: (context, index) {
                        final a = _appointments[index];
                        final DateTime dt = DateTime.parse(a.scheduledAt).toLocal();
                        final bool isOrder = a.isFromOrder;
                        final String formattedDate = isOrder
                            ? '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}'
                            : '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} à ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
                        final bool isOverdue = a.daysUntil != null && a.daysUntil! < 0;
                        final bool isSoon = a.isSoon;

                        // Warning colour: appointments 3 days or less away.
                        final Color accent = isSoon
                            ? AppColors.error
                            : isOverdue
                                ? Colors.grey
                                : AppColors.primary;

                        final String countdown = isOverdue
                            ? 'En retard'
                            : a.daysUntil == 0
                                ? "Aujourd'hui"
                                : a.daysUntil == 1
                                    ? 'Demain'
                                    : 'Dans ${a.daysUntil} jours';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                            side: isSoon
                                ? const BorderSide(color: AppColors.error, width: 1.5)
                                : BorderSide.none,
                          ),
                          color: isSoon ? AppColors.error.withValues(alpha: 0.04) : null,
                          child: ListTile(
                            onTap: isOrder && a.orderId != null
                                ? () => context.push('/admin/order/${a.orderId}')
                                : null,
                            leading: CircleAvatar(
                              backgroundColor: accent.withValues(alpha: 0.12),
                              child: Icon(
                                isOrder
                                    ? Icons.local_shipping_rounded
                                    : Icons.calendar_today_rounded,
                                color: accent,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(a.clientName,
                                      style: const TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                if (isSoon)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.error,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(countdown,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700)),
                                  ),
                              ],
                            ),
                            subtitle: Text(
                              '${isOrder ? 'Livraison commande' : 'Motif: ${a.reason}'}'
                              '\n${isOrder ? 'Livraison prévue' : 'Planifié'} le: $formattedDate'
                              '${isOrder ? '' : '\nTél: ${a.clientPhone}'}',
                            ),
                             trailing: isOrder
                                 ? const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted)
                                 : Row(
                                     mainAxisSize: MainAxisSize.min,
                                     children: [
                                       IconButton(
                                         icon: const Icon(Icons.edit_rounded, color: Colors.blue, size: 20),
                                         tooltip: 'Modifier RDV',
                                         onPressed: () => _openEditAppointmentModal(a),
                                       ),
                                       IconButton(
                                         icon: const Icon(Icons.delete_outline_rounded,
                                             color: AppColors.error, size: 20),
                                         tooltip: 'Annuler RDV',
                                         onPressed: () async {
                                           final confirm = await showDialog<bool>(
                                             context: context,
                                             builder: (ctx) => AlertDialog(
                                               title: const Text('Supprimer rendez-vous ?'),
                                               content: Text('Voulez-vous supprimer le rendez-vous de ${a.clientName} ?'),
                                               actions: [
                                                 TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                                                 ElevatedButton(
                                                   style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                                   onPressed: () => Navigator.pop(ctx, true),
                                                   child: const Text('Supprimer'),
                                                 ),
                                               ],
                                             ),
                                           );
                                           if (confirm == true) {
                                             await _repo.delete(a.id);
                                             _loadAppointments();
                                           }
                                         },
                                       ),
                                     ],
                                   ),
                             isThreeLine: true,
                           ),
                         );
                       },
                     ),
    );
  }

  Future<void> _openEditAppointmentModal(Appointment a) async {
    final formKey = GlobalKey<FormState>();
    String reason = a.reason;
    DateTime dt = DateTime.tryParse(a.scheduledAt)?.toLocal() ?? DateTime.now();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Modifier Rendez-vous - ${a.clientName}'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: ['mesure', 'essayage', 'livraison', 'autre'].contains(reason) ? reason : 'autre',
                  decoration: const InputDecoration(labelText: 'Motif du RDV'),
                  items: const [
                    DropdownMenuItem(value: 'mesure', child: Text('Prise de mesures')),
                    DropdownMenuItem(value: 'essayage', child: Text('Essayage')),
                    DropdownMenuItem(value: 'livraison', child: Text('Livraison')),
                    DropdownMenuItem(value: 'autre', child: Text('Autre')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDlgState(() => reason = v);
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: const Text('Date et heure'),
                  subtitle: Text('${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} à ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'),
                  trailing: const Icon(Icons.calendar_today_rounded),
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: dt,
                      firstDate: DateTime(2026),
                      lastDate: DateTime(2030),
                    );
                    if (pickedDate != null && ctx.mounted) {
                      final pickedTime = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay.fromDateTime(dt),
                      );
                      if (pickedTime != null) {
                        setDlgState(() {
                          dt = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );
                        });
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                formKey.currentState!.save();
                try {
                  await _repo.update(
                    a.id,
                    scheduledAt: dt.toUtc().toIso8601String(),
                    reason: reason,
                  );
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  _loadAppointments();
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
                    );
                  }
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
