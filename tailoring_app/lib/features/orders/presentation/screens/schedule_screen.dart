import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/orders_repository.dart';
import '../../domain/entities/order.dart';

/// Item 4 — production programme. Two views:
///   • Programme: a Monday→Sunday week, orders grouped by their planned day.
///   • File d'attente: orders not yet planned (assign a day here).
/// Both roles (operational scheduling, no financials shown beyond the order
/// price the client already knows).
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with SingleTickerProviderStateMixin {
  final OrdersRepository _repo = OrdersRepository();
  late final TabController _tabs = TabController(length: 2, vsync: this);

  DateTime _weekStart = _mondayOf(DateTime.now());
  List<TailoringOrder> _planned = <TailoringOrder>[];
  List<TailoringOrder> _queue = <TailoringOrder>[];
  bool _loading = true;
  String? _error;

  static const List<String> _dayNames = <String>[
    'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'
  ];

  static DateTime _mondayOf(DateTime d) =>
      DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

  static String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final DateTime weekEnd = _weekStart.add(const Duration(days: 6));
      final results = await Future.wait<List<TailoringOrder>>(<Future<List<TailoringOrder>>>[
        _repo.list(plannedFrom: _weekStart, plannedTo: weekEnd, limit: 300),
        _repo.list(unplanned: true, limit: 300),
      ]);
      if (!mounted) return;
      setState(() {
        _planned = results[0];
        _queue = results[1];
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _shiftWeek(int deltaDays) {
    setState(() => _weekStart = _weekStart.add(Duration(days: deltaDays)));
    _load();
  }

  Color _statusColor(String status) {
    switch (status) {
      case AppConstants.statusTermine:
        return AppColors.warning;
      case AppConstants.statusLivre:
        return AppColors.success;
      case AppConstants.statusEnAttente:
        return AppColors.textSecondary;
      default:
        return AppColors.primary;
    }
  }

  Future<void> _planOrder(TailoringOrder order, {DateTime? initial}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2026),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    try {
      await _repo.setPlan(order.id, picked);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('« ${order.clientName} » planifié le ${picked.day}/${picked.month}.'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erreur: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  Future<void> _unplanOrder(TailoringOrder order) async {
    try {
      await _repo.setPlan(order.id, null);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Remis dans la file d\'attente.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erreur: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  Widget _orderTile(TailoringOrder o, {required bool planned}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(Icons.checkroom_rounded, color: _statusColor(o.status)),
        title: Text(o.clientName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
            '${o.garmentType} · ${o.statusLabel}${o.clientPhone.isNotEmpty ? ' · ${o.clientPhone}' : ''}'),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'open') {
              context.push('/admin/order/${o.id}').then((_) => _load());
            } else if (v == 'replan') {
              _planOrder(o, initial: o.plannedDate);
            } else if (v == 'plan') {
              _planOrder(o);
            } else if (v == 'unplan') {
              _unplanOrder(o);
            }
          },
          itemBuilder: (_) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(value: 'open', child: Text('Ouvrir la commande')),
            if (planned)
              const PopupMenuItem<String>(value: 'replan', child: Text('Changer le jour'))
            else
              const PopupMenuItem<String>(value: 'plan', child: Text('Planifier')),
            if (planned)
              const PopupMenuItem<String>(value: 'unplan', child: Text('Retirer du programme')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final DateTime weekEnd = _weekStart.add(const Duration(days: 6));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Programme'),
        bottom: TabBar(
          controller: _tabs,
          tabs: <Widget>[
            const Tab(text: 'Programme'),
            Tab(text: 'File d\'attente (${_queue.length})'),
          ],
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Erreur: $_error'))
              : TabBarView(
                  controller: _tabs,
                  children: <Widget>[_buildWeek(weekEnd), _buildQueue()],
                ),
    );
  }

  Widget _buildWeek(DateTime weekEnd) {
    final Map<String, List<TailoringOrder>> byDay = <String, List<TailoringOrder>>{};
    for (final TailoringOrder o in _planned) {
      if (o.plannedDate == null) continue;
      byDay.putIfAbsent(_ymd(o.plannedDate!), () => <TailoringOrder>[]).add(o);
    }
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: () => _shiftWeek(-7),
            ),
            Expanded(
              child: Text(
                'Semaine du ${_weekStart.day}/${_weekStart.month} au ${weekEnd.day}/${weekEnd.month}/${weekEnd.year}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: () => _shiftWeek(7),
            ),
          ],
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
              itemCount: 7,
              itemBuilder: (context, i) {
                final DateTime day = _weekStart.add(Duration(days: i));
                final List<TailoringOrder> orders =
                    byDay[_ymd(day)] ?? const <TailoringOrder>[];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                      child: Row(
                        children: <Widget>[
                          Text('${_dayNames[i]} ${day.day}/${day.month}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('${orders.length}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary)),
                          ),
                        ],
                      ),
                    ),
                    if (orders.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 4),
                        child: Text('—',
                            style: TextStyle(color: AppColors.textSecondary)),
                      )
                    else
                      ...orders.map((o) => _orderTile(o, planned: true)),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQueue() {
    if (_queue.isEmpty) {
      return const Center(child: Text('Aucune commande en attente.'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        itemCount: _queue.length,
        itemBuilder: (context, i) => _orderTile(_queue[i], planned: false),
      ),
    );
  }
}
