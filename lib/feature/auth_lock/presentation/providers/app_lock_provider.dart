import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/security/biometric_service.dart';

final biometricServiceProvider = Provider<BiometricService>(
  (ref) => LocalAuthBiometricService(),
);

/// State of the application session lock.
class AppLockState {
  const AppLockState({
    this.isUnlocked = false,
    this.isAuthenticating = false,
    this.pausedAt,
  });

  final bool isUnlocked;
  final bool isAuthenticating;
  final DateTime? pausedAt;

  AppLockState copyWith({
    bool? isUnlocked,
    bool? isAuthenticating,
    DateTime? pausedAt,
    bool clearPausedAt = false,
  }) {
    return AppLockState(
      isUnlocked: isUnlocked ?? this.isUnlocked,
      isAuthenticating: isAuthenticating ?? this.isAuthenticating,
      pausedAt: clearPausedAt ? null : (pausedAt ?? this.pausedAt),
    );
  }
}

/// Central notifier for managing session lock, authentication state,
/// and background/resume timeout re-locking.
class AppLockNotifier extends Notifier<AppLockState> {
  @override
  AppLockState build() {
    return const AppLockState();
  }

  void unlock() {
    state = state.copyWith(isUnlocked: true, clearPausedAt: true);
  }

  void lock() {
    state = state.copyWith(isUnlocked: false, clearPausedAt: true);
  }

  void setAuthenticating(bool authenticating) {
    state = state.copyWith(isAuthenticating: authenticating);
  }

  void didEnterBackground() {
    // If a biometric dialog is currently active, avoid treating it as background idle timeout
    if (!state.isAuthenticating && state.isUnlocked) {
      state = state.copyWith(pausedAt: DateTime.now());
    }
  }

  void didResume({
    int timeoutSeconds = AppConstants.lockTimeoutSeconds,
    bool biometricEnabled = true,
  }) {
    if (!biometricEnabled) {
      unlock();
      return;
    }

    if (state.isAuthenticating) {
      return;
    }

    final paused = state.pausedAt;
    if (paused != null) {
      final elapsedSeconds = DateTime.now().difference(paused).inSeconds;
      if (elapsedSeconds >= timeoutSeconds) {
        lock();
      } else {
        state = state.copyWith(clearPausedAt: true);
      }
    }
  }
}

final appLockProvider = NotifierProvider<AppLockNotifier, AppLockState>(
  AppLockNotifier.new,
);
