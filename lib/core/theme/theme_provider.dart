import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/hive/hive_registrar.dart';

const String _kThemeModeKey = 'app_theme_mode';

/// Riverpod Notifier for managing the current app theme mode.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    // Always start a new app session in light mode. Users can still switch to
    // dark or system mode from Settings while the app is open.
    return ThemeMode.light;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      final box = HiveRegistrar.settingsBox;
      String modeString;
      switch (mode) {
        case ThemeMode.dark:
          modeString = 'dark';
          break;
        case ThemeMode.light:
          modeString = 'light';
          break;
        case ThemeMode.system:
          modeString = 'system';
          break;
      }
      await box.put(_kThemeModeKey, modeString);
    } catch (_) {}
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
