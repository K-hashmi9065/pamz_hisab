import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Abstract interface for biometric authentication.
/// Separated from implementation so it can be mocked in tests.
abstract class BiometricService {
  Future<bool> isAvailable();
  Future<bool> authenticate({String localizedReason});
}

/// Production implementation using local_auth.
class LocalAuthBiometricService implements BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  Future<bool> isAvailable() async {
    // Web / Desktop / Windows (CI, dev): biometrics not available
    if (kIsWeb || (!Platform.isIOS && !Platform.isAndroid)) return false;
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate({
    String localizedReason = 'Please authenticate to open PAMZ Hisab',
  }) async {
    if (kIsWeb || (!Platform.isIOS && !Platform.isAndroid)) return true; // pass on web/desktop
    try {
      return await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          biometricOnly: false, // allow passcode fallback
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}

/// No-op implementation for tests / non-iOS environments.
class AlwaysAuthenticatedBiometricService implements BiometricService {
  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> authenticate({String localizedReason = ''}) async => true;
}
