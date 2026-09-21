import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../domain/entities/fl_transaction.dart';
import '../../domain/repositories/fl_transaction_repository.dart';
import '../datasources/fl_transaction_datasource.dart';
import '../models/fl_transaction_model.dart';

/// SQLite/Hive implementation of [FLTransactionRepository].
class FLTransactionRepositoryImpl implements FLTransactionRepository {
  const FLTransactionRepositoryImpl(this._dataSource);
  final FLTransactionDataSource _dataSource;

  @override
  Future<Either<Failure, List<FLTransaction>>> getByContact(
      String contactId) async {
    try {
      final models = await _dataSource.getByContact(contactId);
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(DatabaseFailure(technicalDetail: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<FLTransaction>>> getAll({
    FLTransactionType? type,
    String? contactId,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final models = await _dataSource.getAll(
        type: type,
        contactId: contactId,
        fromDate: from != null ? AppDateUtils.toDateOnly(from) : null,
        toDate: to != null ? AppDateUtils.toDateOnly(to) : null,
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(DatabaseFailure(technicalDetail: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> insert(FLTransaction transaction) async {
    try {
      await _dataSource.insert(FLTransactionModel.fromEntity(transaction));
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(technicalDetail: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> softDelete(String id) async {
    try {
      await _dataSource.softDelete(id);
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(technicalDetail: e.toString()));
    }
  }

  @override
  Future<Either<Failure, FLContactTotals>> getTotals(String contactId) async {
    try {
      final totals = await _dataSource.getTotals(contactId);
      return Right(totals);
    } catch (e) {
      return Left(DatabaseFailure(technicalDetail: e.toString()));
    }
  }

  @override
  Future<Either<Failure, FLContactTotals>> getGlobalTotals() async {
    try {
      final totals = await _dataSource.getGlobalTotals();
      return Right(totals);
    } catch (e) {
      return Left(DatabaseFailure(technicalDetail: e.toString()));
    }
  }
}
