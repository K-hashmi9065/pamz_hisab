import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pamz_khata/core/db/hive/hive_registrar.dart';
import 'package:pamz_khata/feature/settings/data/models/payment_mode_model.dart';
import 'package:pamz_khata/feature/settings/data/repositories/payment_mode_repository.dart';
import 'package:pamz_khata/feature/settings/presentation/screens/payment_modes_screen.dart';
import 'package:pamz_khata/shared/widgets/app_button.dart';

import '../../test_helpers/pump_app.dart';

void main() {
  group('Payment Mode Unit & Widget Tests', () {
    late Directory tempDir;
    late PaymentModeRepository repository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hive_paymodes_test_');
      Hive.init(tempDir.path);
      await HiveRegistrar.initialize(tempDir.path);
      repository = const PaymentModeRepository();
      await repository.getPaymentModes();
    });

    tearDown(() async {
      await Hive.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    // ── Unit Tests ──

    test('1. PaymentMode Model serialization toMap and fromMap', () {
      const mode = PaymentMode(
        id: 'pm_test',
        code: 'gpay',
        name: 'Google Pay',
        iconKey: '📱',
        isActive: true,
        isSystemPreset: false,
      );

      final map = mode.toMap();
      final fromMap = PaymentMode.fromMap(map);

      expect(fromMap.id, 'pm_test');
      expect(fromMap.code, 'gpay');
      expect(fromMap.name, 'Google Pay');
      expect(fromMap.iconKey, '📱');
      expect(fromMap.isActive, isTrue);
      expect(fromMap.isSystemPreset, isFalse);
    });

    test('2. Repository getPaymentModes seeds defaults on first run', () async {
      final modes = await repository.getPaymentModes();
      expect(modes.length, 4);
      expect(modes.any((m) => m.name == 'Cash'), isTrue);
      expect(modes.any((m) => m.name == 'UPI / QR Code'), isTrue);
    });

    test('3. Repository addPaymentMode, toggleModeActive, deletePaymentMode', () async {
      final added = await repository.addPaymentMode('Crypto USDT', '💎');
      expect(added.name, 'Crypto USDT');
      expect(added.isSystemPreset, isFalse);

      var modes = await repository.getPaymentModes();
      expect(modes.length, 5);

      // Toggle active
      await repository.toggleModeActive(added.id, false);
      modes = await repository.getPaymentModes();
      final toggled = modes.firstWhere((m) => m.id == added.id);
      expect(toggled.isActive, isFalse);

      // Delete custom mode
      await repository.deletePaymentMode(added.id);
      modes = await repository.getPaymentModes();
      expect(modes.length, 4);
      expect(modes.any((m) => m.id == added.id), isFalse);
    });

    // ── Widget Tests ──

    testWidgets('4. PaymentModesScreen renders default payment modes', (tester) async {
      tester.view.physicalSize = const Size(1194, 834);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpApp(
        tester,
        const PaymentModesScreen(),
        overrides: [
          paymentModeRepositoryProvider.overrideWithValue(repository),
        ],
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Payment Modes Configuration'), findsOneWidget);
      expect(find.text('Cash'), findsOneWidget);
      expect(find.text('UPI / QR Code'), findsOneWidget);
      expect(find.text('Bank Transfer (NEFT/IMPS)'), findsOneWidget);
      expect(find.text('Cheque'), findsOneWidget);
      expect(find.text('SYSTEM'), findsWidgets);
    });

    testWidgets('5. Add Custom Payment Mode dialog creates new mode', (tester) async {
      tester.view.physicalSize = const Size(1194, 834);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpApp(
        tester,
        const PaymentModesScreen(),
        overrides: [
          paymentModeRepositoryProvider.overrideWithValue(repository),
        ],
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap FAB
      final fab = find.byType(FloatingActionButton);
      await tester.ensureVisible(fab);
      await tester.tap(fab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Add Custom Payment Mode'), findsOneWidget);

      // Enter name
      final nameField = find.byType(TextFormField).first;
      await tester.enterText(nameField, 'PhonePe Business');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Select emoji (tap second emoji in the dialog Wrap)
      final emojiOption = find.descendant(of: find.byType(Dialog), matching: find.text('📱'));
      await tester.tap(emojiOption);
      await tester.pumpAndSettle();

      // Submit
      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(AppButton, 'Add Mode'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await repository.getPaymentModes();
      });

      // Advance frames across the async add, provider invalidation, and dialog pop
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('PhonePe Business'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('6. Toggle payment mode switch updates active state', (tester) async {
      tester.view.physicalSize = const Size(1194, 834);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpApp(
        tester,
        const PaymentModesScreen(),
        overrides: [
          paymentModeRepositoryProvider.overrideWithValue(repository),
        ],
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final firstSwitch = find.byType(Switch).first;
      expect(firstSwitch, findsOneWidget);

      late List<PaymentMode> modes;
      await tester.runAsync(() async {
        await tester.tap(firstSwitch);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        modes = await repository.getPaymentModes();
      });

      // Advance frames across the async toggle, provider invalidation, and switch animation
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));

      expect(modes.first.isActive, isFalse);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
