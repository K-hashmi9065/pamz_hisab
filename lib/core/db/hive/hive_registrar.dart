import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../../constants/app_constants.dart';

/// Manages all Hive box initialization and registration.
class HiveRegistrar {
  HiveRegistrar._();

  /// Call this in main() before runApp(), or pass custom path in unit tests.
  static Future<void> initialize([String? path]) async {
    if (path != null) {
      Hive.init(path);
    } else if (kIsWeb) {
      await Hive.initFlutter();
    } else {
      final appSupportDir = await getApplicationSupportDirectory();
      final hiveDir = Directory('${appSupportDir.path}/hive_db');
      if (!await hiveDir.exists()) {
        await hiveDir.create(recursive: true);
      }
      Hive.init(hiveDir.path);
    }
    await _openBoxes();
    await _seedDefaults();
  }

  static Future<void> _openBoxes() async {
    // App state & settings boxes
    await Hive.openBox<dynamic>(AppConstants.settingsBox);
    await Hive.openBox<dynamic>(AppConstants.appLockBox);
    await Hive.openBox<dynamic>(AppConstants.sessionBox);
    await Hive.openLazyBox<dynamic>(AppConstants.templatesBox);
    await Hive.openLazyBox<dynamic>(AppConstants.draftBox);

    // Entity boxes
    await Hive.openBox<dynamic>(AppConstants.contactsBox);
    await Hive.openBox<dynamic>(AppConstants.directUdharBox);
    await Hive.openBox<dynamic>(AppConstants.repaymentsBox);
    await Hive.openBox<dynamic>(AppConstants.categoriesBox);
    await Hive.openBox<dynamic>(AppConstants.accountsBox);
    await Hive.openBox<dynamic>(AppConstants.familyTransactionsBox);
    await Hive.openBox<dynamic>(AppConstants.monthlySummaryBox);
    await Hive.openBox<dynamic>(AppConstants.budgetsBox);
    await Hive.openBox<dynamic>(AppConstants.auditLogBox);

    // Fund Ledger & Family Utilization boxes
    await Hive.openBox<dynamic>(AppConstants.flContactsBox);
    await Hive.openBox<dynamic>(AppConstants.flTransactionsBox);
    await Hive.openBox<dynamic>(AppConstants.familyUtilizationsBox);
  }

  static Future<void> _seedDefaults() async {
    // Seed Categories if empty
    final catBox = categoriesBox;
    if (catBox.isEmpty) {
      final incomePresets = [
        {'id': 'cat_sal', 'domain': 'income', 'name': 'Salary', 'icon_key': '💼', 'color_hex': '#4CAF50', 'is_system_preset': 1, 'sort_order': 0, 'is_deleted': 0},
        {'id': 'cat_agri', 'domain': 'income', 'name': 'Agricultural Yield', 'icon_key': '🌾', 'color_hex': '#8BC34A', 'is_system_preset': 1, 'sort_order': 0, 'is_deleted': 0},
        {'id': 'cat_biz', 'domain': 'income', 'name': 'Business/Shop Earnings', 'icon_key': '🏪', 'color_hex': '#2196F3', 'is_system_preset': 1, 'sort_order': 0, 'is_deleted': 0},
        {'id': 'cat_rent', 'domain': 'income', 'name': 'Property Rent', 'icon_key': '🏠', 'color_hex': '#9C27B0', 'is_system_preset': 1, 'sort_order': 0, 'is_deleted': 0},
        {'id': 'cat_remit', 'domain': 'income', 'name': 'Remittances', 'icon_key': '💸', 'color_hex': '#FF9800', 'is_system_preset': 1, 'sort_order': 0, 'is_deleted': 0},
        {'id': 'cat_int', 'domain': 'income', 'name': 'Loan Interest Income', 'icon_key': '📈', 'color_hex': '#00BCD4', 'is_system_preset': 1, 'sort_order': 0, 'is_deleted': 0},
      ];
      final expensePresets = [
        {'id': 'cat_groc', 'domain': 'expense', 'name': 'Groceries & Ration', 'icon_key': '🛒', 'color_hex': '#F44336', 'is_system_preset': 1, 'sort_order': 0, 'is_deleted': 0},
        {'id': 'cat_agri_in', 'domain': 'expense', 'name': 'Agriculture Inputs', 'icon_key': '🌱', 'color_hex': '#4CAF50', 'is_system_preset': 1, 'sort_order': 0, 'is_deleted': 0},
        {'id': 'cat_edu', 'domain': 'expense', 'name': 'Education & Tuition', 'icon_key': '📚', 'color_hex': '#3F51B5', 'is_system_preset': 1, 'sort_order': 0, 'is_deleted': 0},
        {'id': 'cat_health', 'domain': 'expense', 'name': 'Healthcare', 'icon_key': '🏥', 'color_hex': '#E91E63', 'is_system_preset': 1, 'sort_order': 0, 'is_deleted': 0},
        {'id': 'cat_util', 'domain': 'expense', 'name': 'Utilities', 'icon_key': '⚡', 'color_hex': '#FF5722', 'is_system_preset': 1, 'sort_order': 0, 'is_deleted': 0},
        {'id': 'cat_trans', 'domain': 'expense', 'name': 'Transportation', 'icon_key': '🚗', 'color_hex': '#607D8B', 'is_system_preset': 1, 'sort_order': 0, 'is_deleted': 0},
        {'id': 'cat_debt', 'domain': 'expense', 'name': 'Debt Repayments', 'icon_key': '💳', 'color_hex': '#795548', 'is_system_preset': 1, 'sort_order': 0, 'is_deleted': 0},
      ];

      for (final cat in [...incomePresets, ...expensePresets]) {
        await catBox.put(cat['id'], cat);
      }
    }

    // Seed Accounts if empty
    final accBox = accountsBox;
    if (accBox.isEmpty) {
      await accBox.put('acc_cash', {'id': 'acc_cash', 'name': 'Cash', 'type': 'cash', 'is_deleted': 0});
      await accBox.put('acc_bank', {'id': 'acc_bank', 'name': 'Bank Account', 'type': 'bank', 'is_deleted': 0});
    }
  }

  // Getters for boxes
  static Box<dynamic> get settingsBox => Hive.box<dynamic>(AppConstants.settingsBox);
  static Box<dynamic> get appLockBox => Hive.box<dynamic>(AppConstants.appLockBox);
  static Box<dynamic> get sessionBox => Hive.box<dynamic>(AppConstants.sessionBox);
  static LazyBox<dynamic> get templatesBox => Hive.lazyBox<dynamic>(AppConstants.templatesBox);
  static LazyBox<dynamic> get draftBox => Hive.lazyBox<dynamic>(AppConstants.draftBox);

  static Box<dynamic> get contactsBox => Hive.box<dynamic>(AppConstants.contactsBox);
  static Box<dynamic> get directUdharBox => Hive.box<dynamic>(AppConstants.directUdharBox);
  static Box<dynamic> get repaymentsBox => Hive.box<dynamic>(AppConstants.repaymentsBox);
  static Box<dynamic> get categoriesBox => Hive.box<dynamic>(AppConstants.categoriesBox);
  static Box<dynamic> get accountsBox => Hive.box<dynamic>(AppConstants.accountsBox);
  static Box<dynamic> get familyTransactionsBox => Hive.box<dynamic>(AppConstants.familyTransactionsBox);
  static Box<dynamic> get monthlySummaryBox => Hive.box<dynamic>(AppConstants.monthlySummaryBox);
  static Box<dynamic> get budgetsBox => Hive.box<dynamic>(AppConstants.budgetsBox);
  static Box<dynamic> get auditLogBox => Hive.box<dynamic>(AppConstants.auditLogBox);

  // Fund Ledger & Family Utilization boxes
  static Box<dynamic> get flContactsBox => Hive.box<dynamic>(AppConstants.flContactsBox);
  static Box<dynamic> get flTransactionsBox => Hive.box<dynamic>(AppConstants.flTransactionsBox);
  static Box<dynamic> get familyUtilizationsBox => Hive.box<dynamic>(AppConstants.familyUtilizationsBox);
}
