import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/category_budget.dart';
import '../../domain/usecases/budget_usecases.dart';
import 'family_finance_providers.dart';

final selectedBudgetMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

final getBudgetsUsecaseProvider = Provider<GetBudgetsUsecase>((ref) {
  return GetBudgetsUsecase(ref.watch(familyFinanceRepositoryProvider));
});

final createBudgetUsecaseProvider = Provider<CreateBudgetUsecase>((ref) {
  return CreateBudgetUsecase(ref.watch(familyFinanceRepositoryProvider));
});

final updateBudgetUsecaseProvider = Provider<UpdateBudgetUsecase>((ref) {
  return UpdateBudgetUsecase(ref.watch(familyFinanceRepositoryProvider));
});

final deleteBudgetUsecaseProvider = Provider<DeleteBudgetUsecase>((ref) {
  return DeleteBudgetUsecase(ref.watch(familyFinanceRepositoryProvider));
});

final getBudgetCalculationsUsecaseProvider =
    Provider<GetBudgetCalculationsUsecase>((ref) {
  return GetBudgetCalculationsUsecase(
      ref.watch(familyFinanceRepositoryProvider));
});

final monthlyBudgetCalculationsProvider = FutureProvider.family<
    List<BudgetCalculation>, ({int year, int month})>((ref, arg) async {
  final usecase = ref.watch(getBudgetCalculationsUsecaseProvider);
  final result = await usecase(arg.year, arg.month);
  return result.fold(
    (l) => throw Exception(l.message),
    (r) => r,
  );
});

final activeBudgetCalculationsProvider =
    FutureProvider<List<BudgetCalculation>>((ref) async {
  final selectedMonth = ref.watch(selectedBudgetMonthProvider);
  return ref.watch(monthlyBudgetCalculationsProvider((
    year: selectedMonth.year,
    month: selectedMonth.month,
  )).future);
});

class BudgetNotifier extends StateNotifier<AsyncValue<void>> {
  BudgetNotifier(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  Future<bool> createBudget(CategoryBudget budget) async {
    state = const AsyncValue.loading();
    final usecase = _ref.read(createBudgetUsecaseProvider);
    final result = await usecase(budget);
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        _invalidate();
        return true;
      },
    );
  }

  Future<bool> updateBudget(CategoryBudget budget) async {
    state = const AsyncValue.loading();
    final usecase = _ref.read(updateBudgetUsecaseProvider);
    final result = await usecase(budget);
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        _invalidate();
        return true;
      },
    );
  }

  Future<bool> deleteBudget(String id) async {
    state = const AsyncValue.loading();
    final usecase = _ref.read(deleteBudgetUsecaseProvider);
    final result = await usecase(id);
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        _invalidate();
        return true;
      },
    );
  }

  void _invalidate() {
    _ref.invalidate(monthlyBudgetCalculationsProvider);
    _ref.invalidate(activeBudgetCalculationsProvider);
  }
}

final budgetNotifierProvider =
    StateNotifierProvider<BudgetNotifier, AsyncValue<void>>(
  (ref) => BudgetNotifier(ref),
);
