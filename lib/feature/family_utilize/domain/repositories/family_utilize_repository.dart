import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/family_utilize.dart';

/// Abstract repository contract for Family Utilizations.
abstract interface class FamilyUtilizeRepository {
  /// Returns all non-deleted family utilizations, optionally filtered by category,
  /// date range, or search query (newest first).
  Future<Either<Failure, List<FamilyUtilize>>> getAll({
    String? category,
    DateTime? from,
    DateTime? to,
    String? searchQuery,
  });

  /// Finds a single family utilization by ID.
  Future<Either<Failure, FamilyUtilize?>> getById(String id);

  /// Inserts a new family utilization.
  Future<Either<Failure, void>> insert(FamilyUtilize item);

  /// Updates an existing family utilization.
  Future<Either<Failure, void>> update(FamilyUtilize item);

  /// Soft-deletes a family utilization.
  Future<Either<Failure, void>> softDelete(String id);

  /// Returns the summed total of all non-deleted family utilizations.
  Future<Either<Failure, double>> getTotalFamilyUtilized({
    DateTime? from,
    DateTime? to,
  });
}
