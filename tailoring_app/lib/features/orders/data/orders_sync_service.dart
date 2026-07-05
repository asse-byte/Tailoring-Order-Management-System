import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/connectivity_helper.dart';
import '../domain/entities/order.dart';
import 'orders_outbox.dart';
import 'orders_repository.dart';

/// App-singleton: drains the offline outbox when connectivity returns,
/// uploads any persisted images, and creates the Firestore order docs.
///
/// Exposes:
/// - [pendingCount] : ValueNotifier<int> for UI badges/banners.
/// - [syncing]      : ValueNotifier<bool>.
class OrdersSyncService {
  OrdersSyncService._();
  static final OrdersSyncService instance = OrdersSyncService._();

  final OrdersOutbox _outbox = OrdersOutbox();
  final OrdersRepository _repo = OrdersRepository();
  bool _initialised = false;

  final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);
  final ValueNotifier<bool> syncing = ValueNotifier<bool>(false);

  /// Call once after Firebase has been initialised.
  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;
    await _refreshCount();

    // Drain whenever we (re)gain connectivity.
    ConnectivityHelper.instance.online.addListener(_onOnlineChanged);
    if (ConnectivityHelper.instance.isOnline) {
      // Attempt initial drain on boot if already online.
      unawaited(drain());
    }
  }

  void _onOnlineChanged() {
    if (ConnectivityHelper.instance.isOnline) {
      unawaited(drain());
    }
  }

  Future<void> _refreshCount() async {
    try {
      pendingCount.value = await _outbox.count();
    } catch (_) {
      // ignore
    }
  }

  /// Returns the pending count for a single customer (used by the banner).
  Future<int> pendingCountFor(String customerId) =>
      _outbox.countForCustomer(customerId);

  /// Public entry point — safe to call any time. No-op if already syncing
  /// or offline.
  Future<void> drain() async {
    if (syncing.value) return;
    if (!ConnectivityHelper.instance.isOnline) return;

    syncing.value = true;
    try {
      final List<OutboxEntry> entries = await _outbox.all();
      for (final OutboxEntry entry in entries) {
        if (entry.attempts >= 5) {
          // Give up automatically — leave for manual retry later.
          continue;
        }
        try {
          await _process(entry);
          await _outbox.remove(entry.id);
        } catch (e) {
          await _outbox.markAttempt(entry.id, error: e.toString());
        }
      }
    } finally {
      syncing.value = false;
      await _refreshCount();
    }
  }

  Future<void> _process(OutboxEntry entry) async {
    // 1) Create the Firestore document first.
    final created = await _repo.createOrder(entry.order);

    // 2) Upload any persisted images and patch the doc.
    String? fabricUrl;
    String? styleUrl;
    if (entry.fabricPhotoPath != null) {
      fabricUrl = await _repo.uploadOrderImage(
        file: File(entry.fabricPhotoPath!),
        storageFolder: AppConstants.fabricPhotosPath,
        orderId: created.id,
      );
    }
    if (entry.stylePhotoPath != null) {
      styleUrl = await _repo.uploadOrderImage(
        file: File(entry.stylePhotoPath!),
        storageFolder: AppConstants.stylePhotosPath,
        orderId: created.id,
      );
    }
    if (fabricUrl != null || styleUrl != null) {
      await _repo.updateImageUrls(
        orderId: created.id,
        fabricUrl: fabricUrl,
        styleUrl: styleUrl,
      );
    }
  }

  /// Convenience that hides the outbox entirely from UI code.
  Future<void> queueOffline({
    required TailoringOrder order,
    File? fabricPhoto,
    File? stylePhoto,
  }) async {
    await _outbox.enqueue(
      order: order,
      fabricPhoto: fabricPhoto,
      stylePhoto: stylePhoto,
    );
    await _refreshCount();
  }
}
