import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_bar_widgets.dart';
import '../../../../shared/widgets/app_card.dart';

class UserGuideScreen extends StatefulWidget {
  const UserGuideScreen({super.key});

  @override
  State<UserGuideScreen> createState() => _UserGuideScreenState();
}

class _UserGuideScreenState extends State<UserGuideScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  static const List<_GuideSection> _allSections = [
    _GuideSection(
      id: 'dashboard',
      title: '1. Dashboard & Quick Actions',
      icon: Icons.dashboard_rounded,
      tag: 'Overview',
      summary: 'Executive real-time financial snapshot and quick actions.',
      items: [
        _GuideItem(
          title: 'Executive Financial Cards',
          content:
              'The dashboard provides an instant overview of your business & personal health:\n'
              '• Total Income: Sum of all earnings recorded this month.\n'
              '• Total Expense: Sum of all expenses incurred this month.\n'
              '• Net Savings: Calculated automatically as Total Income − Total Expense.\n'
              '• Active Contacts: Number of buyers and suppliers with ledger activity.\n'
              '• Net Udhar Receivable: Net amount owed to you across all credit books.',
        ),
        _GuideItem(
          title: 'Full Exact Amount Display',
          content:
              'All monetary figures show the full exact Indian currency amount (e.g. ₹2,450, ₹50,000, ₹1,25,000) rather than abbreviated approximations, ensuring complete financial precision.',
        ),
        _GuideItem(
          title: 'Quick Actions Bar',
          content:
              'Instantly log entries from the top action bar:\n'
              '• + Income: Quick modal to log revenue.\n'
              '• + Expense: Quick modal to log spending.\n'
              '• + Udhar: Record a credit loan given or taken.\n'
              '• + Buyer: Register a new customer.\n'
              '• + Supplier: Register a new vendor/wholesaler.',
        ),
        _GuideItem(
          title: 'Recent Activity Feed',
          content:
              'Displays the latest 5 transactions across your ledger. Tapping any entry navigates to its full detail.',
        ),
      ],
    ),
    _GuideSection(
      id: 'udhar_khata',
      title: '2. Udhar Khata (Credit Ledger)',
      icon: Icons.handshake_rounded,
      tag: 'Core Ledger',
      summary: 'Manage Buyer and Supplier credits, loans, and repayments.',
      items: [
        _GuideItem(
          title: 'Buyer (Grahak) Ledger',
          content:
              '• Adding a Buyer: Tap "+ Buyer" to record name, phone number, village/tola, address, and credit limit.\n'
              '• Given Udhar (Diya): When you sell on credit or loan cash, record an entry. This increases their Receivable balance.\n'
              '• Record Jama (Payment): When the buyer pays you back (cash, UPI, or bank transfer), record Jama to settle the balance.\n'
              '• Opening Balance: Bring forward previous historical debt when migrating to PAMZ Hisab.',
        ),
        _GuideItem(
          title: 'Supplier (Bypari) Ledger',
          content:
              '• Adding a Supplier: Register suppliers with contact details and shop locations.\n'
              '• Taken Udhar (Liya): When purchasing goods on credit or borrowing funds, record a Taken entry (Payable).\n'
              '• Supplier Payments: Record repayments made to suppliers to reduce your debt liability.\n'
              '• Due Date Alerts: Enable payment reminder notifications for supplier invoices.',
        ),
        _GuideItem(
          title: 'Direct Cash Loans & Opening Balances',
          content:
              '• Direction: Choose "Given (Lent)" or "Taken (Borrowed)".\n'
              '• Interest Types: Choose "Interest-Free" or "Simple Interest (% per month)".\n'
              '• Due Dates: Set optional due dates to track payment deadlines.\n'
              '• Status Lifecycle: Automatically transitions from OPEN → CLOSED upon full repayment.',
        ),
        _GuideItem(
          title: 'WhatsApp & PDF Statement Sharing',
          content:
              'Tap "Share Ledger Statement (WhatsApp / PDF)" on any contact page to generate a branded, itemized PDF receipt and send formatted transaction summaries directly via WhatsApp.',
        ),
      ],
    ),
    _GuideSection(
      id: 'family_finance',
      title: '3. Family Finance & Cashbook',
      icon: Icons.people_rounded,
      tag: 'Personal & Business',
      summary: 'Track daily personal, household, and shop cashflow transactions.',
      items: [
        _GuideItem(
          title: 'Recording Transactions',
          content:
              '• Log Income: Select amount, source category (e.g. Salary, Crop Sales, Shop Sales), and account.\n'
              '• Log Expense: Select amount, expense category (e.g. Groceries, Fertilizer, Utilities, Fuel), and account.\n'
              '• Payment Modes: Supports Cash, Bank Account, and UPI/Online.\n'
              '• Transaction Date: Backdate or forward-date entries accurately.\n'
              '• Memos & Tags: Add reference notes for easy searching.',
        ),
        _GuideItem(
          title: 'Managing Transactions',
          content:
              '• Edit Entry: Tap any transaction in the cashbook list to modify amounts, dates, or categories.\n'
              '• Delete Entry: Remove mistakes cleanly with an immediate confirmation dialog.',
        ),
      ],
    ),
    _GuideSection(
      id: 'budgets',
      title: '4. Budgets & Spending Limits',
      icon: Icons.pie_chart_outline_rounded,
      tag: 'Budgeting',
      summary: 'Set monthly category spending caps to prevent overspending.',
      items: [
        _GuideItem(
          title: 'Creating a Monthly Budget',
          content:
              '1. Go to Family Finance → tap "Manage Budgets" (or use Quick Actions).\n'
              '2. Select an Expense Category (e.g. Groceries, Fuel, Utilities).\n'
              '3. Enter your monthly limit in ₹.\n'
              '4. Set an alert threshold percentage (e.g. 80% or 90%).',
        ),
        _GuideItem(
          title: 'Visual Progress Tracking',
          content:
              '• Green: Spending is well within your budget limit.\n'
              '• Orange: Spending has crossed your alert threshold.\n'
              '• Red: Budget exceeded.\n'
              'Progress bars automatically track all expenses recorded in that category for the active month.',
        ),
      ],
    ),
    _GuideSection(
      id: 'analytics',
      title: '5. Analytics & P&L Reports',
      icon: Icons.bar_chart_rounded,
      tag: 'Reports',
      summary: 'Deep-dive into income trends, category distributions, and multi-year insights.',
      items: [
        _GuideItem(
          title: 'Time Horizons',
          content:
              'Analyze your finances across multiple horizons:\n'
              '• Weekly: Last 7 days cashflow.\n'
              '• Monthly: Current and previous calendar months.\n'
              '• Quarterly (Agricultural Cycles): Kharif, Rabi, and Zaid crop seasons tailored for regional agricultural cashflows.\n'
              '• Yearly: Annual financial statement.\n'
              '• 10-Year Lookback: Historical multi-year comparison table.\n'
              '• Custom Range: Pick any custom start and end dates with the date picker.',
        ),
        _GuideItem(
          title: 'Export to PDF & Excel',
          content:
              'Generate professional reports anytime:\n'
              '• PDF Report: Generates a multi-page, formatted financial report containing executive summaries, category charts, and period breakdowns.\n'
              '• Excel (.xlsx / .csv): Exports raw data tables ready for accounting software or tax filing.',
        ),
      ],
    ),
    _GuideSection(
      id: 'contacts',
      title: '6. Contacts & Ledger Management',
      icon: Icons.contacts_rounded,
      tag: 'Contacts',
      summary: 'Organize customers and suppliers with instant balance lookups.',
      items: [
        _GuideItem(
          title: 'Search & Filtering',
          content:
              '• Search Bar: Type any portion of a contact name or mobile number for instant live filtering.\n'
              '• Segmented Tabs: Switch seamlessly between Buyers (Grahak) and Suppliers (Bypari).',
        ),
        _GuideItem(
          title: 'Understanding Balance Indicators',
          content:
              '• Green (Receivable / Baki): The contact owes money to you (+₹).\n'
              '• Red (Payable / Dena): You owe money to the contact (−₹).\n'
              '• Overdue Badge: Highlighted with an alert icon if a repayment has crossed its due date.',
        ),
      ],
    ),
    _GuideSection(
      id: 'notifications',
      title: '7. Message & Share Templates',
      icon: Icons.sms_outlined,
      tag: 'Messaging',
      summary: 'Customize WhatsApp & SMS vouchers sent to customers.',
      items: [
        _GuideItem(
          title: 'Multi-Language Support',
          content:
              'Templates are available in three formats:\n'
              '• English\n'
              '• हिंदी (Hindi)\n'
              '• Hinglish',
        ),
        _GuideItem(
          title: 'Dynamic Placeholders',
          content:
              'Tap any placeholder chip to insert dynamic tags that get replaced with real data when sharing:\n'
              '• {contact_name}: Party name\n'
              '• {amount}: Transaction or loan amount\n'
              '• {date}: Transaction date\n'
              '• {total_balance}: Outstanding balance\n'
              '• {memo_line}: Reference memo',
        ),
        _GuideItem(
          title: 'Live Formatted Preview',
          content:
              'A live WhatsApp chat bubble preview shows exactly how the message will look to your recipient before saving.',
        ),
      ],
    ),
    _GuideSection(
      id: 'settings',
      title: '8. App Settings & Customization',
      icon: Icons.settings_rounded,
      tag: 'Preferences',
      summary: 'Tailor currency, financial years, categories, and payment modes.',
      items: [
        _GuideItem(
          title: 'Appearance & Themes',
          content:
              '• Default Theme: Starts in clean Light Mode.\n'
              '• Options: Switch between Light, Dark, or System Mode at any time in Settings.',
        ),
        _GuideItem(
          title: 'Financial Configuration',
          content:
              '• Currency Symbol: Default ₹ (INR).\n'
              '• Numbering Format: Indian numbering system (Lakhs & Crores grouping).\n'
              '• Financial Year Start: Choose April 1 (Indian FY) or January 1 (Calendar Year).\n'
              '• GST Calculation: Enable optional GST calculation with custom tax rates (default 18%).',
        ),
        _GuideItem(
          title: 'Category & Payment Mode Management',
          content:
              '• Category Engine: Add custom income and expense categories with custom icons and colors.\n'
              '• Payment Modes: Configure Cash, Bank Accounts, and UPI IDs for transaction logging.',
        ),
        _GuideItem(
          title: 'Audit Logs',
          content:
              'Review a chronological history of create, update, and delete actions for auditing and accountability.',
        ),
      ],
    ),
    _GuideSection(
      id: 'security',
      title: '9. Security & Privacy',
      icon: Icons.security_rounded,
      tag: 'Privacy',
      summary: 'Local-first offline architecture protecting your ledger.',
      items: [
        _GuideItem(
          title: '100% Offline & Local-First',
          content:
              'Your financial data is stored directly on your device inside a local database (SQLite/Hive). It is never sent to external servers or sold to third parties.',
        ),
        _GuideItem(
          title: 'Biometric Lock (Face ID / Fingerprint)',
          content:
              '• Supported Native Devices: Protect app access with device biometric authentication (Face ID, Touch ID, or Android Fingerprint).\n'
              '• Background Lock: Automatically re-locks the app after being idle in the background.\n'
              '• Browser Testing Bypass: The web version bypasses biometrics for manual testing.',
        ),
      ],
    ),
    _GuideSection(
      id: 'data_safety',
      title: '10. Data Safety & Export',
      icon: Icons.save_alt_rounded,
      tag: 'Exports',
      summary: 'Safeguard and export your records on demand.',
      items: [
        _GuideItem(
          title: 'On-Demand Document Exports',
          content:
              '• PDF Ledger Statements: Generate shareable, itemized statement sheets for any individual party.\n'
              '• Comprehensive Reports: Export multi-page financial statements via PDF or Excel from the Reports tab.\n'
              '• Permanent Local Storage: All entries persist locally across app restarts and updates.',
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= AppConstants.tabletBreakpoint;

    final filtered = _searchQuery.trim().isEmpty
        ? _allSections
        : _allSections.where((section) {
            final q = _searchQuery.toLowerCase();
            final matchesTitle = section.title.toLowerCase().contains(q);
            final matchesSummary = section.summary.toLowerCase().contains(q);
            final matchesTag = section.tag.toLowerCase().contains(q);
            final matchesItems = section.items.any((item) =>
                item.title.toLowerCase().contains(q) ||
                item.content.toLowerCase().contains(q));
            return matchesTitle || matchesSummary || matchesTag || matchesItems;
          }).toList();

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'User Guide',
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isWide ? 960 : double.infinity),
          child: ListView(
            padding: EdgeInsets.all(AppSpacing.lg.w),
            children: [
              // Header Card
              Container(
                padding: EdgeInsets.all(AppSpacing.lg.w),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primaryDark,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16.r),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(10.w),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Icon(
                            Icons.menu_book_rounded,
                            color: Colors.white,
                            size: 24.r,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PAMZ Hisab User Guide',
                                style: TextStyle(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                'Learn how to use every feature of your financial ledger',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: AppSpacing.md.h),

              // Search Bar
              TextField(
                controller: _searchCtrl,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search guide topics (e.g. Jama, Udhar, Budget, Reports)...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  filled: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                ),
              ),
              SizedBox(height: AppSpacing.lg.h),

              if (filtered.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl.h),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off_rounded, size: 48.r, color: AppColors.textDisabled),
                        SizedBox(height: AppSpacing.sm.h),
                        Text(
                          'No matching guide topics found',
                          style: AppTextStyles.h3,
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'Try searching with a different keyword.',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...filtered.map((section) => _buildSectionCard(context, section)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(BuildContext context, _GuideSection section) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.md.h),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: _searchQuery.isNotEmpty,
            leading: CircleAvatar(
              radius: 20.r,
              backgroundColor: AppColors.primaryLight.withValues(alpha: 0.2),
              child: Icon(section.icon, color: AppColors.primary, size: 20.r),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    section.title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    section.tag,
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: EdgeInsets.only(top: 2.h),
              child: Text(
                section.summary,
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              ),
            ),
            children: [
              const Divider(height: 1),
              Padding(
                padding: EdgeInsets.all(AppSpacing.md.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: section.items.map((item) {
                    return Padding(
                      padding: EdgeInsets.only(bottom: AppSpacing.sm.h),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(AppSpacing.sm.w),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(
                            color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              item.content,
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontSize: 12.sp,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuideSection {
  const _GuideSection({
    required this.id,
    required this.title,
    required this.icon,
    required this.tag,
    required this.summary,
    required this.items,
  });

  final String id;
  final String title;
  final IconData icon;
  final String tag;
  final String summary;
  final List<_GuideItem> items;
}

class _GuideItem {
  const _GuideItem({
    required this.title,
    required this.content,
  });

  final String title;
  final String content;
}
