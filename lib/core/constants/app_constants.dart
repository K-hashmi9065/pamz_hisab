/// App-wide constants for PAMZ Hisab.
class AppConstants {
  AppConstants._();

  // --- App Identity ---
  static const String appName = 'PAMZ Hisab';
  static const String appVersion = '1.1.0';

  // --- Database ---
  static const String dbName = 'pamz_hisab.db';
  static const int dbVersion = 5;

  // --- Hive Box Names ---
  static const String settingsBox = 'settings_box';
  static const String templatesBox = 'templates_box';
  static const String appLockBox = 'app_lock_box';
  static const String sessionBox = 'session_box';
  static const String draftBox = 'draft_box';
  static const String contactsBox = 'contacts_box';
  static const String directUdharBox = 'direct_udhar_box';
  static const String repaymentsBox = 'repayments_box';
  static const String categoriesBox = 'categories_box';
  static const String accountsBox = 'accounts_box';
  static const String familyTransactionsBox = 'family_transactions_box';
  static const String monthlySummaryBox = 'monthly_summary_box';
  static const String budgetsBox = 'budgets_box';
  static const String auditLogBox = 'audit_log_box';
  static const String familyUtilizationsBox = 'family_utilizations_box';

  // --- Fund Ledger Hive Boxes ---
  static const String flContactsBox = 'fl_contacts_box';
  static const String flTransactionsBox = 'fl_transactions_box';

  // --- Secure Storage Keys ---
  static const String dbEncryptionKeyStorageKey = 'pamz_db_enc_key';

  // --- ScreenUtil Design Size (11-inch iPad landscape) ---
  static const double designWidth = 1180.0;
  static const double designHeight = 820.0;

  // --- Layout Breakpoints ---
  static const double tabletBreakpoint = 840.0; // 3-pane above, collapsed below

  // --- Pagination ---
  static const int defaultPageSize = 30;

  // --- Biometric ---
  static const int lockTimeoutSeconds = 300; // 5 minutes

  // --- Indian Number Formatting ---
  static const String currencySymbol = '₹';

  // --- Date Formats ---
  static const String displayDateFormat = 'dd MMM yyyy';
  static const String monthYearFormat = 'MMM yyyy';
  static const String iso8601Format = 'yyyy-MM-dd';
  static const String monthKey = 'yyyy-MM'; // for monthly_summary

  // --- Seeded Payment Modes ---
  static const List<Map<String, String>> defaultPaymentModes = [
    {'code': 'cash', 'label': 'Cash'},
    {'code': 'upi', 'label': 'UPI'},
    {'code': 'bank_transfer', 'label': 'Bank Transfer'},
    {'code': 'cheque', 'label': 'Cheque'},
  ];
}
