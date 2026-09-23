import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:pamz_khata/core/error/failure.dart';
import 'package:pamz_khata/feature/family_utilize/domain/entities/family_utilize.dart';
import 'package:pamz_khata/feature/family_utilize/domain/repositories/family_utilize_repository.dart';
import 'package:pamz_khata/feature/family_utilize/presentation/providers/family_utilize_providers.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/entities/fl_transaction.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/repositories/fl_transaction_repository.dart';
import 'package:pamz_khata/feature/fund_ledger/presentation/providers/fl_transaction_providers.dart';

class MockFamilyUtilizeRepo implements FamilyUtilizeRepository {
  final List<FamilyUtilize> items = [];
  bool shouldFail = false;

  @override
  Future<Either<Failure, void>> insert(FamilyUtilize item) async {
    if (shouldFail) return const Left(DatabaseFailure(message: 'Insert failed'));
    items.add(item);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> update(FamilyUtilize item) async {
    if (shouldFail) return const Left(DatabaseFailure(message: 'Update failed'));
    final idx = items.indexWhere((i) => i.id == item.id);
    if (idx != -1) items[idx] = item;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> softDelete(String id) async {
    if (shouldFail) return const Left(DatabaseFailure(message: 'Delete failed'));
    items.removeWhere((i) => i.id == id);
    return const Right(null);
  }

  @override
  Future<Either<Failure, List<FamilyUtilize>>> getAll({
    String? category,
    DateTime? from,
    DateTime? to,
    String? searchQuery,
  }) async {
    if (shouldFail) return const Left(DatabaseFailure(message: 'GetAll failed'));
    return Right(List.from(items));
  }

  @override
  Future<Either<Failure, FamilyUtilize?>> getById(String id) async {
    if (shouldFail) return const Left(DatabaseFailure(message: 'GetById failed'));
    final match = items.where((i) => i.id == id).firstOrNull;
    return Right(match);
  }

  @override
  Future<Either<Failure, double>> getTotalFamilyUtilized({
    DateTime? from,
    DateTime? to,
  }) async {
    if (shouldFail) return const Left(DatabaseFailure(message: 'GetTotal failed'));
    final sum = items.fold<double>(0.0, (s, i) => s + i.amount);
    return Right(sum);
  }
}

class MockFLTxnRepoForSummary implements FLTransactionRepository {
  double totalReceived = 50000;
  double totalReturned = 5000;
  double totalUtilized = 2000;

  @override
  Future<Either<Failure, FLContactTotals>> getGlobalTotals() async {
    return Right(
      FLContactTotals(
        totalReceived: totalReceived,
        totalUtilized: totalUtilized,
        totalReturned: totalReturned,
      ),
    );
  }

  @override
  Future<Either<Failure, FLContactTotals>> getTotals(String contactId) async =>
      getGlobalTotals();

  @override
  Future<Either<Failure, List<FLTransaction>>> getAll({
    FLTransactionType? type,
    String? contactId,
    DateTime? from,
    DateTime? to,
  }) async =>
      const Right([]);

  @override
  Future<Either<Failure, List<FLTransaction>>> getByContact(String contactId) async =>
      const Right([]);

  @override
  Future<Either<Failure, void>> insert(FLTransaction transaction) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> update(FLTransaction transaction) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> softDelete(String id) async =>
      const Right(null);
}

void main() {
  group('FamilyUtilize Riverpod Providers Tests', () {
    late MockFamilyUtilizeRepo familyRepo;
    late MockFLTxnRepoForSummary flRepo;
    late ProviderContainer container;

    final now = DateTime(2026, 9, 23);

    setUp(() {
      familyRepo = MockFamilyUtilizeRepo();
      flRepo = MockFLTxnRepoForSummary();
      container = ProviderContainer(
        overrides: [
          familyUtilizeRepositoryProvider.overrideWithValue(familyRepo),
          flTransactionRepositoryProvider.overrideWithValue(flRepo),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('1. Initial list is empty and summary reflects full available fund', () async {
      final list = await container.read(familyUtilizeListNotifierProvider.future);
      expect(list, isEmpty);

      final summary = await container.read(familyUtilizeSummaryProvider.future);
      expect(summary.totalReceived, 50000);
      expect(summary.totalReturned, 5000);
      expect(summary.totalFamilyUtilized, 0);
      expect(summary.availableBeforeFamilyUtilize, 45000);
      expect(summary.remainingAvailable, 45000);
    });

    test('2. Add Family Utilization updates list and reduces remaining balance', () async {
      final item = FamilyUtilize(
        id: 'u1',
        amount: 7000,
        category: 'Education',
        title: 'School Fee',
        transactionDate: '2026-09-23',
        createdAt: now,
        updatedAt: now,
      );

      await container.read(familyUtilizeListNotifierProvider.notifier).add(item);

      final list = await container.read(familyUtilizeListNotifierProvider.future);
      expect(list.length, 1);
      expect(list.first.title, 'School Fee');

      final summary = await container.read(familyUtilizeSummaryProvider.future);
      expect(summary.totalFamilyUtilized, 7000);
      expect(summary.remainingAvailable, 38000); // 45000 - 7000 = 38000
    });

    test('3. Delete Family Utilization updates list and restores remaining balance', () async {
      final item = FamilyUtilize(
        id: 'u1',
        amount: 7000,
        category: 'Education',
        title: 'School Fee',
        transactionDate: '2026-09-23',
        createdAt: now,
        updatedAt: now,
      );

      await container.read(familyUtilizeListNotifierProvider.notifier).add(item);
      expect((await container.read(familyUtilizeSummaryProvider.future)).remainingAvailable, 38000);

      await container.read(familyUtilizeListNotifierProvider.notifier).delete('u1');

      final list = await container.read(familyUtilizeListNotifierProvider.future);
      expect(list, isEmpty);

      final summary = await container.read(familyUtilizeSummaryProvider.future);
      expect(summary.totalFamilyUtilized, 0);
      expect(summary.remainingAvailable, 45000);
    });
  });
}
