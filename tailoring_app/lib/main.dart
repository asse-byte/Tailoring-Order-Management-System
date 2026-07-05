import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_strings.dart';
import 'core/data/mock_database.dart';
import 'core/localization/app_localizations.dart';
import 'core/localization/language_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/connectivity_helper.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/notifications/data/fcm_service.dart';
import 'features/orders/data/orders_sync_service.dart';
import 'features/orders/presentation/providers/admin_orders_provider.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations(
    <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ],
  );

  if (!MockDatabase.useMock) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      // FCM background handler must be registered before runApp().
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('Firebase initialization failed: $e');
    }
  }

  await ConnectivityHelper.instance.init();
  await FcmService.instance.init();
  await OrdersSyncService.instance.init();

  runApp(const TailoringApp());
}

class TailoringApp extends StatelessWidget {
  const TailoringApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProvider<LanguageProvider>(
            create: (_) => LanguageProvider()),
        ChangeNotifierProvider<AdminOrdersProvider>(
            create: (_) => AdminOrdersProvider()),
      ],
      child: Builder(
        builder: (context) {
          final AuthProvider auth = context.watch<AuthProvider>();
          final LanguageProvider lang = context.watch<LanguageProvider>();

          // Bind / unbind FCM token to the current user.
          if (auth.user != null) {
            FcmService.instance.bindToUser(auth.user!.id);
          } else {
            FcmService.instance.unbindUser();
          }

          final router = AppRouter.create(auth: auth);
          return MaterialApp.router(
            title: AppStrings.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: ThemeMode.system,
            routerConfig: router,
            locale: lang.locale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'),
              Locale('fr'),
            ],
          );
        },
      ),
    );
  }
}
