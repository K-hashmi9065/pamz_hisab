import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pamz_khata/core/db/storage_config.dart';
import 'package:pamz_khata/core/db/hive/hive_registrar.dart';
import 'package:pamz_khata/feature/settings/presentation/screens/audit_log_screen.dart';

import '../../test_helpers/pump_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('audit_log_test_');
    Hive.init(tempDir.path);
    await HiveRegistrar.initialize(tempDir.path);
    AppStorageConfig.current = StorageType.hive;
  });

  tearDown(() async {
    AppStorageConfig.current = StorageType.sqlite;
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('AuditLogScreen displays empty state when no logs exist', (tester) async {
    tester.view.physicalSize = const Size(1194, 834);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await pumpApp(
      tester,
      const AuditLogScreen(),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('System Audit Logs'), findsOneWidget);
    expect(find.text('No audit records found'), findsOneWidget);
  });

  testWidgets('AuditLogScreen lists logs, filters by query, entity, action, and opens detail dialog', (tester) async {
    tester.view.physicalSize = const Size(1194, 834);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final box = HiveRegistrar.auditLogBox;
    final payload1 = jsonEncode({'amount': 500, 'name': 'John Doe'});
    final payload2 = jsonEncode({'rate': 2.5, 'type': 'interest'});

    await tester.runAsync(() async {
      await box.put('log1', {
        'id': 'audit_1',
        'entity_type': 'contacts',
        'entity_id': 'contact_123',
        'action': 'create',
        'changed_fields_json': payload1,
        'performed_at': DateTime(2026, 3, 1, 10, 30).toIso8601String(),
      });

      await box.put('log2', {
        'id': 'audit_2',
        'entity_type': 'direct_udhar_loans',
        'entity_id': 'loan_456',
        'action': 'update',
        'changed_fields_json': payload2,
        'performed_at': DateTime(2026, 3, 2, 14, 0).toIso8601String(),
      });

      await box.put('log3', {
        'id': 'audit_3',
        'entity_type': 'repayments',
        'entity_id': 'rep_789',
        'action': 'delete',
        'changed_fields_json': null,
        'performed_at': DateTime(2026, 3, 3, 16, 0).toIso8601String(),
      });
    });

    await pumpApp(
      tester,
      const AuditLogScreen(),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify all 3 items are rendered
    expect(find.text('contacts'), findsOneWidget);
    expect(find.text('direct_udhar_loans'), findsOneWidget);
    expect(find.text('repayments'), findsOneWidget);

    // Filter by entity: contacts
    final contactsChip = find.widgetWithText(FilterChip, 'Contacts');
    await tester.ensureVisible(contactsChip);
    await tester.tap(contactsChip);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('contacts'), findsOneWidget);
    expect(find.text('direct_udhar_loans'), findsNothing);
    expect(find.text('repayments'), findsNothing);

    // Reset entity filter to All Entities
    final allEntitiesChip = find.widgetWithText(FilterChip, 'All Entities');
    await tester.ensureVisible(allEntitiesChip);
    await tester.tap(allEntitiesChip);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Filter by action: Update
    final updateChip = find.widgetWithText(FilterChip, 'Update');
    await tester.ensureVisible(updateChip);
    await tester.tap(updateChip);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('direct_udhar_loans'), findsOneWidget);
    expect(find.text('contacts'), findsNothing);

    // Reset action filter to All Actions
    final allActionsChip = find.widgetWithText(FilterChip, 'All Actions');
    await tester.ensureVisible(allActionsChip);
    await tester.tap(allActionsChip);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Search query
    await tester.enterText(find.byType(TextField), 'John Doe');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('contacts'), findsOneWidget);
    expect(find.text('direct_udhar_loans'), findsNothing);

    // Tap on the item to open detail dialog
    await tester.tap(find.text('contacts'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Audit: contacts'), findsOneWidget);
    expect(find.text('contact_123'), findsOneWidget);
    expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('John Doe')), findsOneWidget);

    // Close detail dialog
    await tester.tap(find.text('Close'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Audit: contacts'), findsNothing);

    // Refresh button
    await tester.tap(find.byTooltip('Refresh Logs'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('contacts'), findsOneWidget);
  });
}
