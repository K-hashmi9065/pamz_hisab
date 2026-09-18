import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Helper to pump any widget wrapped in ProviderScope + ScreenUtil + MaterialApp.
/// Use [overrides] to inject mock providers.
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: ScreenUtilInit(
        designSize: const Size(1194, 834),
        minTextAdapt: true,
        builder: (_, __) => MaterialApp(
          home: Scaffold(body: child),
          // Suppress debug banner in tests
          debugShowCheckedModeBanner: false,
        ),
      ),
    ),
  );
}

/// Helper to pump any widget inside GoRouter and MaterialApp.router with a nested route stack.
Future<void> pumpAppWithRouter(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
  String initialLocation = '/test',
}) async {
  final subPath = initialLocation.startsWith('/')
      ? initialLocation.substring(1)
      : initialLocation;

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: Text('Root')),
        routes: [
          GoRoute(
            path: subPath,
            builder: (_, __) => child,
          ),
        ],
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
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
}
