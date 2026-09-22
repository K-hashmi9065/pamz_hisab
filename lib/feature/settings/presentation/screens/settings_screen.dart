import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../shared/widgets/app_bar_widgets.dart';
import '../../../../shared/widgets/app_card.dart';
import '../providers/app_settings_providers.dart';
import 'audit_log_screen.dart';
import 'payment_modes_screen.dart';

/// Settings screen for app configuration and Fund Ledger preferences.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final isWide =
        MediaQuery.of(context).size.width >= AppConstants.tabletBreakpoint;

    final content = ListView(
      padding: EdgeInsets.all(AppSpacing.lg.w),
      children: [
        const SectionHeader(title: 'App Configuration'),
        SizedBox(height: AppSpacing.sm.h),
        AppCard(
          child: Column(
            children: [
              _SettingsTile(
                icon: Icons.dark_mode_rounded,
                title: 'Theme Mode',
                subtitle: _themeModeLabel(ref.watch(themeModeProvider)),
                onTap: () => _showThemePicker(context, ref),
              ),
              const Divider(height: 1),
              _SettingsTile(
                icon: Icons.currency_rupee_rounded,
                title: 'Currency & Numbering',
                subtitle:
                    '${settings.currencySymbol} · ${settings.numberingFormat}',
                onTap: () => _showCurrencyNumberingPicker(context, ref),
              ),
              const Divider(height: 1),
              _SettingsTile(
                icon: Icons.calendar_month_rounded,
                title: 'Fiscal Year Start',
                subtitle: settings.fiscalYearLabel,
                onTap: () => _showFiscalYearPicker(context, ref),
              ),
              const Divider(height: 1),
              _SettingsTile(
                icon: Icons.percent_rounded,
                title: 'GST Settings',
                subtitle: settings.gstEnabled
                    ? 'Enabled · ${settings.gstRate.toStringAsFixed(0)}% default rate'
                    : 'Disabled (Click to configure)',
                onTap: () => _showGstSettingsDialog(context, ref),
              ),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.xl.h),
        const SectionHeader(title: 'Manage Data'),
        SizedBox(height: AppSpacing.sm.h),
        AppCard(
          child: Column(
            children: [
              _SettingsTile(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Payment Modes',
                subtitle: 'Cash, UPI, Bank Transfer, Cheque',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PaymentModesScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.xl.h),
        const SectionHeader(title: 'Security & Audit'),
        SizedBox(height: AppSpacing.sm.h),
        AppCard(
          child: Column(
            children: [
              _SettingsTile(
                icon: Icons.fingerprint_rounded,
                title: 'Biometric Lock',
                subtitle: 'Face ID / Touch ID protection at startup',
                onTap: () {},
                trailing: Switch(
                  value: settings.biometricEnabled,
                  onChanged: (v) {
                    ref
                        .read(appSettingsProvider.notifier)
                        .setBiometricEnabled(v);
                  },
                  activeTrackColor: AppColors.primary,
                ),
              ),
              const Divider(height: 1),
              _SettingsTile(
                icon: Icons.history_edu_rounded,
                title: 'Audit Logs',
                subtitle: 'View full trail of financial mutations',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AuditLogScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.xl.h),
        const SectionHeader(title: 'Language'),
        SizedBox(height: AppSpacing.sm.h),
        AppCard(
          child: _SettingsTile(
            icon: Icons.language_rounded,
            title: 'App Language',
            subtitle: 'English (India)',
            onTap: () {},
          ),
        ),
        SizedBox(height: AppSpacing.xxxl.h),
        Center(
          child: Text(
            'PAMZ Hisab v1.1.0 · Offline-first · Kishanganj, Bihar',
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(height: AppSpacing.lg.h),
      ],
    );

    return Scaffold(
      appBar: const CustomAppBar(title: 'Settings'),
      body: isWide
          ? Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: content,
              ),
            )
          : content,
    );
  }

  static String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'Dark Mode';
      case ThemeMode.light:
        return 'Light Mode';
      case ThemeMode.system:
        return 'System Default (Follows Device)';
    }
  }

  void _showThemePicker(BuildContext context, WidgetRef ref) {
    final currentMode = ref.read(themeModeProvider);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                currentMode == ThemeMode.system
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color:
                    currentMode == ThemeMode.system ? AppColors.primary : null,
              ),
              title: const Text('System Default'),
              subtitle: const Text('Matches your device dark/light setting'),
              onTap: () {
                ref
                    .read(themeModeProvider.notifier)
                    .setThemeMode(ThemeMode.system);
                Navigator.of(ctx).pop();
              },
            ),
            ListTile(
              leading: Icon(
                currentMode == ThemeMode.dark
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: currentMode == ThemeMode.dark ? AppColors.primary : null,
              ),
              title: const Text('Dark Mode'),
              subtitle: const Text('High contrast dark palette'),
              onTap: () {
                ref
                    .read(themeModeProvider.notifier)
                    .setThemeMode(ThemeMode.dark);
                Navigator.of(ctx).pop();
              },
            ),
            ListTile(
              leading: Icon(
                currentMode == ThemeMode.light
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color:
                    currentMode == ThemeMode.light ? AppColors.primary : null,
              ),
              title: const Text('Light Mode'),
              subtitle: const Text('Clean light palette'),
              onTap: () {
                ref
                    .read(themeModeProvider.notifier)
                    .setThemeMode(ThemeMode.light);
                Navigator.of(ctx).pop();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showCurrencyNumberingPicker(BuildContext context, WidgetRef ref) {
    final currentSettings = ref.read(appSettingsProvider);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Currency & Numbering'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Currency Symbol',
                style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 8.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: ['₹', '\$', '€', '£', 'AED'].map((sym) {
                final isSelected = currentSettings.currencySymbol == sym;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8.r),
                    onTap: () {
                      ref
                          .read(appSettingsProvider.notifier)
                          .setCurrencySymbol(sym);
                      Navigator.of(ctx).pop();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding:
                          EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : (Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[800]
                                : Colors.grey[100]),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.grey.withValues(alpha: 0.35),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelected) ...[
                            Icon(Icons.check_rounded,
                                size: 16.r, color: Colors.white),
                            SizedBox(width: 4.w),
                          ],
                          Text(
                            sym,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? Colors.white
                                  : (Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 16.h),
            const Text('Numbering Presentation',
                style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 8.h),
            RadioGroup<String>(
              groupValue: currentSettings.numberingFormat,
              onChanged: (val) {
                if (val != null) {
                  ref
                      .read(appSettingsProvider.notifier)
                      .setNumberingFormat(val);
                  Navigator.of(ctx).pop();
                }
              },
              child: const Column(
                children: [
                  RadioListTile<String>(
                    value: 'Indian (Lakhs & Crores)',
                    title: Text('Indian (Lakhs & Crores)'),
                    subtitle: Text('e.g. ₹1,50,000'),
                  ),
                  RadioListTile<String>(
                    value: 'Standard (Millions & Billions)',
                    title: Text('Standard (Millions & Billions)'),
                    subtitle: Text('e.g. ₹150,000'),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showFiscalYearPicker(BuildContext context, WidgetRef ref) {
    final currentSettings = ref.read(appSettingsProvider);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fiscal Year Start Month'),
        content: RadioGroup<int>(
          groupValue: currentSettings.fiscalYearStartMonth,
          onChanged: (val) {
            if (val != null) {
              ref
                  .read(appSettingsProvider.notifier)
                  .setFiscalYearStartMonth(val);
              Navigator.of(ctx).pop();
            }
          },
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<int>(
                value: 4,
                title: Text('April 1'),
                subtitle: Text('Standard Indian Financial Year (Recommended)'),
              ),
              RadioListTile<int>(
                value: 1,
                title: Text('January 1'),
                subtitle: Text('Calendar Year (Jan - Dec)'),
              ),
              RadioListTile<int>(
                value: 7,
                title: Text('July 1'),
              ),
              RadioListTile<int>(
                value: 10,
                title: Text('October 1'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showGstSettingsDialog(BuildContext context, WidgetRef ref) {
    final currentSettings = ref.read(appSettingsProvider);
    bool gstEnabled = currentSettings.gstEnabled;
    double gstRate = currentSettings.gstRate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('GST Configuration'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                title: const Text('Enable GST on Invoices'),
                value: gstEnabled,
                onChanged: (v) => setState(() => gstEnabled = v),
              ),
              if (gstEnabled) ...[
                SizedBox(height: 12.h),
                const Text('Default GST Rate',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(height: 8.h),
                Wrap(
                  spacing: 8.w,
                  children: [5.0, 12.0, 18.0, 28.0].map((rate) {
                    final isSelected = gstRate == rate;
                    return ChoiceChip(
                      label: Text('${rate.toStringAsFixed(0)}%'),
                      selected: isSelected,
                      onSelected: (val) {
                        if (val) setState(() => gstRate = rate);
                      },
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                ref
                    .read(appSettingsProvider.notifier)
                    .setGstEnabled(gstEnabled);
                ref.read(appSettingsProvider.notifier).setGstRate(gstRate);
                Navigator.of(ctx).pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: EdgeInsets.all(AppSpacing.xs.w),
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(15),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm.r),
        ),
        child: Icon(icon, color: AppColors.primary, size: AppSpacing.iconMd.w),
      ),
      title: Text(title, style: AppTextStyles.bodyMedium),
      subtitle: Text(subtitle, style: AppTextStyles.caption),
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
    );
  }
}
