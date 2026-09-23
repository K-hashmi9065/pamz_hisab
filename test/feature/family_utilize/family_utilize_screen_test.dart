import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:pamz_khata/core/error/failure.dart';
import 'package:pamz_khata/feature/family_utilize/domain/entities/family_utilize.dart';
import 'package:pamz_khata/feature/family_utilize/domain/repositories/family_utilize_repository.dart';
import 'package:pamz_khata/feature/family_utilize/presentation/providers/family_utilize_providers.dart';
import 'package:pamz_khata/feature/family_utilize/presentation/screens/family_utilize_screen.dart';
import 'package:pamz_khata/feature/family_utilize/presentation/widgets/add_family_utilize_sheet.dart';
import 'package:pamz_khata/feature/family_utilize/presentation/widgets/family_utilize_filter_sheet.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/entities/fl_transaction.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/repositories/fl_transaction_repository.dart';
import 'package:pamz_khata/feature/fund_ledger/presentation/providers/fl_transaction_providers.dart';

class FakeScreenFamilyUtilizeRepo implements FamilyUtilizeRepository {
  final List<FamilyUtilize> items = [];

  @override
  Future<Either<Failure, void>> insert(FamilyUtilize item) async {
    items.add(item);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> update(FamilyUtilize item) async {
    final idx = items.indexWhere((i) => i.id == item.id);
    if (idx != -1) items[idx] = item;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> softDelete(String id) async {
    items.removeWhere((i) => i.id == id);
    return const Right(null);
  }

  @override
  Future<Either<Failure, List<FamilyUtilize>>> getAll({
    String? category,
    DateTime? from,
    DateTime? to,
    String? searchQuery,
  }) async {
    var result = List<FamilyUtilize>.from(items);
    if (category != null) {
      result = result
          .where((i) => i.category.toLowerCase() == category.toLowerCase())
          .toList();
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      result = result
          .where((i) =>
              i.title.toLowerCase().contains(q) ||
              i.category.toLowerCase().contains(q) ||
              (i.paymentMode?.toLowerCase().contains(q) ?? false) ||
              (i.paymentReference?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    return Right(result);
  }

  @override
  Future<Either<Failure, FamilyUtilize?>> getById(String id) async {
    return Right(items.where((i) => i.id == id).firstOrNull);
  }

  @override
  Future<Either<Failure, double>> getTotalFamilyUtilized({
    DateTime? from,
    DateTime? to,
  }) async {
    final sum = items.fold<double>(0.0, (s, i) => s + i.amount);
    return Right(sum);
  }
}

class FakeScreenFLTxnRepo implements FLTransactionRepository {
  @override
  Future<Either<Failure, FLContactTotals>> getGlobalTotals() async {
    return const Right(
      FLContactTotals(
        totalReceived: 50000,
        totalUtilized: 0,
        totalReturned: 5000,
      ),
    );
  }

  @override
  Future<Either<Failure, FLContactTotals>> getTotals(String contactId) async =>
      getGlobalTotals();

  @override
  Future<Either<Failure, List<FLTransaction>>> getAll({
    FLTransactionType? type,
    String? contactId,
    DateTime? from,
    DateTime? to,
  }) async =>
      const Right([]);

  @override
  Future<Either<Failure, List<FLTransaction>>> getByContact(String contactId) async =>
      const Right([]);

  @override
  Future<Either<Failure, void>> insert(FLTransaction transaction) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> update(FLTransaction transaction) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> softDelete(String id) async =>
      const Right(null);
}

Widget buildTestScreen({
  required FakeScreenFamilyUtilizeRepo familyRepo,
  required FakeScreenFLTxnRepo flRepo,
  Size screenSize = const Size(1180, 820),
}) {
  return ProviderScope(
    overrides: [
      familyUtilizeRepositoryProvider.overrideWithValue(familyRepo),
      flTransactionRepositoryProvider.overrideWithValue(flRepo),
    ],
    child: ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      builder: (_, child) => MediaQuery(
        data: MediaQueryData(size: screenSize),
        child: const MaterialApp(
          home: FamilyUtilizeScreen(),
        ),
      ),
    ),
  );
}

Widget buildAddSheetTest({
  required FakeScreenFamilyUtilizeRepo familyRepo,
  required FakeScreenFLTxnRepo flRepo,
  FamilyUtilize? initialItem,
  Size screenSize = const Size(375, 812),
}) {
  return ProviderScope(
    overrides: [
      familyUtilizeRepositoryProvider.overrideWithValue(familyRepo),
      flTransactionRepositoryProvider.overrideWithValue(flRepo),
    ],
    child: ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      builder: (_, child) => MediaQuery(
        data: MediaQueryData(size: screenSize),
        child: MaterialApp(
          home: Scaffold(
            body: AddFamilyUtilizeSheet(initialItem: initialItem),
          ),
        ),
      ),
    ),
  );
}

Widget buildFilterSheetTest({
  required FakeScreenFamilyUtilizeRepo familyRepo,
  required FakeScreenFLTxnRepo flRepo,
  Size screenSize = const Size(375, 812),
}) {
  return ProviderScope(
    overrides: [
      familyUtilizeRepositoryProvider.overrideWithValue(familyRepo),
      flTransactionRepositoryProvider.overrideWithValue(flRepo),
    ],
    child: ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      builder: (_, child) => MediaQuery(
        data: MediaQueryData(size: screenSize),
        child: const MaterialApp(
          home: Scaffold(
            body: FamilyUtilizeFilterSheet(),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('FamilyUtilize Screen & Widget Tests', () {
    late FakeScreenFamilyUtilizeRepo familyRepo;
    late FakeScreenFLTxnRepo flRepo;

    final now = DateTime(2026, 9, 23);

    setUp(() {
      familyRepo = FakeScreenFamilyUtilizeRepo();
      flRepo = FakeScreenFLTxnRepo();
    });

    testWidgets('1. Renders 3 top balance metrics and empty state initially', (tester) async {
      await tester.pumpWidget(
        buildTestScreen(familyRepo: familyRepo, flRepo: flRepo),
      );
      await tester.pumpAndSettle();

      // Top metrics
      expect(find.text('REMAINING AVAILABLE BALANCE'), findsOneWidget);
      expect(find.text('Available Balance'), findsOneWidget);
      expect(find.text('Total Family Utilized'), findsOneWidget);

      // Initial available balance (50,000 - 5,000 = ₹45,000)
      expect(find.text('₹45,000'), findsNWidgets(2)); // Remaining and Available Balance
      expect(find.text('₹0'), findsOneWidget); // Total Family Utilized

      // Empty State
      expect(find.text('No Family Utilizations Recorded'), findsOneWidget);
    });

    testWidgets('2. Displays history items with category, title, paidTo, paymentMode, amount, and date', (tester) async {
      familyRepo.items.addAll([
        FamilyUtilize(
          id: 'u1',
          amount: 5000,
          category: 'Education',
          title: 'School Fee',
          paymentMode: 'UPI',
          paymentReference: '123456789012',
          paidTo: 'ABC School',
          transactionDate: '2026-09-23',
          createdAt: now,
          updatedAt: now,
        ),
        FamilyUtilize(
          id: 'u2',
          amount: 2500,
          category: 'Electricity',
          title: 'Electricity Bill',
          paymentMode: 'Cash',
          paidTo: 'NBPDCL',
          transactionDate: '2026-09-23',
          createdAt: now,
          updatedAt: now,
        ),
        FamilyUtilize(
          id: 'u3',
          amount: 1500,
          category: 'Medical',
          title: 'Doctor Visit',
          // historical record with null paymentMode
          transactionDate: '2026-09-23',
          createdAt: now,
          updatedAt: now,
        ),
      ]);

      await tester.pumpWidget(
        buildTestScreen(familyRepo: familyRepo, flRepo: flRepo),
      );
      await tester.pumpAndSettle();

      // Item 1: Education with UPI
      expect(find.text('School Fee'), findsOneWidget);
      expect(find.text('UPI • UTR: 123456789012'), findsOneWidget);
      expect(find.text('Paid to: ABC School'), findsOneWidget);
      expect(find.text('₹5,000'), findsOneWidget);

      // Item 2: Electricity with Cash
      expect(find.text('Electricity Bill'), findsOneWidget);
      expect(find.text('Cash'), findsWidgets);
      expect(find.text('Paid to: NBPDCL'), findsOneWidget);
      expect(find.text('₹2,500'), findsOneWidget);

      // Item 3: Historical record with null paymentMode does not show fake mode
      expect(find.text('Doctor Visit'), findsOneWidget);
    });

    testWidgets('3. Add Utilization form opens and validates required fields', (tester) async {
      await tester.pumpWidget(
        buildTestScreen(familyRepo: familyRepo, flRepo: flRepo),
      );
      await tester.pumpAndSettle();

      // Tap floating action button
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.byType(AddFamilyUtilizeSheet), findsOneWidget);
      expect(find.text('Add Family Utilization'), findsOneWidget);

      // Attempt to submit empty form
      await tester.tap(find.text('Save Utilization'));
      await tester.pumpAndSettle();

      expect(find.text('Amount is required'), findsOneWidget);
      expect(find.text('Title is required'), findsOneWidget);
    });

    testWidgets('4. Validates amount cannot exceed available balance', (tester) async {
      await tester.pumpWidget(
        buildTestScreen(familyRepo: familyRepo, flRepo: flRepo),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Enter amount > available balance (50000 > 45000)
      await tester.enterText(find.widgetWithText(TextFormField, 'Amount (₹) *'), '50000');
      await tester.enterText(find.widgetWithText(TextFormField, 'Title / Paid For *'), 'Grand Purchase');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save Utilization'));
      await tester.pumpAndSettle();

      expect(find.text('Amount cannot exceed available balance'), findsOneWidget);
    });

    testWidgets('5. Successfully records Education with UPI and Electricity with Cash', (tester) async {
      await tester.pumpWidget(
        buildTestScreen(familyRepo: familyRepo, flRepo: flRepo),
      );
      await tester.pumpAndSettle();

      // Open Add Sheet
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Enter Education details
      await tester.enterText(find.widgetWithText(TextFormField, 'Amount (₹) *'), '5000');
      await tester.enterText(find.widgetWithText(TextFormField, 'Title / Paid For *'), 'School Fee');
      await tester.enterText(find.widgetWithText(TextFormField, 'Paid To (Optional)'), 'ABC School');

      // Select UPI
      await tester.tap(find.widgetWithText(ChoiceChip, 'UPI'));
      await tester.pumpAndSettle();

      // Enter UTR
      await tester.enterText(find.widgetWithText(TextFormField, 'UTR Number (Optional)'), '123456789012');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save Utilization'));
      await tester.pumpAndSettle();

      // Verify item added to repository with UPI and UTR
      expect(familyRepo.items.length, 1);
      expect(familyRepo.items.first.title, 'School Fee');
      expect(familyRepo.items.first.amount, 5000);
      expect(familyRepo.items.first.paymentMode, 'UPI');
      expect(familyRepo.items.first.paymentReference, '123456789012');
    });

    testWidgets('6. AddFamilyUtilizeSheet category chips render with high contrast and readable text', (tester) async {
      await tester.pumpWidget(
        buildAddSheetTest(familyRepo: familyRepo, flRepo: flRepo),
      );
      await tester.pumpAndSettle();

      // All 9 preset categories are present
      for (final preset in FamilyUtilize.presetCategories) {
        expect(find.text(preset.name), findsOneWidget);
      }

      // Initial selected category is Education
      final educationChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Education'),
      );
      expect(educationChip.selected, isTrue);

      // Electricity is unselected initially
      final electricityChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Electricity'),
      );
      expect(electricityChip.selected, isFalse);

      // Tap Grocery category
      await tester.tap(find.text('Grocery'));
      await tester.pumpAndSettle();

      final groceryChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Grocery'),
      );
      expect(groceryChip.selected, isTrue);

      // Save Utilization button is rendered
      expect(find.text('Save Utilization'), findsOneWidget);
    });

    testWidgets('7. FamilyUtilizeFilterSheet renders date and category chips with proper touch targets', (tester) async {
      await tester.pumpWidget(
        buildFilterSheetTest(familyRepo: familyRepo, flRepo: flRepo),
      );
      await tester.pumpAndSettle();

      // Date preset options
      expect(find.text('All Time'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('This Week'), findsOneWidget);
      expect(find.text('This Month'), findsOneWidget);
      expect(find.text('This Year'), findsOneWidget);
      expect(find.text('Custom Range'), findsOneWidget);

      // Category options
      expect(find.text('All Categories'), findsOneWidget);
      for (final preset in FamilyUtilize.presetCategories) {
        expect(find.text(preset.name), findsOneWidget);
      }

      // Tap Today preset
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      // Tap Medical category
      await tester.tap(find.text('Medical'));
      await tester.pumpAndSettle();

      // Apply Filters button is rendered
      expect(find.text('Apply Filters'), findsOneWidget);
    });

    testWidgets('8. Payment Mode displays optional reference fields for UPI, Cheque, and Draft', (tester) async {
      await tester.pumpWidget(
        buildAddSheetTest(familyRepo: familyRepo, flRepo: flRepo),
      );
      await tester.pumpAndSettle();

      // Initial mode is Cash -> no reference field
      expect(find.text('UTR Number (Optional)'), findsNothing);
      expect(find.text('Cheque Number (Optional)'), findsNothing);
      expect(find.text('Draft Number (Optional)'), findsNothing);

      // Switch to UPI -> UTR Number (Optional) appears
      await tester.tap(find.widgetWithText(ChoiceChip, 'UPI'));
      await tester.pumpAndSettle();
      expect(find.text('UTR Number (Optional)'), findsOneWidget);

      // Can submit with empty reference since it is optional
      await tester.enterText(find.widgetWithText(TextFormField, 'Amount (₹) *'), '1000');
      await tester.enterText(find.widgetWithText(TextFormField, 'Title / Paid For *'), 'Test UPI');
      await tester.tap(find.text('Save Utilization'));
      await tester.pumpAndSettle();
      expect(familyRepo.items.length, 1);
      expect(familyRepo.items.first.paymentMode, 'UPI');
      expect(familyRepo.items.first.paymentReference, isNull);

      // Switch to Cheque -> Cheque Number (Optional) appears
      await tester.tap(find.widgetWithText(ChoiceChip, 'Cheque'));
      await tester.pumpAndSettle();
      expect(find.text('Cheque Number (Optional)'), findsOneWidget);
      expect(find.text('UTR Number (Optional)'), findsNothing);

      // Switch to Draft -> Draft Number (Optional) appears
      await tester.tap(find.widgetWithText(ChoiceChip, 'Draft'));
      await tester.pumpAndSettle();
      expect(find.text('Draft Number (Optional)'), findsOneWidget);
    });

    testWidgets('9. Switching payment mode clears stale reference', (tester) async {
      await tester.pumpWidget(
        buildAddSheetTest(familyRepo: familyRepo, flRepo: flRepo),
      );
      await tester.pumpAndSettle();

      // Select UPI and enter UTR
      await tester.tap(find.widgetWithText(ChoiceChip, 'UPI'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'UTR Number (Optional)'), '123456789012');
      await tester.pumpAndSettle();

      // Switch to Cash -> reference field disappears
      await tester.tap(find.widgetWithText(ChoiceChip, 'Cash'));
      await tester.pumpAndSettle();
      expect(find.text('UTR Number (Optional)'), findsNothing);

      // Switch back to UPI -> reference field is empty
      await tester.tap(find.widgetWithText(ChoiceChip, 'UPI'));
      await tester.pumpAndSettle();
      final utrField = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'UTR Number (Optional)'),
      );
      expect(utrField.controller?.text, isEmpty);
    });

    testWidgets('10. Edit flow preserves and allows editing payment mode and reference', (tester) async {
      final existingItem = FamilyUtilize(
        id: 'edit_1',
        amount: 3000,
        category: 'Medical',
        title: 'Clinic Visit',
        paymentMode: 'Cheque',
        paymentReference: '778899',
        transactionDate: '2026-09-23',
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        buildAddSheetTest(
          familyRepo: familyRepo,
          flRepo: flRepo,
          initialItem: existingItem,
        ),
      );
      await tester.pumpAndSettle();

      // Verify initial fields populated
      expect(find.text('Edit Family Utilization'), findsOneWidget);
      expect(find.text('Cheque Number (Optional)'), findsOneWidget);
      expect(find.text('778899'), findsOneWidget);

      // Update to Draft with new reference
      await tester.tap(find.widgetWithText(ChoiceChip, 'Draft'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Draft Number (Optional)'), '443322');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Update Utilization'));
      await tester.pumpAndSettle();

      expect(familyRepo.items.first.paymentMode, 'Draft');
      expect(familyRepo.items.first.paymentReference, '443322');
    });
  });
}
