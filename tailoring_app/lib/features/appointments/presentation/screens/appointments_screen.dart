import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/couture_icons.dart';
import '../../../../core/theme/couture_palette.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/couture/couture_bits.dart';
import '../../../../core/widgets/couture/couture_scaffold.dart';
import '../../data/appointments_repository.dart';

/// Le calendrier : rendez-vous manuels + la date de livraison de chaque
/// commande active (source 'order', lecture seule — la commande reste la
/// source de vérité).
///
/// Redesigned onto "Indigo & Terre". Same rows, same repository, same rules;
/// what changed is that the list is now grouped by day. An agenda that reads
/// "Aujourd'hui / Demain / Vendredi 28 août" answers the question actually
/// being asked — what is there to do today — which a flat list of dated cards
/// never did.
class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key, this.repository});

  /// Injectable only so the screen can be rendered without a server in a test.
  final AppointmentsRepository? repository;

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  late final AppointmentsRepository _repo =
      widget.repository ?? AppointmentsRepository();

  List<Appointment> _appointments = <Appointment>[];
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
      final List<Appointment> list = await _repo.list();
      // Nearest first: the whole point of the screen.
      list.sort((Appointment a, Appointment b) => DateTime.parse(a.scheduledAt)
          .compareTo(DateTime.parse(b.scheduledAt)));
      if (mounted) setState(() => _appointments = list);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CoutureScaffold(
      title: 'Rendez-vous',
      subtitle: 'Ce qui est promis, jour par jour',
      actions: <Widget>[
        CoutureBandAction(
          icon: CoutureIcons.refresh,
          tooltip: 'Actualiser',
          onPressed: _loadAppointments,
        ),
      ],
      child: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return const CoutureEmpty(
        icon: CoutureIcons.warningCircle,
        tone: CoutureTone.urgent,
        title: 'Le calendrier ne s\'affiche pas',
        message: 'Vérifiez la connexion, puis appuyez sur Actualiser.',
      );
    }
    if (_appointments.isEmpty) {
      return const CoutureEmpty(
        icon: CoutureIcons.calendarBlank,
        title: 'Rien de prévu',
        message:
            'Les livraisons promises apparaissent ici dès qu\'une commande est enregistrée.',
      );
    }

    // One entry per day, in order, with its appointments under it.
    final List<_Day> days = <_Day>[];
    for (final Appointment a in _appointments) {
      final DateTime? d = a.scheduledDate?.toLocal();
      if (d == null) continue;
      final DateTime key = DateTime(d.year, d.month, d.day);
      if (days.isEmpty || days.last.date != key) {
        days.add(_Day(date: key, items: <Appointment>[a]));
      } else {
        days.last.items.add(a);
      }
    }

    return RefreshIndicator(
      onRefresh: _loadAppointments,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(CouturePalette.s4, CouturePalette.s4,
            CouturePalette.s4, CouturePalette.s8),
        itemCount: days.length,
        itemBuilder: (_, int i) => _DaySection(
          day: days[i],
          onEdit: _openEditAppointmentModal,
          onDelete: _confirmDelete,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Appointment a) async {
    final CoutureScheme c = CoutureScheme.of(context);
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: c.card,
        title: Text('Enlever ce rendez-vous ?',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w600, color: c.ink)),
        content: Text(
            'Le rendez-vous de ${a.clientName} sera enlevé du calendrier.',
            style: TextStyle(color: c.inkSoft)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(foregroundColor: c.inkSoft),
            child: const Text('Retour'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: c.urgentInk),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enlever'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _repo.delete(a.id);
      await _loadAppointments();
    }
  }

  Future<void> _openEditAppointmentModal(Appointment a) async {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final CoutureScheme c = CoutureScheme.of(context);
    String reason = a.reason;
    DateTime dt = DateTime.tryParse(a.scheduledAt)?.toLocal() ?? DateTime.now();

    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setDlgState) => AlertDialog(
          backgroundColor: c.card,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Rendez-vous de ${a.clientName}',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600, color: c.ink)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                DropdownButtonFormField<String>(
                  initialValue: const <String>[
                    'mesure',
                    'essayage',
                    'livraison',
                    'autre'
                  ].contains(reason)
                      ? reason
                      : 'autre',
                  decoration: const InputDecoration(labelText: 'Pourquoi ?'),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(
                        value: 'mesure', child: Text('Prendre les mesures')),
                    DropdownMenuItem<String>(
                        value: 'essayage', child: Text('Essayage')),
                    DropdownMenuItem<String>(
                        value: 'livraison', child: Text('Livraison')),
                    DropdownMenuItem<String>(
                        value: 'autre', child: Text('Autre')),
                  ],
                  onChanged: (String? v) {
                    if (v != null) setDlgState(() => reason = v);
                  },
                ),
                const SizedBox(height: CouturePalette.s3),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Jour et heure',
                      style: TextStyle(fontSize: 14, color: c.inkSoft)),
                  subtitle: Text(
                    '${DateFormatter.date(dt, locale: 'fr')} à '
                    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: c.ink),
                  ),
                  trailing: Icon(CoutureIcons.calendarBlank, color: c.iconInk),
                  onTap: () async {
                    final DateTime? pickedDate = await showDatePicker(
                      context: ctx,
                      initialDate: dt,
                      firstDate: DateTime(2026),
                      lastDate: DateTime(2030),
                    );
                    if (pickedDate != null && ctx.mounted) {
                      final TimeOfDay? pickedTime = await showTimePicker(
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
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(foregroundColor: c.inkSoft),
              child: const Text('Retour'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: c.iconInk),
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
                  await _loadAppointments();
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                      content: Text('Enregistrement impossible : $e'),
                      backgroundColor: CouturePalette.terracottaDeep,
                    ));
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

class _Day {
  _Day({required this.date, required this.items});

  final DateTime date;
  final List<Appointment> items;
}

class _DaySection extends StatelessWidget {
  const _DaySection({
    required this.day,
    required this.onEdit,
    required this.onDelete,
  });

  final _Day day;
  final Future<void> Function(Appointment) onEdit;
  final Future<void> Function(Appointment) onDelete;

  @override
  Widget build(BuildContext context) {
    final CoutureScheme c = CoutureScheme.of(context);
    final DateTime now = DateTime.now();
    final int days =
        day.date.difference(DateTime(now.year, now.month, now.day)).inDays;
    final bool late = days < 0;
    final bool pressing = days >= 0 && days <= 3;

    final String label = switch (days) {
      0 => 'Aujourd\'hui',
      1 => 'Demain',
      _ => DateFormatter.date(day.date, locale: 'fr'),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: CouturePalette.s2),
          child: Row(
            children: <Widget>[
              Text(
                label.toUpperCase(),
                style: CouturePalette.sectionLabel.copyWith(
                    color: late || pressing ? c.urgentText : c.inkFaint),
              ),
              const SizedBox(width: CouturePalette.s2),
              if (late)
                Text('EN RETARD',
                    style: CouturePalette.sectionLabel
                        .copyWith(color: c.urgentText)),
            ],
          ),
        ),
        for (final Appointment a in day.items)
          Padding(
            padding: const EdgeInsets.only(bottom: CouturePalette.s2),
            child: _AppointmentRow(
              appointment: a,
              pressing: pressing || late,
              onEdit: onEdit,
              onDelete: onDelete,
            ),
          ),
        const SizedBox(height: CouturePalette.s3),
      ],
    );
  }
}

class _AppointmentRow extends StatelessWidget {
  const _AppointmentRow({
    required this.appointment,
    required this.pressing,
    required this.onEdit,
    required this.onDelete,
  });

  final Appointment appointment;
  final bool pressing;
  final Future<void> Function(Appointment) onEdit;
  final Future<void> Function(Appointment) onDelete;

  static const Map<String, String> _reasons = <String, String>{
    'mesure': 'Prendre les mesures',
    'essayage': 'Essayage',
    'livraison': 'Livraison',
    'autre': 'Rendez-vous',
  };

  @override
  Widget build(BuildContext context) {
    final CoutureScheme c = CoutureScheme.of(context);
    final Appointment a = appointment;
    final bool isOrder = a.isFromOrder;
    final DateTime dt = (a.scheduledDate ?? DateTime.now()).toLocal();

    return CoutureCard(
      onTap: isOrder && a.orderId != null
          ? () => context.push('/admin/order/${a.orderId}')
          : null,
      padding: const EdgeInsets.fromLTRB(CouturePalette.s3, CouturePalette.s3,
          CouturePalette.s2, CouturePalette.s3),
      child: Row(
        children: <Widget>[
          CoutureWash(
            icon: isOrder ? CoutureIcons.truck : CoutureIcons.calendarBlank,
            tone: pressing ? CoutureTone.urgent : CoutureTone.normal,
            size: 40,
            iconSize: 20,
          ),
          const SizedBox(width: CouturePalette.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  a.clientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600, color: c.ink),
                ),
                const SizedBox(height: 1),
                Text(
                  isOrder
                      ? 'Livraison de la commande'
                      : _reasons[a.reason] ?? a.reason,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: c.inkSoft),
                ),
                // The hour only matters for a real appointment: an order's
                // delivery is a day, not a time slot.
                if (!isOrder) ...<Widget>[
                  const SizedBox(height: 1),
                  Text(
                    'à ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
                    '${a.clientPhone.isEmpty ? '' : ' · ${a.clientPhone}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: c.inkFaint),
                  ),
                ],
              ],
            ),
          ),
          if (isOrder)
            Padding(
              padding: const EdgeInsets.only(right: CouturePalette.s2),
              child: Icon(CoutureIcons.caretRight, size: 16, color: c.inkFaint),
            )
          else ...<Widget>[
            IconButton(
              tooltip: 'Changer',
              icon: Icon(CoutureIcons.pencil, size: 18, color: c.inkSoft),
              onPressed: () => onEdit(a),
            ),
            IconButton(
              tooltip: 'Enlever',
              icon: Icon(CoutureIcons.trash, size: 18, color: c.urgentText),
              onPressed: () => onDelete(a),
            ),
          ],
        ],
      ),
    );
  }
}
