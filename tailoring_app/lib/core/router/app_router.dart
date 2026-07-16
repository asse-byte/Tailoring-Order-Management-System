import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/change_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/clients/domain/client.dart';
import '../../features/clients/presentation/screens/client_detail_screen.dart';
import '../../features/clients/presentation/screens/client_form_screen.dart';
import '../../features/clients/presentation/screens/clients_list_screen.dart';
import '../../features/clients/presentation/screens/measurements_screen.dart';
import '../../features/orders/presentation/screens/admin_orders_list_screen.dart';
import '../../features/orders/presentation/screens/admin_settings_screen.dart';
import '../../features/orders/presentation/screens/admin_shell.dart';
import '../../features/orders/presentation/screens/history_orders_screen.dart';
import '../../features/orders/presentation/screens/order_detail_screen.dart';
import '../../features/orders/presentation/screens/schedule_screen.dart';
import '../../features/orders/presentation/screens/walk_in_order_screen.dart';
import '../../features/products/presentation/screens/products_screen.dart';
import '../../features/staff/presentation/screens/staff_screen.dart';
import '../../features/staff/presentation/screens/monthly_staff_screen.dart';
import '../../features/finance/presentation/screens/finance_screen.dart';
import '../../features/reports/presentation/screens/reports_screen.dart';
import '../../features/ready_to_wear/presentation/screens/ready_to_wear_screen.dart';
import '../../features/appointments/presentation/screens/appointments_screen.dart';

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
                  OrderDetailScreen(orderId: state.pathParameters['id']!),
            ),
            GoRoute(
              path: 'walk-in',
              builder: (_, __) => const WalkInOrderScreen(),
            ),
            GoRoute(
              path: 'clients/new',
              builder: (_, __) => const ClientFormScreen(),
            ),
            GoRoute(
              path: 'clients/:id/edit',
              builder: (_, state) =>
                  ClientFormScreen(client: state.extra as Client?),
            ),
            GoRoute(
              path: 'clients/:id/measurements/:type',
              builder: (_, state) {
                final Map<String, dynamic>? extra = state.extra as Map<String, dynamic>?;
                return MeasurementsScreen(
                  clientId: state.pathParameters['id']!,
                  garmentType:
                      Uri.decodeComponent(state.pathParameters['type']!),
                  initial: extra?['initial'] as Map<String, num>?,
                  suggestedFields: extra?['suggestedFields'] as List<String>?,
                );
              },
            ),
            GoRoute(
              path: 'clients/:id',
              builder: (_, state) => ClientDetailScreen(
                clientId: state.pathParameters['id']!,
              ),
            ),
            GoRoute(
              path: 'change-password',
              builder: (_, __) => const ChangePasswordScreen(),
            ),
            GoRoute(
              path: 'customers',
              builder: (_, __) => const ClientsListScreen(),
            ),
            GoRoute(
              path: 'orders',
              builder: (_, __) => const AdminOrdersListScreen(),
            ),
            GoRoute(
              path: 'schedule',
              builder: (_, __) => const ScheduleScreen(),
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
              path: 'monthly-staff',
              builder: (_, __) => const MonthlyStaffScreen(),
            ),
            GoRoute(
              path: 'finance',
              builder: (_, __) => const FinanceScreen(),
            ),
            GoRoute(
              path: 'reports',
              builder: (_, __) => const ReportsScreen(),
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
      redirect: (context, state) {
        // While auth is still initialising, keep the splash visible.
        if (auth.status == AuthStatus.uninitialized) {
          return state.matchedLocation == '/' ? null : '/';
        }

        final String loc = state.matchedLocation;

        // Unauthenticated flow ----------------------------------------------
        if (auth.status == AuthStatus.unauthenticated) {
          return loc == '/login' ? null : '/login';
        }

        // Authenticated flow ------------------------------------------------
        // The shop has exactly two operating roles (admin + secretary); any
        // other account (e.g. a stale legacy one) is signed out immediately.
        final bool isStaff = auth.isAdmin || auth.isSecretary;
        if (!isStaff) {
          auth.signOut();
          return '/login';
        }
        if (loc == '/login' || loc == '/') return '/admin';

        // Secretary cannot access financial/management routes — redirect to
        // home. (The server also returns 403 on the underlying endpoints; this
        // is defence-in-depth so a deep link never even renders the screen.)
        if (auth.isSecretary &&
            (loc == '/admin/finance' ||
                loc == '/admin/reports' ||
                loc == '/admin/staff-pay' ||
                loc == '/admin/monthly-staff' ||
                loc == '/admin/settings')) {
          return '/admin';
        }

        return null;
      },
    );
  }
}
