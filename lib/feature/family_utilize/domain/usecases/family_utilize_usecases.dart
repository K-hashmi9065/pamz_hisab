import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/family_utilize.dart';
import '../repositories/family_utilize_repository.dart';

/// Usecase to fetch all family utilizations with optional filters.
class GetAllFamilyUtilizesUsecase {
  const GetAllFamilyUtilizesUsecase(this._repository);
  final FamilyUtilizeRepository _repository;

  Future<Either<Failure, List<FamilyUtilize>>> call({
    String? category,
    DateTime? from,
    DateTime? to,
    String? searchQuery,
  }) {
    return _repository.getAll(
      category: category,
      from: from,
      to: to,
      searchQuery: searchQuery,
    );
  }
}

/// Usecase to insert a new family utilization.
class AddFamilyUtilizeUsecase {
  const AddFamilyUtilizeUsecase(this._repository);
  final FamilyUtilizeRepository _repository;

  Future<Either<Failure, void>> call(FamilyUtilize item) {
    if (item.amount <= 0) {
      return Future.value(
        const Left(ValidationFailure(message: 'Amount must be greater than 0')),
      );
    }
    if (item.title.trim().isEmpty) {
      return Future.value(
        const Left(ValidationFailure(message: 'Title is required')),
      );
    }
    return _repository.insert(item);
  }
}

/// Usecase to update an existing family utilization.
class UpdateFamilyUtilizeUsecase {
  const UpdateFamilyUtilizeUsecase(this._repository);
  final FamilyUtilizeRepository _repository;

  Future<Either<Failure, void>> call(FamilyUtilize item) {
    if (item.amount <= 0) {
      return Future.value(
        const Left(ValidationFailure(message: 'Amount must be greater than 0')),
      );
    }
    if (item.title.trim().isEmpty) {
      return Future.value(
        const Left(ValidationFailure(message: 'Title is required')),
      );
    }
    return _repository.update(item);
  }
}

/// Usecase to soft-delete a family utilization.
class DeleteFamilyUtilizeUsecase {
  const DeleteFamilyUtilizeUsecase(this._repository);
  final FamilyUtilizeRepository _repository;

  Future<Either<Failure, void>> call(String id) {
    return _repository.softDelete(id);
  }
}

/// Usecase to get total family utilized amount.
class GetFamilyUtilizeTotalUsecase {
  const GetFamilyUtilizeTotalUsecase(this._repository);
  final FamilyUtilizeRepository _repository;

  Future<Either<Failure, double>> call({DateTime? from, DateTime? to}) {
    return _repository.getTotalFamilyUtilized(from: from, to: to);
  }
}
