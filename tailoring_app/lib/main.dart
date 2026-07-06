import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/localization/app_localizations.dart';
import 'core/localization/language_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/clients/presentation/providers/clients_provider.dart';
import 'features/orders/presentation/providers/admin_orders_provider.dart';
import 'features/products/presentation/providers/products_provider.dart';
import 'features/settings/presentation/providers/shop_settings_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations(
    <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ],
  );

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
        ChangeNotifierProvider<ShopSettingsProvider>(
            create: (_) => ShopSettingsProvider()),
        ChangeNotifierProvider<AdminOrdersProvider>(
            create: (_) => AdminOrdersProvider()),
        ChangeNotifierProvider<ClientsProvider>(
            create: (_) => ClientsProvider()),
        ChangeNotifierProvider<ProductsProvider>(
            create: (_) => ProductsProvider()),
      ],
      child: Builder(
        builder: (context) {
          final AuthProvider auth = context.watch<AuthProvider>();
          final LanguageProvider lang = context.watch<LanguageProvider>();
          final String shopName =
              context.watch<ShopSettingsProvider>().shopName;

          final router = AppRouter.create(auth: auth);
          return MaterialApp.router(
            title: shopName,
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
            // Français uniquement pour l'instant; la structure i18n
            // (AppLocalizations) est prête pour d'autres langues.
            supportedLocales: const [Locale('fr')],
          );
        },
      ),
    );
  }
}
