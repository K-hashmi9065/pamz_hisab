
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pamz_khata/core/db/hive/hive_registrar.dart';
import 'package:pamz_khata/feature/notifications/data/models/notification_template_model.dart';
import 'package:pamz_khata/feature/notifications/data/repositories/notification_template_repository.dart';
import 'package:pamz_khata/feature/notifications/presentation/providers/template_providers.dart';
import 'package:pamz_khata/feature/notifications/presentation/screens/notification_templates_screen.dart';
import 'package:pamz_khata/shared/widgets/app_button.dart';

import '../../test_helpers/mock_google_fonts.dart';
import '../../test_helpers/mocks.dart';
import '../../test_helpers/pump_app.dart';

void main() {
  setUpAll(() {
    setUpMockGoogleFonts();
  });

  group('Notification Template Unit & Widget Tests', () {
    late Directory tempDir;
    late NotificationTemplateRepository repository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hive_templates_test_');
      await HiveRegistrar.initialize(tempDir.path);
      repository = const NotificationTemplateRepository();
    });

    tearDown(() async {
      await Hive.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    // ── Unit Tests ──

    test('1. Model toMap and fromMap serialization roundtrip', () {
      const model = NotificationTemplate(
        id: 'test_template',
        name: 'Custom Alert',
        supportedPlaceholders: ['{name}', '{amount}'],
        templateEnglish: 'Hello {name}, amount: {amount}',
        templateHindi: 'नमस्ते {name}, राशि: {amount}',
        templateHinglish: 'Namaste {name}, amount: {amount}',
      );

      final map = model.toMap();
      final fromMap = NotificationTemplate.fromMap(map);

      expect(fromMap.id, 'test_template');
      expect(fromMap.name, 'Custom Alert');
      expect(fromMap.supportedPlaceholders, ['{name}', '{amount}']);
      expect(fromMap.templateEnglish, 'Hello {name}, amount: {amount}');
      expect(fromMap.templateHindi, 'नमस्ते {name}, राशि: {amount}');
      expect(fromMap.templateHinglish, 'Namaste {name}, amount: {amount}');
    });

    test('2. Repository getTemplates returns default templates on first access', () async {
      final templates = await repository.getTemplates();
      expect(templates.length, NotificationTemplateRepository.defaultTemplates.length);
      expect(templates.any((t) => t.id == 'loan_voucher'), isTrue);
      expect(templates.any((t) => t.id == 'statement_summary'), isTrue);
      expect(templates.any((t) => t.id == 'repayment_jama'), isTrue);
    });

    test('3. Repository saveTemplate updates template and getTemplate fetches it', () async {
      final template = await repository.getTemplate('loan_voucher');

      final updated = template.copyWith(templateEnglish: 'Custom Header\nDear {contact_name}');
      await repository.saveTemplate(updated);

      final after = await repository.getTemplate('loan_voucher');
      expect(after.templateEnglish, contains('Custom Header'));
    });

    test('4. Repository resetToDefaults restores original templates', () async {
      final template = await repository.getTemplate('loan_voucher');
      await repository.saveTemplate(template.copyWith(templateEnglish: 'Modified'));

      await repository.resetToDefaults();
      final after = await repository.getTemplate('loan_voucher');
      expect(after.templateEnglish, isNot(contains('Modified')));
    });

    test('5. NotificationTemplateRepository.render correctly replaces supported placeholder tags', () async {
      final template = await repository.getTemplate('loan_voucher');
      final message = NotificationTemplateRepository.render(
        template.templateEnglish,
        {
          '{title}': 'Udhar Receipt',
          '{contact_name}': 'Ramesh Kumar',
          '{amount}': '₹5,000',
          '{direction}': 'Lent',
          '{interest_info}': 'Interest-Free',
          '{date}': '17 Sep 2026',
          '{total_balance}': '₹5,000',
          '{memo_line}': 'For fertilizer',
        },
      );

      expect(message, contains('Ramesh Kumar'));
      expect(message, contains('₹5,000'));
      expect(message, contains('Udhar Receipt'));
      expect(message, isNot(contains('{contact_name}')));
    });

    // ── Widget Tests ──

    testWidgets('6. NotificationTemplatesScreen renders template selector and tab switcher', (tester) async {
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
      expect(find.text('Available Placeholders (Tap to insert)'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Save Template'), findsOneWidget);
      expect(find.byTooltip('Reset All to Defaults'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('7. Tab switching updates template language text and tag insertion works', (tester) async {
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

      // Switch to Hindi tab
      await tester.tap(find.text('हिंदी (Hindi)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('नमस्ते'), findsWidgets);

      // Switch to Hinglish tab
      await tester.tap(find.text('Hinglish'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Namaste'), findsWidgets);

      // Tap placeholder chip to insert tag
      final tagChip = find.text('{contact_name}').first;
      await tester.tap(tagChip);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Save
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

      // Settle frames across the UI update and animations
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));

      expect(updatedTemplate.templateHinglish, contains('{contact_name}'));
      expect(find.byType(NotificationTemplatesScreen), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('8. Reset defaults button opens confirmation dialog and restores default templates', (tester) async {
      tester.view.physicalSize = const Size(1194, 834);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final initialTemplate = NotificationTemplateRepository.defaultTemplates
          .firstWhere((t) => t.id == 'loan_voucher')
          .copyWith(templateEnglish: 'CUSTOM MODIFIED TEMPLATE');
      final fakeRepo = FakeNotificationTemplateRepository(
        initialTemplates: [
          initialTemplate,
          ...NotificationTemplateRepository.defaultTemplates.where((t) => t.id != 'loan_voucher'),
        ],
      );

      await pumpApp(
        tester,
        const NotificationTemplatesScreen(),
        overrides: [
          notificationTemplateRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Reset to Defaults in AppBar
      final resetBtn = find.byTooltip('Reset All to Defaults');
      await tester.tap(resetBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Reset All Templates'), findsOneWidget);

      // Confirm reset dialog
      final confirmBtn = find.widgetWithText(AppButton, 'Reset');
      await tester.tap(confirmBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final expectedDefault = NotificationTemplateRepository.defaultTemplates
          .firstWhere((t) => t.id == 'loan_voucher')
          .templateEnglish;

      final restoredTemplate = await fakeRepo.getTemplate('loan_voucher');

      expect(find.text('Reset All Templates'), findsNothing);
      expect(fakeRepo.resetToDefaultsCalled, isTrue);
      expect(restoredTemplate.templateEnglish, expectedDefault);
      expect(find.byType(NotificationTemplatesScreen), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
