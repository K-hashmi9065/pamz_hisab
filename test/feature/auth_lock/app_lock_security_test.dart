import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pamz_khata/core/constants/app_constants.dart';
import 'package:pamz_khata/feature/auth_lock/presentation/providers/app_lock_provider.dart';

void main() {
  group('AppLockNotifier Security & Lifecycle Tests', () {
    test('initial state is locked and not authenticating', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(appLockProvider);
      expect(state.isUnlocked, isFalse);
      expect(state.isAuthenticating, isFalse);
      expect(state.pausedAt, isNull);
    });

    test('unlock() transitions session to isUnlocked = true', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(appLockProvider.notifier).unlock();
      expect(container.read(appLockProvider).isUnlocked, isTrue);
    });

    test('lock() transitions session back to isUnlocked = false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(appLockProvider.notifier);
      notifier.unlock();
      expect(container.read(appLockProvider).isUnlocked, isTrue);

      notifier.lock();
      expect(container.read(appLockProvider).isUnlocked, isFalse);
    });

    test('didEnterBackground records pausedAt when unlocked', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(appLockProvider.notifier);
      notifier.unlock();
      notifier.didEnterBackground();

      expect(container.read(appLockProvider).pausedAt, isNotNull);
    });

    test('didResume locks session when background duration exceeds timeout', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(appLockProvider.notifier);
      notifier.unlock();

      // Simulate backgrounding 301 seconds ago
      notifier.state = notifier.state.copyWith(
        pausedAt: DateTime.now().subtract(const Duration(seconds: AppConstants.lockTimeoutSeconds + 1)),
      );

      notifier.didResume(
        timeoutSeconds: AppConstants.lockTimeoutSeconds,
        biometricEnabled: true,
      );

      expect(container.read(appLockProvider).isUnlocked, isFalse);
      expect(container.read(appLockProvider).pausedAt, isNull);
    });

    test('didResume preserves unlock when background duration is within timeout', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(appLockProvider.notifier);
      notifier.unlock();

      // Simulate backgrounding 10 seconds ago
      notifier.state = notifier.state.copyWith(
        pausedAt: DateTime.now().subtract(const Duration(seconds: 10)),
      );

      notifier.didResume(
        timeoutSeconds: AppConstants.lockTimeoutSeconds,
        biometricEnabled: true,
      );

      expect(container.read(appLockProvider).isUnlocked, isTrue);
      expect(container.read(appLockProvider).pausedAt, isNull);
    });

    test('didResume automatically unlocks if biometricEnabled is false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(appLockProvider.notifier);
      expect(container.read(appLockProvider).isUnlocked, isFalse);

      notifier.didResume(
        timeoutSeconds: AppConstants.lockTimeoutSeconds,
        biometricEnabled: false,
      );

      expect(container.read(appLockProvider).isUnlocked, isTrue);
    });
  });
}
