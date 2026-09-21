import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/sqlite/app_database.dart';
import '../../../../core/db/sqlite/database_helper.dart';
import '../../../../core/db/storage_config.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../data/repositories/family_finance_hive_repository_impl.dart';
import '../../data/repositories/family_finance_repository_impl.dart';
import '../../data/services/receipt_storage_service.dart';
import '../../domain/entities/family_transaction.dart';
import '../../domain/repositories/family_finance_repository.dart';
import '../../../analytics_reports/presentation/providers/analytics_providers.dart';
import '../../domain/usecases/family_finance_usecases.dart';
import 'budget_providers.dart';

// ─── Infrastructure & Repository ─────────────────────────────────────────

final receiptStorageServiceProvider = Provider<ReceiptStorageService>(
  (ref) => const ReceiptStorageService(),
);

final familyFinanceDatabaseHelperProvider = Provider<DatabaseHelper>(
  (ref) => DatabaseHelper(AppDatabase.instance),
);

final familyFinanceRepositoryProvider = Provider<FamilyFinanceRepository>(
  (ref) => AppStorageConfig.isHive
      ? const FamilyFinanceHiveRepositoryImpl()
      : FamilyFinanceRepositoryImpl(
          ref.watch(familyFinanceDatabaseHelperProvider),
        ),
);

// ─── Usecases ────────────────────────────────────────────────────────────

final getFamilyTransactionsUsecaseProvider =
    Provider<GetFamilyTransactionsUsecase>(
  (ref) => GetFamilyTransactionsUsecase(
    ref.watch(familyFinanceRepositoryProvider),
  ),
);

final addFamilyTransactionUsecaseProvider =
    Provider<AddFamilyTransactionUsecase>(
  (ref) => AddFamilyTransactionUsecase(
    ref.watch(familyFinanceRepositoryProvider),
  ),
);

final updateFamilyTransactionUsecaseProvider =
    Provider<UpdateFamilyTransactionUsecase>(
  (ref) => UpdateFamilyTransactionUsecase(
    ref.watch(familyFinanceRepositoryProvider),
  ),
);

final deleteFamilyTransactionUsecaseProvider =
    Provider<DeleteFamilyTransactionUsecase>(
  (ref) => DeleteFamilyTransactionUsecase(
    ref.watch(familyFinanceRepositoryProvider),
  ),
);

final getCategoriesUsecaseProvider = Provider<GetCategoriesUsecase>(
  (ref) => GetCategoriesUsecase(
    ref.watch(familyFinanceRepositoryProvider),
  ),
);

final createCategoryUsecaseProvider = Provider<CreateCategoryUsecase>(
  (ref) => CreateCategoryUsecase(
    ref.watch(familyFinanceRepositoryProvider),
  ),
);

final updateCategoryUsecaseProvider = Provider<UpdateCategoryUsecase>(
  (ref) => UpdateCategoryUsecase(
    ref.watch(familyFinanceRepositoryProvider),
  ),
);

final deleteCategoryUsecaseProvider = Provider<DeleteCategoryUsecase>(
  (ref) => DeleteCategoryUsecase(
    ref.watch(familyFinanceRepositoryProvider),
  ),
);

final getAccountsUsecaseProvider = Provider<GetAccountsUsecase>(
  (ref) => GetAccountsUsecase(
    ref.watch(familyFinanceRepositoryProvider),
  ),
);

// ─── Data Providers ──────────────────────────────────────────────────────

final incomeListProvider =
    FutureProvider<List<FamilyTransaction>>((ref) async {
  final usecase = ref.watch(getFamilyTransactionsUsecaseProvider);
  final result = await usecase(type: 'income');
  return result.fold(
    (l) => throw Exception(l.message),
    (r) => r,
  );
});

final expenseListProvider =
    FutureProvider<List<FamilyTransaction>>((ref) async {
  final usecase = ref.watch(getFamilyTransactionsUsecaseProvider);
  final result = await usecase(type: 'expense');
  return result.fold(
    (l) => throw Exception(l.message),
    (r) => r,
  );
});

final allTransactionsProvider =
    FutureProvider<List<FamilyTransaction>>((ref) async {
  final usecase = ref.watch(getFamilyTransactionsUsecaseProvider);
  final result = await usecase();
  return result.fold(
    (l) => throw Exception(l.message),
    (r) => r,
  );
});

final categoriesProvider =
    FutureProvider.family<List<TransactionCategory>, String?>((ref, domain) async {
  final usecase = ref.watch(getCategoriesUsecaseProvider);
  final result = await usecase(domain: domain);
  return result.fold(
    (l) => throw Exception(l.message),
    (r) => r,
  );
});

final accountsProvider = FutureProvider<List<Account>>((ref) async {
  final usecase = ref.watch(getAccountsUsecaseProvider);
  final result = await usecase();
  return result.fold(
    (l) => throw Exception(l.message),
    (r) => r,
  );
});

final currentMonthIncomeProvider = Provider<AsyncValue<double>>((ref) {
  final txnsAsync = ref.watch(incomeListProvider);
  return txnsAsync.whenData((txns) {
    final now = DateTime.now();
    final currentMonthKey = AppDateUtils.toMonthKey(now);
    return txns
        .where((t) => AppDateUtils.toMonthKey(t.transactionDate) == currentMonthKey)
        .fold<double>(0.0, (sum, t) => sum + t.amount);
  });
});

final currentMonthExpenseProvider = Provider<AsyncValue<double>>((ref) {
  final txnsAsync = ref.watch(expenseListProvider);
  return txnsAsync.whenData((txns) {
    final now = DateTime.now();
    final currentMonthKey = AppDateUtils.toMonthKey(now);
    return txns
        .where((t) => AppDateUtils.toMonthKey(t.transactionDate) == currentMonthKey)
        .fold<double>(0.0, (sum, t) => sum + t.amount);
  });
});

final monthlyIncomeProvider =
    FutureProvider.family<double, DateTime>((ref, month) async {
  final repo = ref.watch(familyFinanceRepositoryProvider);
  final result = await repo.getTotalIncomeForMonth(month);
  return result.fold(
    (l) => throw Exception(l.message),
    (r) => r,
  );
});

final monthlyExpenseProvider =
    FutureProvider.family<double, DateTime>((ref, month) async {
  final repo = ref.watch(familyFinanceRepositoryProvider);
  final result = await repo.getTotalExpenseForMonth(month);
  return result.fold(
    (l) => throw Exception(l.message),
    (r) => r,
  );
});

// ─── Summary Calculation Model & Providers ────────────────────────────────

class FamilyFinanceSummary {
  const FamilyFinanceSummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.netBalance,
  });

  final double totalIncome;
  final double totalExpense;
  final double netBalance;

  static const empty = FamilyFinanceSummary(
    totalIncome: 0.0,
    totalExpense: 0.0,
    netBalance: 0.0,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FamilyFinanceSummary &&
          runtimeType == other.runtimeType &&
          totalIncome == other.totalIncome &&
          totalExpense == other.totalExpense &&
          netBalance == other.netBalance;

  @override
  int get hashCode => Object.hash(totalIncome, totalExpense, netBalance);
}

final familyTotalIncomeProvider = Provider<AsyncValue<double>>((ref) {
  final txnsAsync = ref.watch(incomeListProvider);
  return txnsAsync.whenData((txns) {
    return txns.fold<double>(0.0, (sum, t) => sum + t.amount);
  });
});

final familyTotalExpenseProvider = Provider<AsyncValue<double>>((ref) {
  final txnsAsync = ref.watch(expenseListProvider);
  return txnsAsync.whenData((txns) {
    return txns.fold<double>(0.0, (sum, t) => sum + t.amount);
  });
});

final familyFinanceSummaryProvider =
    Provider<AsyncValue<FamilyFinanceSummary>>((ref) {
  final incomeAsync = ref.watch(incomeListProvider);
  final expenseAsync = ref.watch(expenseListProvider);

  if (incomeAsync.hasError) {
    return AsyncError(
      incomeAsync.error!,
      incomeAsync.stackTrace ?? StackTrace.current,
    );
  }
  if (expenseAsync.hasError) {
    return AsyncError(
      expenseAsync.error!,
      expenseAsync.stackTrace ?? StackTrace.current,
    );
  }
  if (incomeAsync.isLoading || expenseAsync.isLoading) {
    return const AsyncLoading();
  }

  final incomeList = incomeAsync.value ?? [];
  final expenseList = expenseAsync.value ?? [];

  final totalIncome =
      incomeList.fold<double>(0.0, (sum, t) => sum + t.amount);
  final totalExpense =
      expenseList.fold<double>(0.0, (sum, t) => sum + t.amount);
  final netBalance = totalIncome - totalExpense;

  return AsyncData(FamilyFinanceSummary(
    totalIncome: totalIncome,
    totalExpense: totalExpense,
    netBalance: netBalance,
  ));
});

// ─── Form Notifier ───────────────────────────────────────────────────────

class FamilyFinanceNotifier extends StateNotifier<AsyncValue<void>> {
  FamilyFinanceNotifier(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  Future<bool> addTransaction(FamilyTransaction transaction) async {
    state = const AsyncValue.loading();
    final usecase = _ref.read(addFamilyTransactionUsecaseProvider);
    final result = await usecase(transaction);
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        _invalidateAll();
        return true;
      },
    );
  }

  Future<bool> updateTransaction(FamilyTransaction transaction) async {
    state = const AsyncValue.loading();
    final usecase = _ref.read(updateFamilyTransactionUsecaseProvider);
    final result = await usecase(transaction);
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        _invalidateAll();
        return true;
      },
    );
  }

  Future<bool> deleteTransaction(String id) async {
    state = const AsyncValue.loading();
    final usecase = _ref.read(deleteFamilyTransactionUsecaseProvider);
    final result = await usecase(id);
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        _invalidateAll();
        return true;
      },
    );
  }

  void _invalidateAll() {
    _ref.invalidate(incomeListProvider);
    _ref.invalidate(expenseListProvider);
    _ref.invalidate(allTransactionsProvider);
    _ref.invalidate(monthlyIncomeProvider);
    _ref.invalidate(monthlyExpenseProvider);
    _ref.invalidate(monthlyBudgetCalculationsProvider);
    _ref.invalidate(activeBudgetCalculationsProvider);
    _ref.invalidate(analyticsReportProvider);
  }
}


final familyFinanceNotifierProvider =
    StateNotifierProvider<FamilyFinanceNotifier, AsyncValue<void>>(
  (ref) => FamilyFinanceNotifier(ref),
);

// ─── Category Notifier ───────────────────────────────────────────────────

class CategoryNotifier extends StateNotifier<AsyncValue<void>> {
  CategoryNotifier(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  Future<bool> createCategory(TransactionCategory category) async {
    state = const AsyncValue.loading();
    final usecase = _ref.read(createCategoryUsecaseProvider);
    final result = await usecase(category);
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        _invalidateCategories();
        return true;
      },
    );
  }

  Future<bool> updateCategory(TransactionCategory category) async {
    state = const AsyncValue.loading();
    final usecase = _ref.read(updateCategoryUsecaseProvider);
    final result = await usecase(category);
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        _invalidateCategories();
        return true;
      },
    );
  }

  Future<bool> deleteCategory(String id) async {
    state = const AsyncValue.loading();
    final usecase = _ref.read(deleteCategoryUsecaseProvider);
    final result = await usecase(id);
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        _invalidateCategories();
        return true;
      },
    );
  }

  void _invalidateCategories() {
    _ref.invalidate(categoriesProvider);
    _ref.invalidate(incomeListProvider);
    _ref.invalidate(expenseListProvider);
    _ref.invalidate(allTransactionsProvider);
  }
}

final categoryNotifierProvider =
    StateNotifierProvider<CategoryNotifier, AsyncValue<void>>(
  (ref) => CategoryNotifier(ref),
);
