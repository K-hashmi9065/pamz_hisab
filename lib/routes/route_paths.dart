/// Route path constants for GoRouter.
abstract final class RoutePaths {
  RoutePaths._();

  static const String lock = '/lock';
  static const String dashboard = '/dashboard';
  static const String udharList = '/udhar';
  static const String contactLedger = 'contact/:contactId'; // relative
  static const String directUdharNew = 'direct/new';        // relative
  static const String familyFinance = '/family';
  static const String reports = '/reports';
  static const String userGuide = '/user-guide';
  static const String settings = '/settings';
  static const String categoryConfig = 'categories';
  static const String budget = 'budget';
  static const String notificationTemplates = 'templates';
  static const String paymentModes = 'payment-modes';
  static const String auditLog = 'audit-log';
}
