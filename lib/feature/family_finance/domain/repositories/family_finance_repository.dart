import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';
import '../entities/category_budget.dart';
import '../entities/family_transaction.dart';

abstract class FamilyFinanceRepository {
  Future<Either<Failure, List<FamilyTransaction>>> getTransactions({String? type});
  Future<Either<Failure, FamilyTransaction>> addTransaction(FamilyTransaction transaction);
  Future<Either<Failure, FamilyTransaction>> updateTransaction(FamilyTransaction transaction);
  Future<Either<Failure, void>> deleteTransaction(String id);
  Future<Either<Failure, List<TransactionCategory>>> getCategories({String? domain});
  Future<Either<Failure, TransactionCategory>> createCategory(TransactionCategory category);
  Future<Either<Failure, TransactionCategory>> updateCategory(TransactionCategory category);
  Future<Either<Failure, void>> deleteCategory(String id);
  Future<Either<Failure, List<CategoryBudget>>> getBudgets({int? year, int? month});
  Future<Either<Failure, CategoryBudget>> createBudget(CategoryBudget budget);
  Future<Either<Failure, CategoryBudget>> updateBudget(CategoryBudget budget);
  Future<Either<Failure, void>> deleteBudget(String id);
  Future<Either<Failure, List<BudgetCalculation>>> getBudgetCalculations(int year, int month);
  Future<Either<Failure, List<Account>>> getAccounts();
  Future<Either<Failure, double>> getTotalIncomeForMonth(DateTime month);
  Future<Either<Failure, double>> getTotalExpenseForMonth(DateTime month);
}
