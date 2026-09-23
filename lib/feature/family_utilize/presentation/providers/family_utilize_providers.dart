import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/sqlite/app_database.dart';
import '../../../../core/db/sqlite/database_helper.dart';
import '../../../../core/db/storage_config.dart';
import '../../../fund_ledger/domain/repositories/fl_transaction_repository.dart';
import '../../../fund_ledger/presentation/providers/fl_transaction_providers.dart';
import '../../data/datasources/family_utilize_datasource.dart';
import '../../data/datasources/family_utilize_hive_datasource.dart';
import '../../data/datasources/family_utilize_sqlite_datasource.dart';
import '../../data/repositories/family_utilize_repository_impl.dart';
import '../../domain/entities/family_utilize.dart';
import '../../domain/entities/family_utilize_summary.dart';
import '../../domain/repositories/family_utilize_repository.dart';
import '../../domain/usecases/family_utilize_usecases.dart';

// ─── Infrastructure Providers ──────────────────────────────────────────────

final familyUtilizeDataSourceProvider = Provider<FamilyUtilizeDataSource>(
  (ref) => AppStorageConfig.isHive
      ? const FamilyUtilizeHiveDataSource()
      : FamilyUtilizeSqliteDataSource(
          DatabaseHelper(AppDatabase.instance),
        ),
);

final familyUtilizeRepositoryProvider = Provider<FamilyUtilizeRepository>(
  (ref) => FamilyUtilizeRepositoryImpl(
    ref.watch(familyUtilizeDataSourceProvider),
  ),
);

// ─── Usecases ───────────────────────────────────────────────────────────────

final getAllFamilyUtilizesUsecaseProvider =
    Provider<GetAllFamilyUtilizesUsecase>(
  (ref) => GetAllFamilyUtilizesUsecase(
    ref.watch(familyUtilizeRepositoryProvider),
  ),
);

final addFamilyUtilizeUsecaseProvider = Provider<AddFamilyUtilizeUsecase>(
  (ref) => AddFamilyUtilizeUsecase(
    ref.watch(familyUtilizeRepositoryProvider),
  ),
);

final updateFamilyUtilizeUsecaseProvider =
    Provider<UpdateFamilyUtilizeUsecase>(
  (ref) => UpdateFamilyUtilizeUsecase(
    ref.watch(familyUtilizeRepositoryProvider),
  ),
);

final deleteFamilyUtilizeUsecaseProvider =
    Provider<DeleteFamilyUtilizeUsecase>(
  (ref) => DeleteFamilyUtilizeUsecase(
    ref.watch(familyUtilizeRepositoryProvider),
  ),
);

final getFamilyUtilizeTotalUsecaseProvider =
    Provider<GetFamilyUtilizeTotalUsecase>(
  (ref) => GetFamilyUtilizeTotalUsecase(
    ref.watch(familyUtilizeRepositoryProvider),
  ),
);

// ─── Filter State ──────────────────────────────────────────────────────────

enum FamilyUtilizeDatePreset {
  all,
  today,
  thisWeek,
  thisMonth,
  thisYear,
  custom,
}

class FamilyUtilizeFilter {
  const FamilyUtilizeFilter({
    this.category,
    this.from,
    this.to,
    this.searchQuery = '',
    this.datePreset = FamilyUtilizeDatePreset.all,
  });

  final String? category;
  final DateTime? from;
  final DateTime? to;
  final String searchQuery;
  final FamilyUtilizeDatePreset datePreset;

  FamilyUtilizeFilter copyWith({
    String? category,
    bool clearCategory = false,
    DateTime? from,
    bool clearFrom = false,
    DateTime? to,
    bool clearTo = false,
    String? searchQuery,
    FamilyUtilizeDatePreset? datePreset,
  }) {
    return FamilyUtilizeFilter(
      category: clearCategory ? null : (category ?? this.category),
      from: clearFrom ? null : (from ?? this.from),
      to: clearTo ? null : (to ?? this.to),
      searchQuery: searchQuery ?? this.searchQuery,
      datePreset: datePreset ?? this.datePreset,
    );
  }
}

final familyUtilizeFilterProvider =
    StateProvider<FamilyUtilizeFilter>((ref) => const FamilyUtilizeFilter());

// ─── Family Utilize List Notifier ──────────────────────────────────────────

class FamilyUtilizeListNotifier
    extends AsyncNotifier<List<FamilyUtilize>> {
  @override
  Future<List<FamilyUtilize>> build() async {
    final filter = ref.watch(familyUtilizeFilterProvider);
    final usecase = ref.watch(getAllFamilyUtilizesUsecaseProvider);

    final result = await usecase(
      category: filter.category,
      from: filter.from,
      to: filter.to,
      searchQuery: filter.searchQuery,
    );

    return result.fold(
      (failure) => throw Exception(failure.message),
      (items) => items,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  Future<void> add(FamilyUtilize item) async {
    final usecase = ref.read(addFamilyUtilizeUsecaseProvider);
    final result = await usecase(item);
    result.fold(
      (failure) => throw Exception(failure.message),
      (_) {
        ref.invalidate(familyUtilizeSummaryProvider);
        ref.invalidate(flDashboardSummaryProvider);
        ref.invalidate(flReportsTotalsProvider);
        refresh();
      },
    );
  }

  Future<void> updateItem(FamilyUtilize item) async {
    final usecase = ref.read(updateFamilyUtilizeUsecaseProvider);
    final result = await usecase(item);
    result.fold(
      (failure) => throw Exception(failure.message),
      (_) {
        ref.invalidate(familyUtilizeSummaryProvider);
        ref.invalidate(flDashboardSummaryProvider);
        ref.invalidate(flReportsTotalsProvider);
        refresh();
      },
    );
  }

  Future<void> delete(String id) async {
    final usecase = ref.read(deleteFamilyUtilizeUsecaseProvider);
    final result = await usecase(id);
    result.fold(
      (failure) => throw Exception(failure.message),
      (_) {
        ref.invalidate(familyUtilizeSummaryProvider);
        ref.invalidate(flDashboardSummaryProvider);
        ref.invalidate(flReportsTotalsProvider);
        refresh();
      },
    );
  }
}

final familyUtilizeListNotifierProvider =
    AsyncNotifierProvider<FamilyUtilizeListNotifier, List<FamilyUtilize>>(
  FamilyUtilizeListNotifier.new,
);

// ─── Summary Provider ──────────────────────────────────────────────────────

final familyUtilizeSummaryProvider =
    FutureProvider<FamilyUtilizeSummary>((ref) async {
  final flRepo = ref.watch(flTransactionRepositoryProvider);
  final familyRepo = ref.watch(familyUtilizeRepositoryProvider);

  // 1. Global totals from Fund Ledger (Received & Returned)
  final flTotalsResult = await flRepo.getGlobalTotals();
  final flTotals = flTotalsResult.getOrElse((_) => FLContactTotals.zero());

  // 2. Total Family Utilized
  final familyTotalResult = await familyRepo.getTotalFamilyUtilized();
  final familyTotal = familyTotalResult.getOrElse((_) => 0.0);

  return FamilyUtilizeSummary(
    totalReceived: flTotals.totalReceived,
    totalReturned: flTotals.totalReturned,
    totalContactUtilized: flTotals.totalUtilized,
    totalFamilyUtilized: familyTotal,
  );
});
