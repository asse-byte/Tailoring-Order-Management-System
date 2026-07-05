import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/change_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/customers/presentation/screens/admin_customer_detail_screen.dart';
import '../../features/customers/presentation/screens/admin_customers_screen.dart';
import '../../features/notifications/presentation/screens/admin_broadcast_screen.dart';
import '../../features/orders/presentation/screens/admin_order_detail_screen.dart';
import '../../features/orders/presentation/screens/admin_orders_list_screen.dart';
import '../../features/orders/presentation/screens/admin_settings_screen.dart';
import '../../features/orders/presentation/screens/admin_shell.dart';
import '../../features/orders/presentation/screens/walk_in_order_screen.dart';
import '../../features/reports/presentation/screens/admin_reports_screen.dart';
import '../../features/products/presentation/screens/products_screen.dart';
import '../../features/staff/presentation/screens/staff_screen.dart';
import '../../features/finance/presentation/screens/finance_screen.dart';
import '../../features/ready_to_wear/presentation/screens/ready_to_wear_screen.dart';
import '../../features/appointments/presentation/screens/appointments_screen.dart';
import '../../features/orders/presentation/screens/history_orders_screen.dart';

/// Wraps a [Listenable] so GoRouter can refresh on auth changes.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Listenable listenable) {
    listenable.addListener(notifyListeners);
  }
}

class AppRouter {
  AppRouter._();

  static GoRouter create({required AuthProvider auth}) {
    return GoRouter(
      initialLocation: '/',
      refreshListenable: _AuthRefresh(auth),
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (_, __) => const SplashScreen(),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (_, __) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (_, __) => const LoginScreen(),
        ),
        GoRoute(
          path: '/admin',
          builder: (_, __) => const AdminShell(),
          routes: <RouteBase>[
            GoRoute(
              path: 'order/:id',
              builder: (_, state) =>
                  AdminOrderDetailScreen(orderId: state.pathParameters['id']!),
            ),
            GoRoute(
              path: 'walk-in',
              builder: (_, __) => const WalkInOrderScreen(),
            ),
            GoRoute(
              path: 'customer/:id',
              builder: (_, state) => AdminCustomerDetailScreen(
                customerId: state.pathParameters['id']!,
              ),
            ),
            GoRoute(
              path: 'broadcast',
              builder: (_, __) => const AdminBroadcastScreen(),
            ),
            GoRoute(
              path: 'reports',
              builder: (_, __) => const AdminReportsScreen(),
            ),
            GoRoute(
              path: 'change-password',
              builder: (_, __) => const ChangePasswordScreen(),
            ),
            GoRoute(
              path: 'customers',
              builder: (_, __) => const AdminCustomersScreen(),
            ),
            GoRoute(
              path: 'orders',
              builder: (_, __) => const AdminOrdersListScreen(),
            ),
            GoRoute(
              path: 'settings',
              builder: (_, __) => const AdminSettingsScreen(),
            ),
            GoRoute(
              path: 'products',
              builder: (_, __) => const ProductsScreen(),
            ),
            GoRoute(
              path: 'staff',
              builder: (_, __) => const StaffScreen(),
            ),
            GoRoute(
              path: 'finance',
              builder: (_, __) => const FinanceScreen(),
            ),
            GoRoute(
              path: 'ready-to-wear',
              builder: (_, __) => const ReadyToWearScreen(),
            ),
            GoRoute(
              path: 'appointments',
              builder: (_, __) => const AppointmentsScreen(),
            ),
            GoRoute(
              path: 'history',
              builder: (_, __) => const HistoryOrdersScreen(),
            ),
          ],
        ),
      ],
      redirect: (context, state) async {
        // While auth is still initialising, keep the splash visible.
        if (auth.status == AuthStatus.uninitialized) {
          return state.matchedLocation == '/' ? null : '/';
        }

        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final bool onboardingDone =
            prefs.getBool(AppConstants.prefsKeyOnboardingDone) ?? false;

        final String loc = state.matchedLocation;
        final bool isAuthRoute = loc == '/login' || loc == '/onboarding';

        // Unauthenticated flow ----------------------------------------------
        if (auth.status == AuthStatus.unauthenticated) {
          if (!onboardingDone && loc != '/onboarding') return '/onboarding';
          if (loc == '/' || loc == '/admin') return '/login';
          // Allow auth screens.
          return isAuthRoute ? null : '/login';
        }

        // Authenticated flow ------------------------------------------------
        // The shop has exactly two operating roles (admin + secretary); any
        // other account (e.g. a stale legacy one) is signed out immediately.
        final bool isStaff = auth.isAdmin || auth.isSecretary;
        if (!isStaff) {
          auth.signOut();
          return '/login';
        }
        if (isAuthRoute || loc == '/') return '/admin';

        return null;
      },
    );
  }
}
