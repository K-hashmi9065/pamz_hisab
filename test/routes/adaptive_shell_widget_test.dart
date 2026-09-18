import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pamz_khata/core/constants/app_constants.dart';
import 'package:pamz_khata/routes/adaptive_shell.dart';
import 'package:pamz_khata/routes/route_paths.dart';

void main() {
  GoRouter createTestRouter({String initialLocation = RoutePaths.dashboard}) {
    return GoRouter(
      initialLocation: initialLocation,
      routes: [
        ShellRoute(
          builder: (context, state, child) => AdaptiveShell(child: child),
          routes: [
            GoRoute(
              path: RoutePaths.dashboard,
              builder: (_, __) => const Scaffold(body: Text('Dashboard Content')),
            ),
            GoRoute(
              path: RoutePaths.udharList,
              builder: (_, __) => const Scaffold(body: Text('Udhar Khata Content')),
            ),
            GoRoute(
              path: RoutePaths.familyFinance,
              builder: (_, __) => const Scaffold(body: Text('Family Finance Content')),
            ),
            GoRoute(
              path: RoutePaths.reports,
              builder: (_, __) => const Scaffold(body: Text('Reports Content')),
            ),
            GoRoute(
              path: RoutePaths.settings,
              builder: (_, __) => const Scaffold(body: Text('Settings Content')),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> pumpAdaptiveApp(
    WidgetTester tester, {
    required Size viewportSize,
    String initialLocation = RoutePaths.dashboard,
  }) async {
    tester.view.physicalSize = viewportSize;
    tester.view.devicePixelRatio = 1.0;

    final router = createTestRouter(initialLocation: initialLocation);

    await tester.pumpWidget(
      ProviderScope(
        child: ScreenUtilInit(
          designSize: const Size(1194, 834),
          minTextAdapt: true,
          builder: (_, __) => MaterialApp.router(
            routerConfig: router,
            debugShowCheckedModeBanner: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('AdaptiveShell Widget Tests (GAP-W02)', () {
    testWidgets('1. Compact layout (< tabletBreakpoint): NavigationRail is collapsed without branding header', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);

      // Width below AppConstants.tabletBreakpoint (1024.0)
      const compactSize = Size(AppConstants.tabletBreakpoint - 100, 800);
      await pumpAdaptiveApp(tester, viewportSize: compactSize);

      // NavigationRail is present
      final navRail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(navRail.extended, isFalse);

      // PAMZ Hisab expanded branding is NOT rendered
      expect(find.text('PAMZ Hisab'), findsNothing);

      // Active content is rendered
      expect(find.text('Dashboard Content'), findsOneWidget);

      // Icon destinations remain accessible
      expect(find.byIcon(Icons.dashboard_rounded), findsOneWidget);
      expect(find.byIcon(Icons.handshake_rounded), findsOneWidget);
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bar_chart_rounded), findsOneWidget);
      expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
    });

    testWidgets('2. Expanded layout (>= tabletBreakpoint): NavigationRail is extended and shows PAMZ Hisab branding', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);

      // Width at/above AppConstants.tabletBreakpoint (1024.0)
      const expandedSize = Size(AppConstants.tabletBreakpoint + 170, 834);
      await pumpAdaptiveApp(tester, viewportSize: expandedSize);

      // NavigationRail is extended
      final navRail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(navRail.extended, isTrue);

      // PAMZ Hisab branding text is shown in the sidebar
      expect(find.text('PAMZ Hisab'), findsOneWidget);

      // Navigation item labels are rendered
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Udhar Khata'), findsOneWidget);
      expect(find.text('Family'), findsOneWidget);
      expect(find.text('Reports'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      expect(find.text('Dashboard Content'), findsOneWidget);
    });

    testWidgets('3. Tapping navigation destination updates router and displays targeted screen content', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);

      const expandedSize = Size(1194, 834);
      await pumpAdaptiveApp(tester, viewportSize: expandedSize);

      expect(find.text('Dashboard Content'), findsOneWidget);

      // Tap Udhar Khata tab
      await tester.tap(find.text('Udhar Khata'));
      await tester.pumpAndSettle();

      expect(find.text('Udhar Khata Content'), findsOneWidget);
      expect(find.text('Dashboard Content'), findsNothing);

      // Tap Family tab
      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();

      expect(find.text('Family Finance Content'), findsOneWidget);

      // Tap Reports tab
      await tester.tap(find.text('Reports'));
      await tester.pumpAndSettle();

      expect(find.text('Reports Content'), findsOneWidget);

      // Tap Settings tab
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Settings Content'), findsOneWidget);

      // Navigate back to Dashboard
      await tester.tap(find.text('Dashboard'));
      await tester.pumpAndSettle();

      expect(find.text('Dashboard Content'), findsOneWidget);
    });
  });
}
