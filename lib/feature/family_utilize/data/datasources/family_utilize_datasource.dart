import '../models/family_utilize_model.dart';

/// Abstract datasource interface for Family Utilizations.
abstract interface class FamilyUtilizeDataSource {
  /// Returns all non-deleted family utilizations with optional filters.
  Future<List<FamilyUtilizeModel>> getAll({
    String? category,
    String? fromDate,
    String? toDate,
    String? searchQuery,
  });

  /// Finds a single record by ID.
  Future<FamilyUtilizeModel?> getById(String id);

  /// Inserts a new family utilization.
  Future<void> insert(FamilyUtilizeModel model);

  /// Updates an existing family utilization.
  Future<void> update(FamilyUtilizeModel model);

  /// Soft-deletes a family utilization.
  Future<void> softDelete(String id);

  /// Returns total sum of family utilizations.
  Future<double> getTotalFamilyUtilized({
    String? fromDate,
    String? toDate,
  });
}
