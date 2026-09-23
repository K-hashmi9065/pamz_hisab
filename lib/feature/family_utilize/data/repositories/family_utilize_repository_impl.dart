import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../domain/entities/family_utilize.dart';
import '../../domain/repositories/family_utilize_repository.dart';
import '../datasources/family_utilize_datasource.dart';
import '../models/family_utilize_model.dart';

/// Concrete implementation of [FamilyUtilizeRepository].
class FamilyUtilizeRepositoryImpl implements FamilyUtilizeRepository {
  const FamilyUtilizeRepositoryImpl(this._dataSource);
  final FamilyUtilizeDataSource _dataSource;

  @override
  Future<Either<Failure, List<FamilyUtilize>>> getAll({
    String? category,
    DateTime? from,
    DateTime? to,
    String? searchQuery,
  }) async {
    try {
      final models = await _dataSource.getAll(
        category: category,
        fromDate: from != null ? AppDateUtils.toDateOnly(from) : null,
        toDate: to != null ? AppDateUtils.toDateOnly(to) : null,
        searchQuery: searchQuery,
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(DatabaseFailure(technicalDetail: e.toString()));
    }
  }

  @override
  Future<Either<Failure, FamilyUtilize?>> getById(String id) async {
    try {
      final model = await _dataSource.getById(id);
      return Right(model?.toEntity());
    } catch (e) {
      return Left(DatabaseFailure(technicalDetail: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> insert(FamilyUtilize item) async {
    try {
      await _dataSource.insert(FamilyUtilizeModel.fromEntity(item));
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(technicalDetail: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> update(FamilyUtilize item) async {
    try {
      await _dataSource.update(FamilyUtilizeModel.fromEntity(item));
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
  Future<Either<Failure, double>> getTotalFamilyUtilized({
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final total = await _dataSource.getTotalFamilyUtilized(
        fromDate: from != null ? AppDateUtils.toDateOnly(from) : null,
        toDate: to != null ? AppDateUtils.toDateOnly(to) : null,
      );
      return Right(total);
    } catch (e) {
      return Left(DatabaseFailure(technicalDetail: e.toString()));
    }
  }
}
