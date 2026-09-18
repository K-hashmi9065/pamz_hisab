import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pamz_khata/core/db/hive/hive_registrar.dart';
import 'package:pamz_khata/feature/notifications/data/models/notification_template_model.dart';
import 'package:pamz_khata/feature/notifications/data/repositories/notification_template_repository.dart';
import 'package:pamz_khata/feature/notifications/presentation/screens/notification_templates_screen.dart';

import '../../test_helpers/pump_app.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('templates_test_');
    await HiveRegistrar.initialize(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('NotificationTemplate renders correctly with placeholders', () {
    const template = NotificationTemplate(
      id: 'test-1',
      name: 'Test Template',
      templateEnglish: 'Dear {contact_name}, received {amount}. Balance: {total_balance}.',
      templateHindi: 'नमस्ते {contact_name}, राशि {amount}.',
      templateHinglish: 'Namaste {contact_name}, amount {amount}.',
      supportedPlaceholders: ['{contact_name}', '{amount}', '{total_balance}'],
    );

    final rendered = NotificationTemplateRepository.render(
      template.templateEnglish,
      {
        '{contact_name}': 'Ramesh Kumar',
        '{amount}': '₹5,000',
        '{total_balance}': '₹15,000',
      },
    );

    expect(
      rendered,
      'Dear Ramesh Kumar, received ₹5,000. Balance: ₹15,000.',
    );
  });

  test('NotificationTemplateRepository provides default templates', () {
    const defaults = NotificationTemplateRepository.defaultTemplates;

    expect(defaults.length, 3);
    expect(defaults.any((t) => t.id == 'loan_voucher'), isTrue);
    expect(defaults.any((t) => t.id == 'statement_summary'), isTrue);
    expect(defaults.any((t) => t.id == 'repayment_jama'), isTrue);
  });

  testWidgets('NotificationTemplatesScreen allows tab switching and preview', (tester) async {
    await pumpApp(
      tester,
      const NotificationTemplatesScreen(),
    );

    await tester.pumpAndSettle();

    expect(find.text('English'), findsOneWidget);
    expect(find.text('हिंदी (Hindi)'), findsOneWidget);
    expect(find.text('Hinglish'), findsOneWidget);

    // Switch to Hindi
    await tester.tap(find.text('हिंदी (Hindi)'));
    await tester.pumpAndSettle();

    // Switch to Hinglish
    await tester.tap(find.text('Hinglish'));
    await tester.pumpAndSettle();

    expect(find.text('Template Editor'), findsOneWidget);
  });
}
