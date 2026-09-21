import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pamz_khata/core/db/hive/hive_registrar.dart';
import 'package:pamz_khata/core/db/storage_config.dart';
import 'package:pamz_khata/feature/notifications/presentation/screens/notification_templates_screen.dart';
import 'package:pamz_khata/feature/settings/presentation/screens/audit_log_screen.dart';
import 'package:pamz_khata/feature/settings/presentation/screens/category_config_screen.dart';
import 'package:pamz_khata/feature/settings/presentation/screens/payment_modes_screen.dart';
import 'package:pamz_khata/feature/settings/presentation/screens/settings_screen.dart';

import '../../test_helpers/pump_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('settings_screen_test_');
    await HiveRegistrar.initialize(tempDir.path);
    AppStorageConfig.current = StorageType.hive;
  });

  tearDownAll(() {
    AppStorageConfig.current = StorageType.sqlite;
  });

  testWidgets('SettingsScreen theme picker switches theme modes', (tester) async {
    tester.view.physicalSize = const Size(1194, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await pumpApp(
      tester,
      const SettingsScreen(),
    );
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Theme Mode'), findsOneWidget);

    // Tap theme mode tile
    await tester.tap(find.text('Theme Mode'));
    await tester.pumpAndSettle();

    expect(find.text('Choose Theme'), findsOneWidget);
    expect(find.text('Dark Mode'), findsOneWidget);
    expect(find.text('Light Mode'), findsWidgets);
    expect(find.text('System Default'), findsOneWidget);

    // Select Dark Mode
    await tester.tap(find.text('Dark Mode').last);
    await tester.pumpAndSettle();

    expect(find.text('Choose Theme'), findsNothing);
    expect(find.text('Dark Mode'), findsOneWidget);

    // Open again and select Light Mode
    await tester.tap(find.text('Theme Mode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Light Mode').last);
    await tester.pumpAndSettle();

    expect(find.text('Light Mode'), findsOneWidget);

    // Open and cancel
    await tester.tap(find.text('Theme Mode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('SettingsScreen currency and numbering picker updates settings', (tester) async {
    tester.view.physicalSize = const Size(1194, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await pumpApp(
      tester,
      const SettingsScreen(),
    );
    await tester.pumpAndSettle();

    // Tap Currency & Numbering
    await tester.tap(find.text('Currency & Numbering'));
    await tester.pumpAndSettle();

    expect(find.text('Currency Symbol'), findsOneWidget);
    expect(find.text('\$'), findsOneWidget);

    // Select $ currency chip
    await tester.tap(find.text('\$'));
    await tester.pumpAndSettle();

    // Open dialog again to test Numbering format
    await tester.tap(find.text('Currency & Numbering'));
    await tester.pumpAndSettle();

    expect(find.text('Standard (Millions & Billions)'), findsOneWidget);
    await tester.tap(find.text('Standard (Millions & Billions)'));
    await tester.pumpAndSettle();
  });

  testWidgets('SettingsScreen fiscal year picker updates start month', (tester) async {
    tester.view.physicalSize = const Size(1194, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await pumpApp(
      tester,
      const SettingsScreen(),
    );
    await tester.pumpAndSettle();

    // Tap Fiscal Year Start
    await tester.tap(find.text('Fiscal Year Start'));
    await tester.pumpAndSettle();

    expect(find.text('Fiscal Year Start Month'), findsOneWidget);
    expect(find.text('January 1'), findsOneWidget);

    // Tap January 1
    await tester.tap(find.text('January 1'));
    await tester.pumpAndSettle();

    // Open and select July 1
    await tester.tap(find.text('Fiscal Year Start'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('July 1'));
    await tester.pumpAndSettle();

    // Open and Cancel
    await tester.tap(find.text('Fiscal Year Start'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('SettingsScreen GST dialog toggles and selects rates', (tester) async {
    tester.view.physicalSize = const Size(1194, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await pumpApp(
      tester,
      const SettingsScreen(),
    );
    await tester.pumpAndSettle();

    // Tap GST Settings
    await tester.tap(find.text('GST Settings'));
    await tester.pumpAndSettle();

    expect(find.text('GST Configuration'), findsOneWidget);
    expect(find.text('Enable GST on Invoices'), findsOneWidget);

    // Toggle switch on
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(find.text('Default GST Rate'), findsOneWidget);
    expect(find.text('18%'), findsOneWidget);

    // Select 12%
    await tester.tap(find.text('12%'));
    await tester.pumpAndSettle();

    // Tap Save
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('GST Configuration'), findsNothing);
    expect(find.text('Enabled · 12% default rate'), findsOneWidget);
  });

  testWidgets('SettingsScreen biometric switch toggles', (tester) async {
    tester.view.physicalSize = const Size(1194, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await pumpApp(
      tester,
      const SettingsScreen(),
    );
    await tester.pumpAndSettle();

    final biometricSwitch = find.byType(Switch).first;
    await tester.tap(biometricSwitch);
    await tester.pumpAndSettle();
  });

  testWidgets('SettingsScreen navigates to CategoryConfigScreen', (tester) async {
    tester.view.physicalSize = const Size(1194, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await pumpApp(
      tester,
      const SettingsScreen(),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Categories'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CategoryConfigScreen), findsOneWidget);
  });

  testWidgets('SettingsScreen navigates to PaymentModesScreen', (tester) async {
    tester.view.physicalSize = const Size(1194, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await pumpApp(
      tester,
      const SettingsScreen(),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Payment Modes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(PaymentModesScreen), findsOneWidget);
  });

  testWidgets('SettingsScreen navigates to NotificationTemplatesScreen', (tester) async {
    tester.view.physicalSize = const Size(1194, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await pumpApp(
      tester,
      const SettingsScreen(),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Message Templates'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(NotificationTemplatesScreen), findsOneWidget);
  });

  testWidgets('SettingsScreen navigates to AuditLogScreen', (tester) async {
    tester.view.physicalSize = const Size(1194, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await pumpApp(
      tester,
      const SettingsScreen(),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Audit Logs'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AuditLogScreen), findsOneWidget);
  });
}
