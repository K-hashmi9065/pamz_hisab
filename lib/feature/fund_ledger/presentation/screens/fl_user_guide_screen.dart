import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_bar_widgets.dart';

/// Interactive and comprehensive User Guide for PAMZ Fund Responsibility Ledger.
class FLUserGuideScreen extends StatelessWidget {
  const FLUserGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: const CustomAppBar(title: 'User Guide'),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(AppSpacing.md.r),
          children: [
            // Hero Intro Card
            Card(
              elevation: 0,
              color: isDark
                  ? AppColors.darkSurfaceVariant
                  : const Color(0xFFE8F5E9),
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
                      'A reliable, local-first fund responsibility and utilization management ledger designed for trustees, coordinators, families, and individuals managing public and personal funds.',
                      style: AppTextStyles.body.copyWith(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: AppSpacing.md.h),

            // Section 1: The Authoritative Balance Formula
            _guideSection(
              icon: Icons.calculate_outlined,
              iconColor: AppColors.credit,
              title: '1. Available Balance Formula',
              content:
                  'The core formula for calculating your net usable available fund is:\n\n'
                  '   Available Balance = Total Received - Total Returned - Total Utilized\n\n'
                  'Where:\n'
                  '• Total Received: Sum of all funds received from all contributors.\n'
                  '• Total Returned: Sum of all funds returned back to contributors.\n'
                  '• Total Utilized = Contact Utilized + Family Utilized.\n'
                  '• Contact Utilized: Funds spent/allocated towards specific contact project goals.\n'
                  '• Family Utilized: Funds utilized for family & personal expenses (Education, Medical, Grocery, etc.).',
              isDark: isDark,
            ),
            SizedBox(height: AppSpacing.md.h),

            // Section 2: Dashboard Summary Cards
            _guideSection(
              icon: Icons.dashboard_customize_outlined,
              iconColor: AppColors.info,
              title: '2. Dashboard Summary Overview',
              content:
                  'The Dashboard top header displays three real-time summary cards:\n\n'
                  '1. Available Balance (Green/Red):\n'
                  '   Net remaining fund available in your custody after subtracting returns and all utilizations.\n\n'
                  '2. Contact Utilized (Blue):\n'
                  '   Sum of all internal project utilizations recorded under Fund Ledger contacts.\n\n'
                  '3. Total Utilized (Primary/Dark):\n'
                  '   Combined total of both Contact Utilizations and Family Utilizations.\n\n'
                  'Lower metric cards show total Received, Returned, and Family Utilized breakdown at a glance.',
              isDark: isDark,
            ),
            SizedBox(height: AppSpacing.md.h),

            // Section 3: Family Utilize Tab
            _guideSection(
              icon: Icons.family_restroom_rounded,
              iconColor: const Color(0xFF3F51B5),
              title: '3. Family & Personal Utilization (Utilize Tab)',
              content:
                  'Use the dedicated Utilize tab (or Dashboard Quick Action) to track household and personal expenses:\n\n'
                  '• Preset Categories: Education, Electricity, Medical, Grocery, House Expense, Travel, Food, Maintenance, and Other.\n\n'
                  '• Payment Modes: Supports Cash, UPI, Cheque, and Draft.\n\n'
                  '• Optional References: Enter UTR number for UPI, Cheque number, or Draft number if available.\n\n'
                  '• Balance Protection: New utilization entries are automatically checked against the remaining available balance so you never overspend.\n\n'
                  '• Date & Category Filters: Filter by Today, This Week, This Month, This Year, or Custom date range, with instant full-text search.',
              isDark: isDark,
            ),
            SizedBox(height: AppSpacing.md.h),

            // Section 4: Fund Ledger Contact Transactions
            _guideSection(
              icon: Icons.swap_horiz_rounded,
              iconColor: AppColors.primary,
              title: '4. Contact Fund Transactions',
              content:
                  'Manage individual contributor accounts in the Contacts tab:\n\n'
                  '🟢 Receive Fund:\n'
                  'Record funds received from a contributor (supports Cash, UPI, Cheque, Draft with date & time).\n\n'
                  '🔵 Utilize Fund:\n'
                  'Record internal spending allocated towards this contact\'s project scope.\n\n'
                  '🔴 Return Fund:\n'
                  'Record money refunded or returned to the contributor.',
              isDark: isDark,
            ),
            SizedBox(height: AppSpacing.md.h),

            // Section 5: Strict Statement Privacy
            _guideSection(
              icon: Icons.shield_outlined,
              iconColor: Colors.amber.shade800,
              title: '5. Strict PDF Statement Privacy',
              content:
                  'When generating or sharing PDF statements with contributors:\n\n'
                  '• Only Received and Returned history are included on the shared statement.\n'
                  '• Internal contact utilizations and personal family expenses are NEVER shown on contributor statements.\n'
                  '• Ensures complete financial transparency for contributors while maintaining full privacy for internal spending.',
              isDark: isDark,
            ),
            SizedBox(height: AppSpacing.md.h),

            // Section 6: Data Safety & Offline Security
            _guideSection(
              icon: Icons.offline_pin_outlined,
              iconColor: AppColors.primaryLight,
              title: '6. 100% Offline & Local Storage',
              content:
                  '• All records are safely encrypted and stored on your local device.\n'
                  '• No external servers or cloud accounts required.\n'
                  '• Use the Settings tab to manage categories, payment modes, and audit logs.',
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
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
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
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
