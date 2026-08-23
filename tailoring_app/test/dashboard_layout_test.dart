import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tailoring_app/core/theme/couture_palette.dart';
import 'package:tailoring_app/features/auth/data/auth_repository.dart';
import 'package:tailoring_app/features/auth/domain/entities/app_user.dart';
import 'package:tailoring_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:tailoring_app/features/orders/presentation/screens/dashboard_screen.dart';
import 'package:tailoring_app/features/settings/data/settings_repository.dart';
import 'package:tailoring_app/features/settings/presentation/providers/shop_settings_provider.dart';

/// The home screen is where rule 1 is visible: the secretary must never be
/// offered a way into the shop's money. The API returns 403 and the router
/// bounces her, but a tile she can see and tap is still a bug — she would read
/// it as "the app is broken", and the next session might "fix" the guard
/// instead of the tile.
///
/// These tests pin the three manager-only destinations to the manager, and pin
/// the everyday destinations to both roles so a future redesign cannot quietly
/// take the till or the order list away from the person standing at the
/// counter.

class _OfflineAuthRepo extends AuthRepository {
  @override
  Future<AppUser?> restoreSession() async => null;
}

class _OfflineSettingsRepo extends SettingsRepository {
  _OfflineSettingsRepo({this.themeColor = '#1E2E52'});

  final String themeColor;

  @override
  Future<({String shopName, String? logoUrl, String promoGroupLink, String? themeColor})>
      publicSettings() async => (
            shopName: 'Rayan Couture',
            logoUrl: null,
            promoGroupLink: '',
            themeColor: themeColor,
          );
}

class _FakeAuth extends AuthProvider {
  _FakeAuth({required this.secretary}) : super(repository: _OfflineAuthRepo());

  final bool secretary;

  @override
  bool get isSecretary => secretary;

  @override
  bool get isAdmin => !secretary;

  @override
  AppUser? get user => AppUser(
        id: '1',
        name: secretary ? 'Awa' : 'Le Gérant',
        email: '',
        phone: '',
        role: secretary ? 'secretary' : 'admin',
      );
}

Future<void> _pumpDashboard(
  WidgetTester tester, {
  required bool secretary,
  // Tall by default so the whole screen is laid out at once: a ListView only
  // builds what is near the viewport, and a missing tile would otherwise look
  // like a permission decision rather than scrolling.
  Size size = const Size(390, 1600),
  Brightness brightness = Brightness.light,
  String themeColor = '#1E2E52',
}) {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  // A fresh key on every pump: without one, pumping a second tree of the same
  // shape reuses the element, and `create:` never runs again — the test would
  // keep the FIRST pump's providers and quietly assert nothing.
  return tester.pumpWidget(
    MultiProvider(
      key: ValueKey<String>('$secretary/$brightness/$themeColor/$size'),
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => _FakeAuth(secretary: secretary),
        ),
        ChangeNotifierProvider<ShopSettingsProvider>(
          create: (_) => ShopSettingsProvider(
              repository: _OfflineSettingsRepo(themeColor: themeColor)),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: const DashboardScreen(),
      ),
    ),
  );
}

void main() {
  const List<String> managerOnly = <String>[
    'Finances',
    'Rapports',
    'Grossistes',
  ];

  const List<String> everyday = <String>[
    'Vendre',
    'Commandes',
    'Tailleurs',
    'Les ventes',
    'Rendez-vous',
    'Mon Album',
  ];

  testWidgets('the manager is offered the money modules', (tester) async {
    await _pumpDashboard(tester, secretary: false);
    await tester.pump();

    for (final String label in managerOnly) {
      expect(find.text(label), findsOneWidget, reason: '$label manquant');
    }
  });

  testWidgets('the secretary is offered none of them', (tester) async {
    await _pumpDashboard(tester, secretary: true);
    await tester.pump();

    for (final String label in managerOnly) {
      expect(find.text(label), findsNothing,
          reason: '$label ne doit jamais être visible pour la secrétaire');
    }
  });

  // The phones in the shop are cheap and small. An overflow stripe across a
  // card is the sort of thing that only shows up on the device, after the
  // build has already been handed over.
  testWidgets('it lays out on a small phone without overflowing',
      (tester) async {
    await _pumpDashboard(tester, secretary: false, size: const Size(320, 568));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  // The app's default is ThemeMode.system, so a phone set to dark gets the dark
  // theme whether or not anyone chose it. The screen has to hold up there too.
  testWidgets('it renders under the dark theme', (tester) async {
    await _pumpDashboard(tester, secretary: false, brightness: Brightness.dark);
    await tester.pump();

    expect(tester.takeException(), isNull);
    for (final String label in <String>['Vendre', 'Finances']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  // Each shop picks its own band colour, and nothing stops one from choosing a
  // pale gold. The greeting must not become white-on-cream because of it.
  testWidgets('the greeting follows the shop colour, not indigo',
      (tester) async {
    Color greeting() =>
        tester.widget<Text>(find.text('Bonjour, Le Gérant')).style!.color!;

    await _pumpDashboard(tester, secretary: false);
    await tester.pumpAndSettle();
    expect(greeting(), CouturePalette.onBand,
        reason: 'white on a dark indigo band');

    await _pumpDashboard(tester, secretary: false, themeColor: '#F2D8A7');
    await tester.pumpAndSettle();
    expect(greeting(), CouturePalette.ink,
        reason: 'ink on a pale gold band — white would be unreadable');
  });

  testWidgets('both roles keep the counter work', (tester) async {
    for (final bool secretary in <bool>[false, true]) {
      await _pumpDashboard(tester, secretary: secretary);
      await tester.pump();

      for (final String label in everyday) {
        expect(find.text(label), findsOneWidget,
            reason: '$label manquant (secrétaire: $secretary)');
      }
    }
  });
}
