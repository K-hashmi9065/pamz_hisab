import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pamz_khata/core/db/hive/hive_registrar.dart';
import 'package:pamz_khata/core/db/storage_config.dart';
import 'package:pamz_khata/feature/notifications/data/models/notification_template_model.dart';
import 'package:pamz_khata/feature/notifications/data/repositories/notification_template_repository.dart';
import 'package:pamz_khata/feature/notifications/presentation/providers/template_providers.dart';
import 'package:pamz_khata/feature/notifications/presentation/screens/notification_templates_screen.dart';
import 'package:pamz_khata/shared/widgets/app_button.dart';

import '../../test_helpers/mock_google_fonts.dart';
import '../../test_helpers/pump_app.dart';

void main() {
  setUpAll(() {
    setUpMockGoogleFonts();
  });

  group('Notification Template Extended Unit & Widget Tests', () {
    late Directory tempDir;
    late NotificationTemplateRepository repository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('notif_templates_ext_test_');
      await HiveRegistrar.initialize(tempDir.path);
      AppStorageConfig.current = StorageType.hive;
      repository = const NotificationTemplateRepository();
    });

    tearDown(() async {
      await Hive.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
      AppStorageConfig.current = StorageType.sqlite;
    });

    // ── Model & Interpolation Unit Tests ──

    test('1. NotificationTemplate copyWith, toMap, and fromMap', () {
      const template = NotificationTemplate(
        id: 'tpl_custom_1',
        name: 'Custom Loan Voucher',
        templateEnglish: 'Dear {contact_name}, your balance is {total_balance}.',
        templateHindi: 'नमस्ते {contact_name}, आपका बकाया {total_balance} है।',
        templateHinglish: 'Namaste {contact_name}, aapka balance {total_balance} hai.',
        supportedPlaceholders: ['{contact_name}', '{total_balance}'],
      );

      final map = template.toMap();
      expect(map['id'], 'tpl_custom_1');
      expect(map['name'], 'Custom Loan Voucher');
      expect(map['template_english'], contains('{total_balance}'));

      final fromMap = NotificationTemplate.fromMap(map);
      expect(fromMap.id, template.id);
      expect(fromMap.name, template.name);
      expect(fromMap.templateHindi, template.templateHindi);
      expect(fromMap.supportedPlaceholders.length, 2);

      final updated = template.copyWith(
        name: 'Updated Voucher',
        templateEnglish: 'New text for {contact_name}',
      );
      expect(updated.name, 'Updated Voucher');
      expect(updated.templateEnglish, 'New text for {contact_name}');
      expect(updated.templateHindi, template.templateHindi);
    });

    test('2. NotificationTemplateRepository.render placeholder interpolation', () {
      const raw = 'Hello {contact_name}, you paid {amount} on {date}. Remaining: {remaining_balance}.';
      final rendered = NotificationTemplateRepository.render(raw, {
        '{contact_name}': 'Zafar Iqbal',
        '{amount}': '₹12,000',
        '{date}': '18-Sep-2026',
        '{remaining_balance}': '₹3,000',
      });

      expect(rendered, 'Hello Zafar Iqbal, you paid ₹12,000 on 18-Sep-2026. Remaining: ₹3,000.');
    });

    // ── Isolated Repository Persistence Tests ──

    test('3. Repository seeds defaults, saves modifications, and fetches templates', () async {
      final templates = await repository.getTemplates();
      expect(templates.length, greaterThanOrEqualTo(3));
      expect(templates.any((t) => t.id == 'loan_voucher'), isTrue);

      final loanVoucher = templates.firstWhere((t) => t.id == 'loan_voucher');
      final modified = loanVoucher.copyWith(
        templateEnglish: 'Modified English Template for {contact_name}',
      );

      await repository.saveTemplate(modified);

      final reloaded = await repository.getTemplates();
      final fetched = reloaded.firstWhere((t) => t.id == 'loan_voucher');
      expect(fetched.templateEnglish, 'Modified English Template for {contact_name}');

      // Repository reset to defaults
      await repository.resetToDefaults();
      final resetList = await repository.getTemplates();
      final resetVoucher = resetList.firstWhere((t) => t.id == 'loan_voucher');
      expect(resetVoucher.templateEnglish, contains('*PAMZ Hisab - {title}*'));
    });

    // ── Safe Widget Tests ──

    testWidgets('4. Screen renders template selector and switching language tabs updates editor', (tester) async {
      tester.view.physicalSize = const Size(1194, 834);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpApp(
        tester,
        const NotificationTemplatesScreen(),
        overrides: [
          notificationTemplateRepositoryProvider.overrideWithValue(repository),
        ],
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Message & Share Templates'), findsOneWidget);
      expect(find.text('Select Message Template'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('हिंदी (Hindi)'), findsOneWidget);
      expect(find.text('Hinglish'), findsOneWidget);

      // Tap Hindi tab
      await tester.tap(find.text('हिंदी (Hindi)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('नमस्ते'), findsWidgets);

      // Tap Hinglish tab
      await tester.tap(find.text('Hinglish'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Namaste'), findsWidgets);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('5. Inserting placeholder tag chip and saving template updates state', (tester) async {
      tester.view.physicalSize = const Size(1194, 834);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpApp(
        tester,
        const NotificationTemplatesScreen(),
        overrides: [
          notificationTemplateRepositoryProvider.overrideWithValue(repository),
        ],
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap English tab
      await tester.tap(find.text('English'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Find {contact_name} chip and tap it to insert
      final tagChip = find.text('{contact_name}').first;
      await tester.tap(tagChip);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Save Template button
      final saveBtn = find.widgetWithText(AppButton, 'Save Template');
      await tester.ensureVisible(saveBtn);

      late NotificationTemplate updatedTemplate;
      await tester.runAsync(() async {
        await tester.tap(saveBtn);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        updatedTemplate = await repository.getTemplate('loan_voucher');
      });

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));

      expect(updatedTemplate.templateEnglish, contains('{contact_name}'));
      expect(find.byType(NotificationTemplatesScreen), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
