import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
              path: RoutePaths.contacts,
              builder: (_, __) => const Scaffold(body: Text('Contacts Content')),
            ),
            GoRoute(
              path: RoutePaths.utilize,
              builder: (_, __) => const Scaffold(body: Text('Utilize Content')),
            ),
            GoRoute(
              path: RoutePaths.reports,
              builder: (_, __) => const Scaffold(body: Text('Reports Content')),
            ),
            GoRoute(
              path: RoutePaths.userGuide,
              builder: (_, __) => const Scaffold(body: Text('User Guide Content')),
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

  group('AdaptiveShell Widget Tests (Fund Ledger 6-Tab Navigation)', () {
    testWidgets('1. Compact layout (< tabletBreakpoint, >= 600): NavigationRail is collapsed without branding header', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);

      // Width below AppConstants.tabletBreakpoint (840.0) but >= 600
      const compactSize = Size(750, 800);
      await pumpAdaptiveApp(tester, viewportSize: compactSize);

      // NavigationRail is present
      final navRail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(navRail.extended, isFalse);

      // PAMZ Hisab expanded branding is NOT rendered
      expect(find.text('PAMZ Hisab'), findsNothing);

      // Active content is rendered
      expect(find.text('Dashboard Content'), findsOneWidget);

      // Icon destinations remain accessible (all 6 tabs)
      expect(find.byIcon(Icons.dashboard_rounded), findsOneWidget);
      expect(find.byIcon(Icons.contacts_rounded), findsOneWidget);
      expect(find.byIcon(Icons.shopping_bag_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bar_chart_rounded), findsOneWidget);
      expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);
      expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
    });

    testWidgets('2. Expanded layout (>= tabletBreakpoint): NavigationRail is extended and shows PAMZ Hisab branding and 6 tabs', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);

      // Width at/above AppConstants.tabletBreakpoint (840.0)
      const expandedSize = Size(1194, 834);
      await pumpAdaptiveApp(tester, viewportSize: expandedSize);

      // NavigationRail is extended
      final navRail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(navRail.extended, isTrue);

      // PAMZ Hisab branding text is shown in the sidebar
      expect(find.text('PAMZ Hisab'), findsOneWidget);

      // All 6 Navigation item labels are rendered
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Contacts'), findsOneWidget);
      expect(find.text('Utilize'), findsOneWidget);
      expect(find.text('Reports'), findsOneWidget);
      expect(find.text('User Guide'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      expect(find.text('Dashboard Content'), findsOneWidget);
    });

    testWidgets('3. Mobile layout (< 600): NavigationBar displays all 6 tabs', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);

      const mobileSize = Size(400, 800);
      await pumpAdaptiveApp(tester, viewportSize: mobileSize);

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Contacts'), findsOneWidget);
      expect(find.text('Utilize'), findsOneWidget);
      expect(find.text('Reports'), findsOneWidget);
      expect(find.text('User Guide'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('4. Tapping navigation destination updates router and displays targeted screen content', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);

      const expandedSize = Size(1194, 834);
      await pumpAdaptiveApp(tester, viewportSize: expandedSize);

      expect(find.text('Dashboard Content'), findsOneWidget);

      // Tap Contacts tab
      await tester.tap(find.text('Contacts'));
      await tester.pumpAndSettle();

      expect(find.text('Contacts Content'), findsOneWidget);
      expect(find.text('Dashboard Content'), findsNothing);

      // Tap Utilize tab
      await tester.tap(find.text('Utilize'));
      await tester.pumpAndSettle();

      expect(find.text('Utilize Content'), findsOneWidget);
      expect(find.text('Contacts Content'), findsNothing);

      // Tap Reports tab
      await tester.tap(find.text('Reports'));
      await tester.pumpAndSettle();

      expect(find.text('Reports Content'), findsOneWidget);

      // Tap User Guide tab
      await tester.tap(find.text('User Guide'));
      await tester.pumpAndSettle();

      expect(find.text('User Guide Content'), findsOneWidget);

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
