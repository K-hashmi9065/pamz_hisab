import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pamz_khata/core/constants/app_constants.dart';
import 'package:pamz_khata/core/theme/app_colors.dart';
import 'package:pamz_khata/shared/widgets/app_button.dart';
import 'test_helpers/pump_app.dart';

void main() {
  testWidgets('AppButton renders label and handles tap', (tester) async {
    bool tapped = false;

    await pumpApp(
      tester,
      AppButton(
        label: 'Save Contact',
        onPressed: () => tapped = true,
      ),
    );

    expect(find.text('Save Contact'), findsOneWidget);
    await tester.tap(find.text('Save Contact'));
    expect(tapped, isTrue);
  });

  test('AppConstants values are correct', () {
    expect(AppConstants.appName, 'PAMZ Hisab');
    expect(AppConstants.designWidth, 1180.0);
    expect(AppConstants.designHeight, 820.0);
  });

  test('AppColors — Utilize/Receive button color matches Utilized card color', () {
    // Both Receive & Utilize Quick Action buttons now use AppColors.info (blue)
    // to match the blue color shown in the Utilized stat card above them.
    expect(AppColors.info, const Color(0xFF1976D2));

    // Return button keeps its red color
    expect(AppColors.debit, const Color(0xFFC62828));

    // Credit green is still used for financial indicators (not buttons)
    expect(AppColors.credit, const Color(0xFF2E7D32));
  });
}
