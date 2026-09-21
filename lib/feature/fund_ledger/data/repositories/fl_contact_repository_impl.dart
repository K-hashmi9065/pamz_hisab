import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/fl_contact.dart';
import '../../domain/repositories/fl_contact_repository.dart';
import '../datasources/fl_contact_datasource.dart';
import '../models/fl_contact_model.dart';

/// SQLite/Hive implementation of [FLContactRepository].
class FLContactRepositoryImpl implements FLContactRepository {
  const FLContactRepositoryImpl(this._dataSource);
  final FLContactDataSource _dataSource;

  @override
  Future<Either<Failure, List<FLContact>>> getAll() async {
    try {
      final models = await _dataSource.getAll();
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(DatabaseFailure(technicalDetail: e.toString()));
    }
  }

  @override
  Future<Either<Failure, FLContact?>> findById(String id) async {
    try {
      final model = await _dataSource.findById(id);
      return Right(model?.toEntity());
    } catch (e) {
      return Left(DatabaseFailure(technicalDetail: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> existsByMobile(
    String mobile, {
    String? excludeId,
  }) async {
    try {
      final exists = await _dataSource.existsByMobile(mobile, excludeId: excludeId);
      return Right(exists);
    } catch (e) {
      return Left(DatabaseFailure(technicalDetail: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> insert(FLContact contact) async {
    try {
      await _dataSource.insert(FLContactModel.fromEntity(contact));
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(technicalDetail: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> update(FLContact contact) async {
    try {
      await _dataSource.update(FLContactModel.fromEntity(contact));
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
}
