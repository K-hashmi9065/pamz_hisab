import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../feature/analytics_reports/presentation/screens/analytics_screen.dart';
import '../feature/auth_lock/presentation/screens/app_lock_screen.dart';
import '../feature/contacts/presentation/screens/contact_detail_screen.dart';
import '../feature/contacts/presentation/screens/contact_list_screen.dart';
import '../feature/dashboard/presentation/screens/dashboard_screen.dart';
import '../feature/family_finance/presentation/screens/budget_screen.dart';
import '../feature/family_finance/presentation/screens/family_finance_screen.dart';
import '../feature/notifications/presentation/screens/notification_templates_screen.dart';
import '../feature/settings/presentation/screens/audit_log_screen.dart';
import '../feature/settings/presentation/screens/category_config_screen.dart';
import '../feature/settings/presentation/screens/payment_modes_screen.dart';
import '../feature/settings/presentation/screens/settings_screen.dart';
import '../feature/user_guide/presentation/screens/user_guide_screen.dart';
import 'adaptive_shell.dart';
import 'route_names.dart';
import 'route_paths.dart';

/// Centralised GoRouter provider with session lock guard.
final appRouterProvider = Provider<GoRouter>((ref) {
  final isUnlocked = ref.watch(appLockProvider.select((s) => s.isUnlocked));

  final routerListenable = ValueNotifier<bool>(isUnlocked);
  ref.listen<bool>(appLockProvider.select((s) => s.isUnlocked), (_, next) {
    routerListenable.value = next;
  });

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
    // Temporary web bypass for manual browser testing.
    initialLocation: kIsWeb ? RoutePaths.dashboard : RoutePaths.lock,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      // Temporary web bypass for manual browser testing.
      if (kIsWeb) {
        return null;
      }

      final location = state.matchedLocation;
      final isLockRoute = location == RoutePaths.lock;
      final isUnlocked = isUnlockedGetter();

      if (!isUnlocked) {
        // If locked and trying to access any route other than /lock, redirect to /lock
        return isLockRoute ? null : RoutePaths.lock;
      }

      // If unlocked and on /lock, redirect to dashboard
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

    // ─── Main Shell (with AdaptiveShell sidebar) ─
    ShellRoute(
      builder: (context, state, child) => AdaptiveShell(child: child),
      routes: [
        GoRoute(
          path: RoutePaths.dashboard,
          name: RouteNames.dashboard,
          builder: (_, __) => const DashboardScreen(),
        ),

        GoRoute(
          path: RoutePaths.udharList,
          name: RouteNames.udharList,
          builder: (_, __) => const ContactListScreen(),
          routes: [
            GoRoute(
              path: RoutePaths.contactLedger, // 'contact/:contactId'
              name: RouteNames.contactLedger,
              builder: (_, state) {
                final contactId = state.pathParameters['contactId']!;
                return ContactDetailScreen(contactId: contactId);
              },
            ),
            GoRoute(
              path: RoutePaths.directUdharNew, // 'direct/new'
              name: RouteNames.directUdharNew,
              builder: (_, __) => const _DirectUdharNewPlaceholder(),
            ),
          ],
        ),

        GoRoute(
          path: RoutePaths.familyFinance,
          name: RouteNames.familyFinance,
          builder: (_, __) => const FamilyFinanceScreen(),
          routes: [
            GoRoute(
              path: RoutePaths.budget,
              name: RouteNames.budget,
              builder: (_, __) => const BudgetScreen(),
            ),
          ],
        ),


        GoRoute(
          path: RoutePaths.reports,
          name: RouteNames.reports,
          builder: (_, __) => const AnalyticsScreen(),
        ),

        GoRoute(
          path: RoutePaths.userGuide,
          name: RouteNames.userGuide,
          builder: (_, __) => const UserGuideScreen(),
        ),

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
              path: RoutePaths.notificationTemplates,
              name: RouteNames.notificationTemplates,
              builder: (_, __) => const NotificationTemplatesScreen(),
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

// ── Placeholder widgets for routes not yet implemented ────────────────────

class _DirectUdharNewPlaceholder extends StatelessWidget {
  const _DirectUdharNewPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Direct Udhar')),
      body: const Center(child: Text('Direct Udhar form — coming soon')),
    );
  }
}
