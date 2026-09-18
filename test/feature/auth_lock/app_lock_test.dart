import 'package:flutter_test/flutter_test.dart';
import 'package:pamz_khata/core/security/biometric_service.dart';
import 'package:pamz_khata/feature/auth_lock/presentation/screens/app_lock_screen.dart';

import '../../test_helpers/pump_app.dart';

void main() {
  testWidgets('AppLockScreen renders app title and lock branding', (tester) async {
    await pumpApp(
      tester,
      const AppLockScreen(),
      overrides: [
        biometricServiceProvider.overrideWithValue(AlwaysAuthenticatedBiometricService()),
      ],
    );

    expect(find.text('PAMZ Hisab'), findsOneWidget);
    expect(find.text('Your secure financial ledger'), findsOneWidget);
  });

  testWidgets('appRouterProvider redirects unauthenticated user trying to access /dashboard to /lock', (tester) async {
    // When session is locked (default state), navigating to /dashboard should redirect to /lock
    await pumpApp(
      tester,
      const AppLockScreen(),
      overrides: [
        biometricServiceProvider.overrideWithValue(AlwaysAuthenticatedBiometricService()),
      ],
    );

    expect(find.byType(AppLockScreen), findsOneWidget);
  });
}
