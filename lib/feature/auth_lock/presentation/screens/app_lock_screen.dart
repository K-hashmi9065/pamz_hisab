import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';


import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../routes/route_names.dart';
import '../../../../shared/widgets/app_button.dart';

import '../../../settings/presentation/providers/app_settings_providers.dart';
import '../providers/app_lock_provider.dart';

export '../providers/app_lock_provider.dart' show biometricServiceProvider, appLockProvider, AppLockState, AppLockNotifier;

/// App lock screen — shown at cold start and after timeout.
/// Triggers biometric auth → marks session unlocked on success.
class AppLockScreen extends ConsumerStatefulWidget {
  const AppLockScreen({super.key});

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen> {
  bool _isAuthenticating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Auto-trigger on first build
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  Future<void> _authenticate() async {
    final settings = ref.read(appSettingsProvider);
    if (!settings.biometricEnabled) {
      ref.read(appLockProvider.notifier).unlock();
      if (mounted) context.goNamed(RouteNames.dashboard);
      return;
    }

    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });
    ref.read(appLockProvider.notifier).setAuthenticating(true);

    final service = ref.read(biometricServiceProvider);
    final available = await service.isAvailable();

    // On non-iOS / web or if biometrics not available, skip lock and navigate to dashboard
    if (!available) {
      ref.read(appLockProvider.notifier).setAuthenticating(false);
      ref.read(appLockProvider.notifier).unlock();
      if (mounted) {
        try {
          context.goNamed(RouteNames.dashboard);
        } catch (_) {}
      }
      return;
    }

    final success = await service.authenticate(
      localizedReason: 'Please authenticate to open PAMZ Hisab',
    );

    ref.read(appLockProvider.notifier).setAuthenticating(false);

    if (!mounted) return;

    setState(() => _isAuthenticating = false);

    if (success) {
      ref.read(appLockProvider.notifier).unlock();
      try {
        context.goNamed(RouteNames.dashboard);
      } catch (_) {}
    } else {
      setState(() => _errorMessage =
          'Authentication failed. Please try again or use your passcode.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.sidebarBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.xxl.w,
              vertical: AppSpacing.xl.h,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // App icon
                  Container(
                    padding: EdgeInsets.all(AppSpacing.xl.w),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(40),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 64.r,
                      color: AppColors.onPrimary,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xl.h),
                  Text(
                    'PAMZ Hisab',
                    style: AppTextStyles.display.copyWith(
                      color: AppColors.onPrimary,
                    ),
                  ),
                  SizedBox(height: AppSpacing.sm.h),
                  Text(
                    'Your secure financial ledger',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.onPrimary.withAlpha(160),
                    ),
                  ),
                  SizedBox(height: AppSpacing.xxxl.h),

                  if (_isAuthenticating) ...[
                    const CircularProgressIndicator(color: AppColors.primaryLight),
                    SizedBox(height: AppSpacing.lg.h),
                    Text(
                      'Authenticating...',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.onPrimary.withAlpha(180),
                      ),
                    ),
                  ] else ...[
                    Icon(
                      Icons.fingerprint_rounded,
                      size: 56.r,
                      color: AppColors.primaryLight,
                    ),
                    SizedBox(height: AppSpacing.lg.h),
                    if (_errorMessage != null)
                      Padding(
                        padding: EdgeInsets.only(bottom: AppSpacing.lg.h),
                        child: Text(
                          _errorMessage!,
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.debit.withAlpha(200),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    AppButton(
                      label: 'Authenticate',
                      icon: Icons.lock_open_rounded,
                      onPressed: _authenticate,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
