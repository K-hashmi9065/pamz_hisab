import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pamz_khata/feature/family_finance/domain/entities/family_transaction.dart';
import 'package:pamz_khata/feature/family_finance/presentation/providers/family_finance_providers.dart';
import 'package:pamz_khata/feature/settings/presentation/screens/category_config_screen.dart';
import 'package:pamz_khata/feature/settings/presentation/screens/settings_screen.dart';
import 'package:pamz_khata/shared/widgets/app_button.dart';

import '../../test_helpers/mocks.dart';
import '../../test_helpers/pump_app.dart';

void main() {
  setUpAll(registerFallbacks);

  final testIncomeCategories = [
    const TransactionCategory(
      id: 'cat_sal',
      domain: 'income',
      name: 'Salary',
      iconKey: '💼',
      colorHex: '#4CAF50',
      isSystemPreset: true,
      sortOrder: 1,
      isDeleted: false,
    ),
    const TransactionCategory(
      id: 'cat_custom_inc',
      domain: 'income',
      name: 'Agricultural Yield Sales',
      iconKey: '🌾',
      colorHex: '#8BC34A',
      isSystemPreset: false,
      sortOrder: 2,
      isDeleted: false,
    ),
  ];

  final testExpenseCategories = [
    const TransactionCategory(
      id: 'cat_groc',
      domain: 'expense',
      name: 'Groceries & Ration',
      iconKey: '🛒',
      colorHex: '#F44336',
      isSystemPreset: true,
      sortOrder: 1,
      isDeleted: false,
    ),
  ];

  group('CategoryConfigScreen Widget Tests', () {
    late MockFamilyFinanceRepository mockRepo;

    setUp(() {
      mockRepo = MockFamilyFinanceRepository();
      when(() => mockRepo.getCategories(domain: any(named: 'domain')))
          .thenAnswer((inv) async {
        final domain = inv.namedArguments[#domain] as String?;
        if (domain == 'income') return right(testIncomeCategories);
        if (domain == 'expense') return right(testExpenseCategories);
        return right([...testIncomeCategories, ...testExpenseCategories]);
      });
    });

    List<Override> buildOverrides() {
      return [
        familyFinanceRepositoryProvider.overrideWithValue(mockRepo),
        categoriesProvider('income').overrideWith((ref) async => testIncomeCategories),
        categoriesProvider('expense').overrideWith((ref) async => testExpenseCategories),
      ];
    }

    testWidgets('1. Renders CategoryConfigScreen with Income tabs, categories and Preset/Custom badges', (tester) async {
      await pumpApp(
        tester,
        const CategoryConfigScreen(),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Manage Categories'), findsOneWidget);
      expect(find.text('Income Categories'), findsOneWidget);
      expect(find.text('Expense Categories'), findsOneWidget);
      expect(find.text('Salary'), findsOneWidget);
      expect(find.text('Agricultural Yield Sales'), findsOneWidget);
      expect(find.text('SYSTEM'), findsOneWidget);
      expect(find.text('Custom user category'), findsOneWidget);
    });

    testWidgets('2. Tab switching shows Expense categories', (tester) async {
      await pumpApp(
        tester,
        const CategoryConfigScreen(),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      // Tap Expense Tab
      await tester.tap(find.text('Expense Categories'));
      await tester.pumpAndSettle();

      expect(find.text('Groceries & Ration'), findsOneWidget);
      expect(find.text('SYSTEM'), findsOneWidget);
    });

    testWidgets('3. Add Category sheet validates empty name and calls createCategory', (tester) async {
      when(() => mockRepo.createCategory(any()))
          .thenAnswer((inv) async => right(inv.positionalArguments.first as TransactionCategory));

      await pumpApp(
        tester,
        const CategoryConfigScreen(),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      // Tap Add button
      await tester.tap(find.byTooltip('Add Category'));
      await tester.pumpAndSettle();

      expect(find.text('Add Category'), findsWidgets);
      expect(find.text('Save Category'), findsOneWidget);

      // Attempt submit empty
      await tester.tap(find.text('Save Category'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter category name'), findsOneWidget);

      // Enter name
      await tester.enterText(find.byType(TextFormField).first, 'Property Rent');
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.text('Save Category'));
      await tester.pumpAndSettle();

      verify(() => mockRepo.createCategory(any())).called(1);
    });

    testWidgets('4. Edit Category sheet pre-populates name & icon and calls updateCategory', (tester) async {
      when(() => mockRepo.updateCategory(any()))
          .thenAnswer((inv) async => right(inv.positionalArguments.first as TransactionCategory));

      await pumpApp(
        tester,
        const CategoryConfigScreen(),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      // Tap edit on the custom category
      final editBtn = find.byTooltip('Edit Category').first;
      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      expect(find.text('Edit Category'), findsWidgets);
      expect(find.text('Update Category'), findsOneWidget);
      expect(find.text('Agricultural Yield Sales'), findsWidgets);

      // Change name
      await tester.enterText(find.byType(TextFormField).first, 'Crop Harvest Sales');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Update Category'));
      await tester.pumpAndSettle();

      verify(() => mockRepo.updateCategory(any())).called(1);
    });

    testWidgets('5. Delete Category confirmation dialog prompts and invokes deleteCategory', (tester) async {
      when(() => mockRepo.deleteCategory(any()))
          .thenAnswer((_) async => right(null));

      await pumpApp(
        tester,
        const CategoryConfigScreen(),
        overrides: buildOverrides(),
      );
      await tester.pumpAndSettle();

      // Tap delete on the custom category
      final deleteBtn = find.byTooltip('Delete Category').first;
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      expect(find.text('Delete Category'), findsOneWidget);
      expect(find.textContaining('Past transactions will retain this category name'), findsOneWidget);

      // Confirm delete
      final confirmDelete = find.widgetWithText(AppButton, 'Delete');
      await tester.tap(confirmDelete);
      await tester.pumpAndSettle();

      verify(() => mockRepo.deleteCategory(testIncomeCategories[1].id)).called(1);
    });
  });

  group('SettingsScreen System Configurability Widget Tests', () {
    testWidgets('6. Settings screen renders App Configuration and opens Currency & Fiscal Year pickers', (tester) async {
      await pumpApp(
        tester,
        const SettingsScreen(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('APP CONFIGURATION'), findsOneWidget);
      expect(find.text('Currency & Numbering'), findsOneWidget);
      expect(find.text('Fiscal Year Start'), findsOneWidget);
      expect(find.text('GST Settings'), findsOneWidget);
      expect(find.text('Categories'), findsOneWidget);

      // Tap Currency & Numbering
      await tester.tap(find.text('Currency & Numbering'));
      await tester.pumpAndSettle();

      expect(find.text('Currency Symbol'), findsOneWidget);
      expect(find.text('Numbering Presentation'), findsOneWidget);
      expect(find.text('Standard (Millions & Billions)'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // Tap Fiscal Year Start
      await tester.tap(find.text('Fiscal Year Start'));
      await tester.pumpAndSettle();

      expect(find.text('Fiscal Year Start Month'), findsOneWidget);
      expect(find.text('April 1'), findsOneWidget);
      expect(find.text('January 1'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Tap GST Settings
      await tester.tap(find.text('GST Settings'));
      await tester.pumpAndSettle();

      expect(find.text('GST Configuration'), findsOneWidget);
      expect(find.text('Enable GST on Invoices'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });
  });
}
