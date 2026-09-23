import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../feature/auth_lock/presentation/screens/app_lock_screen.dart';
import '../feature/dashboard/presentation/screens/dashboard_screen.dart';
import '../feature/family_utilize/presentation/screens/family_utilize_screen.dart';
import '../feature/fund_ledger/presentation/screens/fl_contact_detail_screen.dart';
import '../feature/fund_ledger/presentation/screens/fl_contacts_screen.dart';
import '../feature/fund_ledger/presentation/screens/fl_reports_screen.dart';
import '../feature/fund_ledger/presentation/screens/fl_user_guide_screen.dart';
import '../feature/settings/presentation/screens/audit_log_screen.dart';
import '../feature/settings/presentation/screens/category_config_screen.dart';
import '../feature/settings/presentation/screens/payment_modes_screen.dart';
import '../feature/settings/presentation/screens/settings_screen.dart';
import 'adaptive_shell.dart';
import 'route_names.dart';
import 'route_paths.dart';

/// Centralised GoRouter provider with session lock guard.
final appRouterProvider = Provider<GoRouter>((ref) {
  final routerListenable = ValueNotifier<bool>(
    ref.read(appLockProvider).isUnlocked,
  );

  ref.listen<bool>(appLockProvider.select((s) => s.isUnlocked), (_, next) {
    routerListenable.value = next;
  });

  ref.onDispose(routerListenable.dispose);

  return _buildRouter(
    refreshListenable: routerListenable,
    isUnlockedGetter: () => ref.read(appLockProvider).isUnlocked,
  );
});

/// Default singleton for static access.
final appRouter = _buildRouter(
  isUnlockedGetter: () => false,
);

GoRouter _buildRouter({
  Listenable? refreshListenable,
  required bool Function() isUnlockedGetter,
}) {
  return GoRouter(
    initialLocation: kIsWeb ? RoutePaths.dashboard : RoutePaths.lock,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      if (kIsWeb) {
        return null;
      }

      final location = state.matchedLocation;
      final isLockRoute = location == RoutePaths.lock;
      final isUnlocked = isUnlockedGetter();

      if (!isUnlocked) {
        return isLockRoute ? null : RoutePaths.lock;
      }

      if (isLockRoute) {
        return RoutePaths.dashboard;
      }

      return null;
    },
    debugLogDiagnostics: kDebugMode,
    routes: [
      // ─── Biometric Lock Gate ────────────────────
      GoRoute(
        path: RoutePaths.lock,
        name: RouteNames.lock,
        builder: (_, __) => const AppLockScreen(),
      ),

      // ─── Main Shell (5 Core Tabs) ───────────────
      ShellRoute(
        builder: (context, state, child) => AdaptiveShell(child: child),
        routes: [
          // 1. Dashboard
          GoRoute(
            path: RoutePaths.dashboard,
            name: RouteNames.dashboard,
            builder: (_, __) => const DashboardScreen(),
          ),

          // 2. Contacts (Master + Detail)
          GoRoute(
            path: RoutePaths.contacts,
            name: RouteNames.flContacts,
            builder: (_, __) => const FLContactsScreen(),
            routes: [
              GoRoute(
                path: RoutePaths.contactDetail, // ':id'
                name: RouteNames.flContactDetail,
                builder: (_, state) {
                  final contactId = state.pathParameters['id']!;
                  return FLContactDetailScreen(contactId: contactId);
                },
              ),
            ],
          ),

          // 3. Utilize (Family / Personal)
          GoRoute(
            path: RoutePaths.utilize,
            name: RouteNames.utilize,
            builder: (_, __) => const FamilyUtilizeScreen(),
          ),

          // 4. Reports
          GoRoute(
            path: RoutePaths.reports,
            name: RouteNames.reports,
            builder: (_, __) => const FLReportsScreen(),
          ),

          // 4. User Guide
          GoRoute(
            path: RoutePaths.userGuide,
            name: RouteNames.userGuide,
            builder: (_, __) => const FLUserGuideScreen(),
          ),

          // 5. Settings
          GoRoute(
            path: RoutePaths.settings,
            name: RouteNames.settings,
            builder: (_, __) => const SettingsScreen(),
            routes: [
              GoRoute(
                path: RoutePaths.categoryConfig,
                name: RouteNames.categoryConfig,
                builder: (_, __) => const CategoryConfigScreen(),
              ),
              GoRoute(
                path: RoutePaths.paymentModes,
                name: RouteNames.paymentModes,
                builder: (_, __) => const PaymentModesScreen(),
              ),
              GoRoute(
                path: RoutePaths.auditLog,
                name: RouteNames.auditLog,
                builder: (_, __) => const AuditLogScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text(
          'Page not found: ${state.uri}',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    ),
  );
}
