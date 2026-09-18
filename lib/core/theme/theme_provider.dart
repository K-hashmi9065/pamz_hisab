import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../db/hive/hive_registrar.dart';

const String _kThemeModeKey = 'app_theme_mode';

/// Riverpod Notifier for managing app theme mode with persistent storage in Hive.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    try {
      final box = HiveRegistrar.settingsBox;
      final savedMode = box.get(_kThemeModeKey) as String?;
      if (savedMode == 'dark') return ThemeMode.dark;
      if (savedMode == 'light') return ThemeMode.light;
      if (savedMode == 'system') return ThemeMode.system;
    } catch (_) {
      // Fallback to light mode if storage read fails
    }
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
