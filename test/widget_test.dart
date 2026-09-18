import 'package:flutter_test/flutter_test.dart';
import 'package:pamz_khata/core/constants/app_constants.dart';
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
}
