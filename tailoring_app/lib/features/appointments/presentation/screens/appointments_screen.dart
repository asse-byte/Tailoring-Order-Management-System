import 'package:flutter/material.dart';
import '../../../../core/data/mock_database.dart';
import '../../../../core/theme/app_colors.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  List<Map<String, dynamic>> _appointments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() => _loading = true);
    final a = await MockDatabase.instance.getAppointments();
    // Sort appointments by date
    a.sort((x, y) => DateTime.parse(x['dateTime']).compareTo(DateTime.parse(y['dateTime'])));
    setState(() {
      _appointments = a;
      _loading = false;
    });
  }

  Future<void> _addOrEditAppointment([Map<String, dynamic>? existing]) async {
    final formKey = GlobalKey<FormState>();
    String clientName = existing?['clientName'] ?? '';
    String type = existing?['type'] ?? 'Fitting (قياس)';
    String notes = existing?['notes'] ?? '';
    DateTime selectedDate = existing != null ? DateTime.parse(existing['dateTime']) : DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = existing != null ? TimeOfDay.fromDateTime(DateTime.parse(existing['dateTime'])) : const TimeOfDay(hour: 10, minute: 0);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(existing == null ? 'Nouveau Rendez-vous / New Appt' : 'Modifier Rendez-vous'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: clientName,
                    decoration: const InputDecoration(labelText: 'Nom du client / Client Name'),
                    validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                    onSaved: (v) => clientName = v ?? '',
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: const [
                      DropdownMenuItem(value: 'Fitting (قياس)', child: Text('Séance d\'essayage / Fitting (قياس)')),
                      DropdownMenuItem(value: 'Consultation (استشارة)', child: Text('Consultation / Consultation (استشارة)')),
                    ],
                    onChanged: (v) => setDlgState(() => type = v ?? 'Fitting (قياس)'),
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
                            firstDate: DateTime.now().subtract(const Duration(days: 30)),
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
                      const Text('Heure / Time:', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: notes,
                    decoration: const InputDecoration(labelText: 'Notes / Remarques'),
                    onSaved: (v) => notes = v ?? '',
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
                if (formKey.currentState!.validate()) {
                  formKey.currentState!.save();
                  final DateTime finalDateTime = DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                    selectedTime.hour,
                    selectedTime.minute,
                  );
                  final appt = {
                    'id': existing?['id'] ?? 'apt_${DateTime.now().millisecondsSinceEpoch}',
                    'clientName': clientName,
                    'type': type,
                    'notes': notes,
                    'dateTime': finalDateTime.toIso8601String(),
                  };
                  await MockDatabase.instance.saveAppointment(appt);
                  Navigator.pop(ctx);
                  _loadAppointments();
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
        title: const Text('Rendez-vous / Appointments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadAppointments,
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _appointments.isEmpty
              ? const Center(child: Text('Aucun rendez-vous planifié / No appointments'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _appointments.length,
                  itemBuilder: (context, index) {
                    final a = _appointments[index];
                    final DateTime dt = DateTime.parse(a['dateTime']);
                    final String formattedDate = '${dt.day}/${dt.month}/${dt.year} à ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
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
                        title: Text(a['clientName'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${a['type']}\n$formattedDate\nNote: ${a['notes']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_rounded, color: Colors.blue, size: 20),
                              onPressed: () => _addOrEditAppointment(a),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                              onPressed: () async {
                                await MockDatabase.instance.deleteAppointment(a['id']);
                                _loadAppointments();
                              },
                            ),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditAppointment(),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
