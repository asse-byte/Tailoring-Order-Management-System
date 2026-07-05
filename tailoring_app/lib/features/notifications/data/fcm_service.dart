import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/data/mock_database.dart';
import '../../auth/data/auth_repository.dart';
import '../../../firebase_options.dart';

/// Background-isolate FCM handler — must be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (MockDatabase.useMock) return;
  // Re-init Firebase in the background isolate.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Note: Android shows the heads-up automatically when the message
  // includes a `notification` payload. Nothing else required here.
}

/// Wraps Firebase Cloud Messaging + flutter_local_notifications.
///
/// Lifecycle:
/// 1. Call [FcmService.instance.init] once after Firebase has been
///    initialised (in main()).
/// 2. After sign-in, call [FcmService.instance.bindToUser(uid)] so we
///    can persist the device token onto the user's profile.
/// 3. After sign-out, call [FcmService.instance.unbindUser()].
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  FirebaseMessaging? _fmInstance;
  FirebaseMessaging get _fm => _fmInstance ??= FirebaseMessaging.instance;

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  final AuthRepository _authRepo = AuthRepository();

  // Surface taps from the system tray to the app (e.g. to deep-link to an order).
  final ValueNotifier<RemoteMessage?> tappedMessage =
      ValueNotifier<RemoteMessage?>(null);

  bool _initialised = false;
  String? _currentUid;
  StreamSubscription<String>? _tokenSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedSub;

  Future<void> init() async {
    if (MockDatabase.useMock) {
      _initialised = true;
      return;
    }
    if (_initialised) return;
    _initialised = true;

    // Local notifications setup (used to display foreground messages).
    const AndroidInitializationSettings android =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings ios = DarwinInitializationSettings();
    await _local.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _local.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        AppConstants.fcmChannelId,
        AppConstants.fcmChannelName,
        description: AppConstants.fcmChannelDescription,
        importance: Importance.high,
      ),
    );
    await androidPlugin?.requestNotificationsPermission();

    // Permission (iOS + Android 13+).
    await _fm.requestPermission(alert: true, badge: true, sound: true);

    // Foreground messages → show a heads-up via local notifications.
    _foregroundSub = FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // Tap on a message that was shown while the app was in the background
    // and the user opened it.
    _openedSub = FirebaseMessaging.onMessageOpenedApp.listen((m) {
      tappedMessage.value = m;
    });

    // Was the app launched from a terminated state by tapping a notification?
    final RemoteMessage? launch = await _fm.getInitialMessage();
    if (launch != null) tappedMessage.value = launch;
  }

  Future<void> bindToUser(String uid) async {
    if (MockDatabase.useMock) return;
    _currentUid = uid;
    try {
      final String? token = await _fm.getToken();
      if (token != null) {
        await _authRepo.updateFcmToken(uid, token);
      }
      _tokenSub?.cancel();
      _tokenSub = _fm.onTokenRefresh.listen((t) {
        if (_currentUid != null) {
          _authRepo.updateFcmToken(_currentUid!, t);
        }
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FCM token registration failed: $e');
      }
    }
  }

  Future<void> unbindUser() async {
    if (MockDatabase.useMock) return;
    _currentUid = null;
    await _tokenSub?.cancel();
    _tokenSub = null;
  }

  Future<void> _onForegroundMessage(RemoteMessage m) async {
    final RemoteNotification? n = m.notification;
    if (n == null) return;

    await _local.show(
      n.hashCode,
      n.title,
      n.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.fcmChannelId,
          AppConstants.fcmChannelName,
          channelDescription: AppConstants.fcmChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: m.data['orderId'] as String?,
    );
  }

  Future<void> dispose() async {
    await _foregroundSub?.cancel();
    await _openedSub?.cancel();
    await _tokenSub?.cancel();
  }
}
