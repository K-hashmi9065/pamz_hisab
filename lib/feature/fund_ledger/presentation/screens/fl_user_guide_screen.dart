import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Interactive and comprehensive User Guide for Fund Responsibility Ledger.
class FLUserGuideScreen extends StatelessWidget {
  const FLUserGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'User Guide',
          style: AppTextStyles.h2.copyWith(
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(AppSpacing.md.r),
          children: [
            // Hero Intro Card
            Card(
              elevation: 0,
              color: isDark ? AppColors.darkSurfaceVariant : const Color(0xFFE8F5E9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg.r),
                side: BorderSide(
                  color: AppColors.primary.withAlpha(80),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg.r),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_rounded,
                          color: AppColors.primary,
                          size: 28.r,
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Text(
                            'PAMZ Fund Responsibility Ledger',
                            style: AppTextStyles.h2.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'A reliable, local-first fund management ledger designed for trustees, coordinators, and individuals managing public, family, or organizational funds.',
                      style: AppTextStyles.body.copyWith(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: AppSpacing.md.h),

            // Rule 1: The Golden Formula
            _guideSection(
              icon: Icons.calculate_outlined,
              iconColor: AppColors.credit,
              title: '1. Available Fund Formula',
              content:
                  'The authoritative formula for calculating fund responsibility is:\n\n'
                  '   Available = Total Received - Total Returned\n\n'
                  '• Total Received: Total money handed over to you by this contact.\n'
                  '• Total Returned: Total money returned back to this contact.\n'
                  '• Total Utilized: Money allocated/spent towards authorized goals. (Tracked internally; does not reduce your initial receipt responsibility until formally settled).',
              isDark: isDark,
            ),
            SizedBox(height: AppSpacing.md.h),

            // Rule 2: Transaction Types Explained
            _guideSection(
              icon: Icons.swap_horiz_rounded,
              iconColor: AppColors.info,
              title: '2. The Three Transaction Types',
              content:
                  '🟢 Receive Fund:\n'
                  'Record when a contact transfers or deposits money into your custody. Increases available funds.\n\n'
                  '🔵 Utilize Fund:\n'
                  'Record when you spend or distribute money on project expenses (e.g. food, medical aid, materials, fees). Includes a purpose title and optional notes.\n\n'
                  '🔴 Return Fund:\n'
                  'Record when you return unused or requested funds back to the contributor. Reduces available funds.',
              isDark: isDark,
            ),
            SizedBox(height: AppSpacing.md.h),

            // Rule 3: Privacy by Design
            _guideSection(
              icon: Icons.shield_outlined,
              iconColor: Colors.amber.shade800,
              title: '3. Strict Privacy Boundary in PDF Statements',
              content:
                  'When you generate or share a PDF statement with a contributor:\n\n'
                  '• Only Received and Returned entries are included in the statement.\n'
                  '• Utilized details (internal spending records) are strictly excluded from shared statements to preserve internal privacy and trust.\n'
                  '• PDFs are generated completely offline on your device.',
              isDark: isDark,
            ),
            SizedBox(height: AppSpacing.md.h),

            // Rule 4: Data Safety & Backup
            _guideSection(
              icon: Icons.offline_pin_outlined,
              iconColor: AppColors.primary,
              title: '4. 100% Offline & Local Storage',
              content:
                  '• All data is saved on your local device storage.\n'
                  '• No account or internet connection is required.\n'
                  '• Keep your app updated and perform regular backups via the Settings tab.',
              isDark: isDark,
            ),
            SizedBox(height: AppSpacing.xl.h),
          ],
        ),
      ),
    );
  }

  Widget _guideSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String content,
    required bool isDark,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg.r),
        side: BorderSide(
          color: isDark ? AppColors.darkOutline : AppColors.outline,
          width: 0.8,
        ),
      ),
      color: isDark ? AppColors.darkCardBackground : AppColors.cardBackground,
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: iconColor.withAlpha(isDark ? 30 : 25),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(icon, color: iconColor, size: 20.r),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.h3.copyWith(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Text(
              content,
              style: AppTextStyles.body.copyWith(
                height: 1.5,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
