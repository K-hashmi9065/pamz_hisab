import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pamz_khata/shared/widgets/app_bar_widgets.dart';
import 'package:pamz_khata/shared/widgets/app_states.dart';

Widget _wrap(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(375, 812),
    builder: (_, __) => MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  // ─── AppLoader ─────────────────────────────────────────────────────────────

  group('AppLoader widget tests', () {
    testWidgets('renders CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(_wrap(const AppLoader()));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows message when provided', (tester) async {
      await tester.pumpWidget(_wrap(const AppLoader(message: 'Loading data...')));
      expect(find.text('Loading data...'), findsOneWidget);
    });

    testWidgets('no message shown when null', (tester) async {
      await tester.pumpWidget(_wrap(const AppLoader()));
      expect(find.byType(Text), findsNothing);
    });
  });

  // ─── AppEmptyState ─────────────────────────────────────────────────────────

  group('AppEmptyState widget tests', () {
    testWidgets('renders title only', (tester) async {
      await tester.pumpWidget(_wrap(const AppEmptyState(title: 'No Items')));
      expect(find.text('No Items'), findsOneWidget);
    });

    testWidgets('renders title and subtitle', (tester) async {
      await tester.pumpWidget(_wrap(
        const AppEmptyState(title: 'Empty', subtitle: 'Add items to get started'),
      ));
      expect(find.text('Empty'), findsOneWidget);
      expect(find.text('Add items to get started'), findsOneWidget);
    });

    testWidgets('shows action button when actionLabel and onAction are provided', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(_wrap(
        AppEmptyState(
          title: 'No Contacts',
          actionLabel: 'Add Contact',
          onAction: () => tapped = true,
        ),
      ));
      expect(find.text('Add Contact'), findsOneWidget);
      await tester.tap(find.text('Add Contact'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('does NOT show action button when onAction is null', (tester) async {
      await tester.pumpWidget(_wrap(
        const AppEmptyState(title: 'Empty', actionLabel: 'Add'),
      ));
      // AppButton should not be present without onAction
      expect(find.text('Add'), findsNothing);
    });

    testWidgets('uses custom icon when provided', (tester) async {
      await tester.pumpWidget(_wrap(
        const AppEmptyState(title: 'No Files', icon: Icons.folder_open),
      ));
      expect(find.byIcon(Icons.folder_open), findsOneWidget);
    });

    testWidgets('uses default inbox icon when icon is null', (tester) async {
      await tester.pumpWidget(_wrap(const AppEmptyState(title: 'Empty')));
      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    });
  });

  // ─── AppErrorView ──────────────────────────────────────────────────────────

  group('AppErrorView widget tests', () {
    testWidgets('renders error message', (tester) async {
      await tester.pumpWidget(_wrap(
        const AppErrorView(message: 'Network error occurred'),
      ));
      expect(find.text('Network error occurred'), findsOneWidget);
      expect(find.text('Something went wrong'), findsOneWidget);
    });

    testWidgets('renders Retry button when onRetry is provided', (tester) async {
      bool retried = false;
      await tester.pumpWidget(_wrap(
        AppErrorView(
          message: 'Failed to load',
          onRetry: () => retried = true,
        ),
      ));
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(retried, isTrue);
    });

    testWidgets('does NOT render Retry button when onRetry is null', (tester) async {
      await tester.pumpWidget(_wrap(
        const AppErrorView(message: 'No retry available'),
      ));
      expect(find.text('Retry'), findsNothing);
    });
  });

  // ─── AppSnackbar ───────────────────────────────────────────────────────────

  group('AppSnackbar widget tests', () {
    testWidgets('showSuccess displays message', (tester) async {
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, __) => MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => AppSnackbar.showSuccess(ctx, 'Saved successfully'),
                  child: const Text('Show'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pump();
      expect(find.text('Saved successfully'), findsOneWidget);
    });

    testWidgets('showError displays error message', (tester) async {
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, __) => MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => AppSnackbar.showError(ctx, 'Operation failed'),
                  child: const Text('Show Error'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Show Error'));
      await tester.pump();
      expect(find.text('Operation failed'), findsOneWidget);
    });

    testWidgets('showInfo displays info message', (tester) async {
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, __) => MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => AppSnackbar.showInfo(ctx, 'Info message here'),
                  child: const Text('Show Info'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Show Info'));
      await tester.pump();
      expect(find.text('Info message here'), findsOneWidget);
    });
  });

  // ─── CustomAppBar ──────────────────────────────────────────────────────────

  group('CustomAppBar widget tests', () {
    testWidgets('renders title', (tester) async {
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, __) => const MaterialApp(
            home: Scaffold(appBar: CustomAppBar(title: 'My Screen')),
          ),
        ),
      );
      expect(find.text('My Screen'), findsOneWidget);
    });

    testWidgets('renders subtitle when provided', (tester) async {
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, __) => const MaterialApp(
            home: Scaffold(
              appBar: CustomAppBar(title: 'Main', subtitle: 'Subtitle here'),
            ),
          ),
        ),
      );
      expect(find.text('Main'), findsOneWidget);
      expect(find.text('Subtitle here'), findsOneWidget);
    });

    testWidgets('renders actions when provided', (tester) async {
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, __) => MaterialApp(
            home: Scaffold(
              appBar: CustomAppBar(
                title: 'Screen',
                actions: [IconButton(key: const Key('action1'), icon: const Icon(Icons.add), onPressed: () {})],
              ),
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('action1')), findsOneWidget);
    });

    testWidgets('preferredSize height matches kToolbarHeight with no subtitle/bottom', (tester) async {
      const appBar = CustomAppBar(title: 'Test');
      expect(appBar.preferredSize.height, kToolbarHeight);
    });
  });
}
