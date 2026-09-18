import 'package:flutter_test/flutter_test.dart';
import 'package:pamz_khata/feature/settings/data/models/payment_mode_model.dart';
import 'package:pamz_khata/feature/settings/data/repositories/payment_mode_repository.dart';
import 'package:pamz_khata/feature/settings/presentation/screens/payment_modes_screen.dart';

import '../../test_helpers/pump_app.dart';

void main() {
  test('PaymentMode default presets check', () {
    const presets = PaymentModeRepository.defaultPresets;

    expect(presets.length, 4);
    expect(presets.any((m) => m.name == 'Cash'), isTrue);
    expect(presets.any((m) => m.name == 'UPI / QR Code'), isTrue);
    expect(presets.any((m) => m.name == 'Bank Transfer (NEFT/IMPS)'), isTrue);
    expect(presets.any((m) => m.name == 'Cheque'), isTrue);
  });

  testWidgets('PaymentModesScreen displays modes and responds to add button', (tester) async {
    const testModes = [
      PaymentMode(id: 'pm_cash', code: 'cash', name: 'Cash', iconKey: '💵', isSystemPreset: true),
      PaymentMode(id: 'pm_upi', code: 'upi', name: 'UPI / QR Code', iconKey: '📱', isSystemPreset: true),
    ];

    await pumpApp(
      tester,
      const PaymentModesScreen(),
      overrides: [
        paymentModesListProvider.overrideWith((ref) async => testModes),
      ],
    );

    await tester.pumpAndSettle();

    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('UPI / QR Code'), findsOneWidget);
  });
}
