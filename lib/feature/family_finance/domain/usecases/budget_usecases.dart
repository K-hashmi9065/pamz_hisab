import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/category_budget.dart';
import '../repositories/family_finance_repository.dart';

class GetBudgetsUsecase {
  const GetBudgetsUsecase(this._repository);
  final FamilyFinanceRepository _repository;

  Future<Either<Failure, List<CategoryBudget>>> call({int? year, int? month}) {
    return _repository.getBudgets(year: year, month: month);
  }
}

class CreateBudgetUsecase {
  const CreateBudgetUsecase(this._repository);
  final FamilyFinanceRepository _repository;

  Future<Either<Failure, CategoryBudget>> call(CategoryBudget budget) {
    if (budget.categoryId.isEmpty) {
      return Future.value(left(const ValidationFailure(
        message: 'Expense category is required.',
        field: 'categoryId',
      )));
    }
    if (budget.monthlyLimit <= 0) {
      return Future.value(left(const ValidationFailure(
        message: 'Monthly budget limit must be greater than zero.',
        field: 'monthlyLimit',
      )));
    }
    if (budget.thresholdPercentage <= 0 || budget.thresholdPercentage > 100) {
      return Future.value(left(const ValidationFailure(
        message: 'Alert threshold percentage must be between 1 and 100.',
        field: 'thresholdPercentage',
      )));
    }
    if (budget.month < 1 || budget.month > 12) {
      return Future.value(left(const ValidationFailure(
        message: 'Invalid budget month.',
        field: 'month',
      )));
    }
    return _repository.createBudget(budget);
  }
}

class UpdateBudgetUsecase {
  const UpdateBudgetUsecase(this._repository);
  final FamilyFinanceRepository _repository;

  Future<Either<Failure, CategoryBudget>> call(CategoryBudget budget) {
    if (budget.id.isEmpty) {
      return Future.value(left(const ValidationFailure(
        message: 'Budget ID is required for update.',
        field: 'id',
      )));
    }
    if (budget.monthlyLimit <= 0) {
      return Future.value(left(const ValidationFailure(
        message: 'Monthly budget limit must be greater than zero.',
        field: 'monthlyLimit',
      )));
    }
    if (budget.thresholdPercentage <= 0 || budget.thresholdPercentage > 100) {
      return Future.value(left(const ValidationFailure(
        message: 'Alert threshold percentage must be between 1 and 100.',
        field: 'thresholdPercentage',
      )));
    }
    return _repository.updateBudget(budget);
  }
}

class DeleteBudgetUsecase {
  const DeleteBudgetUsecase(this._repository);
  final FamilyFinanceRepository _repository;

  Future<Either<Failure, void>> call(String id) {
    if (id.isEmpty) {
      return Future.value(left(const ValidationFailure(
        message: 'Budget ID is required.',
        field: 'id',
      )));
    }
    return _repository.deleteBudget(id);
  }
}

class GetBudgetCalculationsUsecase {
  const GetBudgetCalculationsUsecase(this._repository);
  final FamilyFinanceRepository _repository;

  Future<Either<Failure, List<BudgetCalculation>>> call(int year, int month) {
    return _repository.getBudgetCalculations(year, month);
  }
}
