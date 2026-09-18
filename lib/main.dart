import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'core/constants/app_constants.dart';
import 'core/db/hive/hive_registrar.dart';
import 'core/db/sqlite/app_database.dart';
import 'core/db/storage_config.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'feature/auth_lock/presentation/providers/app_lock_provider.dart';
import 'feature/settings/presentation/providers/app_settings_providers.dart';
import 'routes/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive (settings, boxes, seed defaults)
  await HiveRegistrar.initialize();

  // Warm up SQLite only when SQLite engine is active
  if (AppStorageConfig.isSqlite) {
    await AppDatabase.instance.database;
  }

  runApp(
    const ProviderScope(
      child: PamzHisabApp(),
    ),
  );
}

class PamzHisabApp extends ConsumerStatefulWidget {
  const PamzHisabApp({super.key});

  @override
  ConsumerState<PamzHisabApp> createState() => _PamzHisabAppState();
}

class _PamzHisabAppState extends ConsumerState<PamzHisabApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final settings = ref.read(appSettingsProvider);
    final lockNotifier = ref.read(appLockProvider.notifier);

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      lockNotifier.didEnterBackground();
    } else if (state == AppLifecycleState.resumed) {
      lockNotifier.didResume(
        timeoutSeconds: AppConstants.lockTimeoutSeconds,
        biometricEnabled: settings.biometricEnabled,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(appRouterProvider);

    return ScreenUtilInit(
      // 11-inch iPad landscape design size
      designSize: const Size(
        AppConstants.designWidth,
        AppConstants.designHeight,
      ),
      minTextAdapt: true,
      splitScreenMode: true, // Support iPad Split View / Slide Over
      builder: (context, child) {
        return MaterialApp.router(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,

          // Theme
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,

          // Routing
          routerConfig: router,

          // Localization
          supportedLocales: const [
            Locale('en'),
            Locale('hi'),
          ],
          localizationsDelegates: const [
            // Will be added when l10n arb files are generated
          ],
        );
      },
    );
  }
}
