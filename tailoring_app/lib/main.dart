import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/localization/app_localizations.dart';
import 'core/localization/language_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
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
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
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
      child: const _AppView(),
    );
  }
}

/// Holds the [GoRouter] so it is built exactly once. Rebuilding the router on
/// every provider change (e.g. when a screen loads settings) would reset the
/// navigation stack and silently drop the page just pushed. Auth changes are
/// handled by the router's own `refreshListenable`, not by re-creating it.
class _AppView extends StatefulWidget {
  const _AppView();

  @override
  State<_AppView> createState() => _AppViewState();
}

class _AppViewState extends State<_AppView> {
  late final _router = AppRouter.create(auth: context.read<AuthProvider>());

  @override
  Widget build(BuildContext context) {
    final LanguageProvider lang = context.watch<LanguageProvider>();
    final ShopSettingsProvider shop = context.watch<ShopSettingsProvider>();
    final ThemeProvider theme = context.watch<ThemeProvider>();
    final String shopName = shop.shopName;
    final Color brand = shop.themeColor;

    return MaterialApp.router(
      title: shopName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(brand: brand),
      darkTheme: AppTheme.dark(brand: brand),
      themeMode: theme.themeMode,
      routerConfig: _router,
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
  }
}
