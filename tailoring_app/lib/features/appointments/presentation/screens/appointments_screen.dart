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
                                : IconButton(
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
                            isThreeLine: true,
                          ),
                        );
                      },
                    ),
    );
  }
}
