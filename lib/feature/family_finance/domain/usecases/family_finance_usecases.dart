import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';
import '../entities/family_transaction.dart';
import '../repositories/family_finance_repository.dart';

class GetFamilyTransactionsUsecase {
  const GetFamilyTransactionsUsecase(this._repository);
  final FamilyFinanceRepository _repository;

  Future<Either<Failure, List<FamilyTransaction>>> call({String? type}) {
    return _repository.getTransactions(type: type);
  }
}

class AddFamilyTransactionUsecase {
  const AddFamilyTransactionUsecase(this._repository);
  final FamilyFinanceRepository _repository;

  Future<Either<Failure, FamilyTransaction>> call(FamilyTransaction transaction) {
    if (transaction.amount <= 0) {
      return Future.value(left(const ValidationFailure(
        message: 'Amount must be greater than zero.',
        field: 'amount',
      )));
    }
    if (transaction.categoryId.isEmpty) {
      return Future.value(left(const ValidationFailure(
        message: 'Category is required.',
        field: 'categoryId',
      )));
    }
    return _repository.addTransaction(transaction);
  }
}

class UpdateFamilyTransactionUsecase {
  const UpdateFamilyTransactionUsecase(this._repository);
  final FamilyFinanceRepository _repository;

  Future<Either<Failure, FamilyTransaction>> call(FamilyTransaction transaction) {
    if (transaction.amount <= 0) {
      return Future.value(left(const ValidationFailure(
        message: 'Amount must be greater than zero.',
        field: 'amount',
      )));
    }
    if (transaction.categoryId.isEmpty) {
      return Future.value(left(const ValidationFailure(
        message: 'Category is required.',
        field: 'categoryId',
      )));
    }
    return _repository.updateTransaction(transaction);
  }
}

class DeleteFamilyTransactionUsecase {
  const DeleteFamilyTransactionUsecase(this._repository);
  final FamilyFinanceRepository _repository;

  Future<Either<Failure, void>> call(String id) {
    return _repository.deleteTransaction(id);
  }
}

class GetCategoriesUsecase {
  const GetCategoriesUsecase(this._repository);
  final FamilyFinanceRepository _repository;

  Future<Either<Failure, List<TransactionCategory>>> call({String? domain}) {
    return _repository.getCategories(domain: domain);
  }
}

class CreateCategoryUsecase {
  const CreateCategoryUsecase(this._repository);
  final FamilyFinanceRepository _repository;

  Future<Either<Failure, TransactionCategory>> call(TransactionCategory category) {
    if (category.name.trim().isEmpty) {
      return Future.value(left(const ValidationFailure(
        message: 'Category name is required.',
        field: 'name',
      )));
    }
    if (category.domain != 'income' && category.domain != 'expense') {
      return Future.value(left(const ValidationFailure(
        message: 'Category domain must be income or expense.',
        field: 'domain',
      )));
    }
    return _repository.createCategory(category);
  }
}

class UpdateCategoryUsecase {
  const UpdateCategoryUsecase(this._repository);
  final FamilyFinanceRepository _repository;

  Future<Either<Failure, TransactionCategory>> call(TransactionCategory category) {
    if (category.id.isEmpty) {
      return Future.value(left(const ValidationFailure(
        message: 'Category id is required for update.',
        field: 'id',
      )));
    }
    if (category.name.trim().isEmpty) {
      return Future.value(left(const ValidationFailure(
        message: 'Category name is required.',
        field: 'name',
      )));
    }
    return _repository.updateCategory(category);
  }
}

class DeleteCategoryUsecase {
  const DeleteCategoryUsecase(this._repository);
  final FamilyFinanceRepository _repository;

  Future<Either<Failure, void>> call(String id) {
    if (id.isEmpty) {
      return Future.value(left(const ValidationFailure(
        message: 'Category id is required.',
        field: 'id',
      )));
    }
    return _repository.deleteCategory(id);
  }
}

class GetAccountsUsecase {
  const GetAccountsUsecase(this._repository);
  final FamilyFinanceRepository _repository;

  Future<Either<Failure, List<Account>>> call() {
    return _repository.getAccounts();
  }
}
