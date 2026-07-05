import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../clients/data/clients_repository.dart';
import '../../../clients/domain/client.dart';
import '../../data/appointments_repository.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  final AppointmentsRepository _repo = AppointmentsRepository();
  final ClientsRepository _clientsRepo = ClientsRepository();

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

  Future<void> _addAppointment() async {
    final formKey = GlobalKey<FormState>();
    Client? selectedClient;
    String reason = 'Essayage';
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 10, minute: 0);

    // Pick client helper
    Future<void> showClientPicker(StateSetter setDlgState) async {
      try {
        final List<Client> clients = await _clientsRepo.list(limit: 100);
        if (!mounted) return;
        final Client? chosen = await showModalBottomSheet<Client>(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sélectionner un client', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: clients.length,
                      itemBuilder: (context, index) {
                        final c = clients[index];
                        return ListTile(
                          title: Text(c.fullName),
                          subtitle: Text(c.phone),
                          onTap: () => Navigator.pop(ctx, c),
                        );
                      },
                    ),
                  )
                ],
              ),
            ),
          ),
        );
        if (chosen != null) {
          setDlgState(() {
            selectedClient = chosen;
          });
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Nouveau Rendez-vous'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Client Picker Row
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Client', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(selectedClient == null ? 'Choisir un client...' : '${selectedClient!.fullName} (${selectedClient!.phone})'),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    onTap: () => showClientPicker(setDlgState),
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: reason,
                    decoration: const InputDecoration(labelText: 'Motif'),
                    items: const [
                      DropdownMenuItem(value: 'Essayage', child: Text('Séance d\'essayage')),
                      DropdownMenuItem(value: 'Consultation', child: Text('Consultation / Mesures')),
                      DropdownMenuItem(value: 'Livraison', child: Text('Livraison')),
                    ],
                    onChanged: (v) => setDlgState(() => reason = v ?? 'Essayage'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Date:', style: TextStyle(fontWeight: FontWeight.bold)),
                      TextButton.icon(
                        icon: const Icon(Icons.calendar_today_rounded),
                        label: Text('${selectedDate.toLocal()}'.substring(0, 10)),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setDlgState(() => selectedDate = picked);
                          }
                        },
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Heure:', style: TextStyle(fontWeight: FontWeight.bold)),
                      TextButton.icon(
                        icon: const Icon(Icons.access_time_rounded),
                        label: Text(selectedTime.format(context)),
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                          );
                          if (picked != null) {
                            setDlgState(() => selectedTime = picked);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedClient == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Veuillez sélectionner un client.'), backgroundColor: Colors.orange),
                  );
                  return;
                }

                if (formKey.currentState!.validate()) {
                  formKey.currentState!.save();
                  final DateTime finalDateTime = DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                    selectedTime.hour,
                    selectedTime.minute,
                  );

                  try {
                    await _repo.create(
                      clientId: selectedClient!.id,
                      scheduledAt: finalDateTime.toUtc().toIso8601String(),
                      reason: reason,
                    );
                    Navigator.pop(ctx);
                    _loadAppointments();
                  } catch (e) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RAYAN COUTURE - Calendrier'),
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
                        final String formattedDate = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} à ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
                        final bool isOverdue = dt.isBefore(DateTime.now());

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isOverdue ? Colors.grey[200] : AppColors.primary.withOpacity(0.1),
                              child: Icon(
                                Icons.calendar_today_rounded,
                                color: isOverdue ? Colors.grey : AppColors.primary,
                              ),
                            ),
                            title: Text(a.clientName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Motif: ${a.reason}\nPlanifié le: $formattedDate\nTél: ${a.clientPhone}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
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
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _addAppointment,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }
}
