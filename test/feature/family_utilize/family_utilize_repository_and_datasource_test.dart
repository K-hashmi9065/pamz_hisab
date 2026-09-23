import 'package:flutter_test/flutter_test.dart';
import 'package:pamz_khata/feature/family_utilize/data/datasources/family_utilize_datasource.dart';
import 'package:pamz_khata/feature/family_utilize/data/models/family_utilize_model.dart';
import 'package:pamz_khata/feature/family_utilize/data/repositories/family_utilize_repository_impl.dart';
import 'package:pamz_khata/feature/family_utilize/domain/entities/family_utilize.dart';

class InMemoryFamilyUtilizeDataSource implements FamilyUtilizeDataSource {
  final Map<String, FamilyUtilizeModel> _store = {};

  @override
  Future<void> insert(FamilyUtilizeModel model) async {
    _store[model.id] = model;
  }

  @override
  Future<void> update(FamilyUtilizeModel model) async {
    _store[model.id] = model;
  }

  @override
  Future<FamilyUtilizeModel?> getById(String id) async {
    final m = _store[id];
    return (m != null && !m.isDeleted) ? m : null;
  }

  @override
  Future<void> softDelete(String id) async {
    final existing = _store[id];
    if (existing != null) {
      _store[id] = existing.copyWith(isDeleted: true);
    }
  }

  @override
  Future<List<FamilyUtilizeModel>> getAll({
    String? category,
    String? fromDate,
    String? toDate,
    String? searchQuery,
  }) async {
    return _store.values.where((item) {
      if (item.isDeleted) return false;
      if (category != null &&
          item.category.toLowerCase() != category.toLowerCase()) {
        return false;
      }
      if (fromDate != null && item.transactionDate.compareTo(fromDate) < 0) {
        return false;
      }
      if (toDate != null && item.transactionDate.compareTo(toDate) > 0) {
        return false;
      }
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
        final match = item.title.toLowerCase().contains(q) ||
            item.category.toLowerCase().contains(q) ||
            (item.paidTo?.toLowerCase().contains(q) ?? false) ||
            (item.description?.toLowerCase().contains(q) ?? false) ||
            (item.mobileNumber?.toLowerCase().contains(q) ?? false) ||
            (item.paymentMode?.toLowerCase().contains(q) ?? false) ||
            (item.paymentReference?.toLowerCase().contains(q) ?? false) ||
            item.amount.toString().contains(q);
        if (!match) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
  }

  @override
  Future<double> getTotalFamilyUtilized({
    String? fromDate,
    String? toDate,
  }) async {
    final list = await getAll(fromDate: fromDate, toDate: toDate);
    return list.fold<double>(0.0, (sum, item) => sum + item.amount);
  }
}

class ThrowingFamilyUtilizeDataSource implements FamilyUtilizeDataSource {
  @override
  Future<List<FamilyUtilizeModel>> getAll({
    String? category,
    String? fromDate,
    String? toDate,
    String? searchQuery,
  }) =>
      throw Exception('GetAll exploded');

  @override
  Future<FamilyUtilizeModel?> getById(String id) =>
      throw Exception('GetById exploded');

  @override
  Future<void> insert(FamilyUtilizeModel model) =>
      throw Exception('Insert exploded');

  @override
  Future<void> update(FamilyUtilizeModel model) =>
      throw Exception('Update exploded');

  @override
  Future<void> softDelete(String id) => throw Exception('Delete exploded');

  @override
  Future<double> getTotalFamilyUtilized({String? fromDate, String? toDate}) =>
      throw Exception('GetTotal exploded');
}

void main() {
  group('FamilyUtilize Repository & DataSource Tests', () {
    late InMemoryFamilyUtilizeDataSource dataSource;
    late FamilyUtilizeRepositoryImpl repository;

    final now = DateTime(2026, 9, 23);

    setUp(() {
      dataSource = InMemoryFamilyUtilizeDataSource();
      repository = FamilyUtilizeRepositoryImpl(dataSource);
    });

    test('1. Create, Read and Update Family Utilization with Payment Mode and Reference', () async {
      final item = FamilyUtilize(
        id: 'u1',
        amount: 5000,
        category: 'Education',
        title: 'School Fee',
        paymentMode: 'UPI',
        paymentReference: '123456789012',
        paidTo: 'ABC School',
        mobileNumber: '9876543210',
        description: 'Semester 1 fee',
        transactionDate: '2026-09-20',
        createdAt: now,
        updatedAt: now,
      );

      // Insert
      final insertRes = await repository.insert(item);
      expect(insertRes.isRight(), isTrue);

      // Read by ID
      final getRes = await repository.getById('u1');
      expect(getRes.isRight(), isTrue);
      final retrieved = getRes.getOrElse((_) => null);
      expect(retrieved?.title, 'School Fee');
      expect(retrieved?.amount, 5000);
      expect(retrieved?.paymentMode, 'UPI');
      expect(retrieved?.paymentReference, '123456789012');

      // Update payment mode to Cheque
      final updatedItem = item.copyWith(
        amount: 5500,
        title: 'School Fee Revised',
        paymentMode: 'Cheque',
        paymentReference: '654321',
      );
      final updateRes = await repository.update(updatedItem);
      expect(updateRes.isRight(), isTrue);

      final reGetRes = await repository.getById('u1');
      final reRetrieved = reGetRes.getOrElse((_) => null);
      expect(reRetrieved?.amount, 5500);
      expect(reRetrieved?.title, 'School Fee Revised');
      expect(reRetrieved?.paymentMode, 'Cheque');
      expect(reRetrieved?.paymentReference, '654321');
    });

    test('2. Soft Delete excludes item from getAll and getTotalFamilyUtilized', () async {
      final item1 = FamilyUtilize(
        id: 'u1',
        amount: 5000,
        category: 'Education',
        title: 'School Fee',
        paymentMode: 'Cash',
        transactionDate: '2026-09-20',
        createdAt: now,
        updatedAt: now,
      );
      final item2 = FamilyUtilize(
        id: 'u2',
        amount: 2500,
        category: 'Electricity',
        title: 'Electricity Bill',
        paymentMode: 'UPI',
        paymentReference: '9988776655',
        transactionDate: '2026-09-21',
        createdAt: now,
        updatedAt: now,
      );

      await repository.insert(item1);
      await repository.insert(item2);

      var total = await repository.getTotalFamilyUtilized();
      expect(total.getOrElse((_) => 0), 7500);

      // Soft delete item1
      final delRes = await repository.softDelete('u1');
      expect(delRes.isRight(), isTrue);

      // Verify list only has item2
      final listRes = await repository.getAll();
      final list = listRes.getOrElse((_) => []);
      expect(list.length, 1);
      expect(list.first.id, 'u2');

      total = await repository.getTotalFamilyUtilized();
      expect(total.getOrElse((_) => 0), 2500);
    });

    test('3. Date Range and Category Filtering', () async {
      final item1 = FamilyUtilize(
        id: 'u1',
        amount: 5000,
        category: 'Education',
        title: 'School Fee',
        paymentMode: 'Draft',
        paymentReference: '112233',
        transactionDate: '2026-09-01',
        createdAt: now,
        updatedAt: now,
      );
      final item2 = FamilyUtilize(
        id: 'u2',
        amount: 2500,
        category: 'Electricity',
        title: 'Electricity Bill',
        paymentMode: 'Cash',
        transactionDate: '2026-09-15',
        createdAt: now,
        updatedAt: now,
      );
      final item3 = FamilyUtilize(
        id: 'u3',
        amount: 4000,
        category: 'Grocery',
        title: 'Monthly Ration',
        paymentMode: 'UPI',
        paymentReference: '445566',
        transactionDate: '2026-09-25',
        createdAt: now,
        updatedAt: now,
      );

      await repository.insert(item1);
      await repository.insert(item2);
      await repository.insert(item3);

      // Filter by category
      final eduRes = await repository.getAll(category: 'Education');
      expect(eduRes.getOrElse((_) => []).length, 1);
      expect(eduRes.getOrElse((_) => []).first.category, 'Education');

      // Filter by date range (10 Sep to 20 Sep)
      final rangeRes = await repository.getAll(
        from: DateTime(2026, 9, 10),
        to: DateTime(2026, 9, 20),
      );
      final rangeList = rangeRes.getOrElse((_) => []);
      expect(rangeList.length, 1);
      expect(rangeList.first.id, 'u2');
    });

    test('4. Full-text Search by paymentMode, paymentReference and multiple fields', () async {
      final item1 = FamilyUtilize(
        id: 'u1',
        amount: 5000,
        category: 'Education',
        title: 'School Fee',
        paidTo: 'St. Xavier School',
        paymentMode: 'UPI',
        paymentReference: 'UTR998877',
        mobileNumber: '9876543210',
        description: 'Quarter 2 payment',
        transactionDate: '2026-09-01',
        createdAt: now,
        updatedAt: now,
      );
      final item2 = FamilyUtilize(
        id: 'u2',
        amount: 2500,
        category: 'Electricity',
        title: 'Monthly Light Bill',
        paymentMode: 'Cheque',
        paymentReference: 'CHQ123456',
        paidTo: 'NBPDCL Power Corp',
        transactionDate: '2026-09-15',
        createdAt: now,
        updatedAt: now,
      );

      await repository.insert(item1);
      await repository.insert(item2);

      // Search by UTR
      final searchUtr = await repository.getAll(searchQuery: 'UTR998877');
      expect(searchUtr.getOrElse((_) => []).length, 1);
      expect(searchUtr.getOrElse((_) => []).first.id, 'u1');

      // Search by Cheque Reference
      final searchChq = await repository.getAll(searchQuery: 'CHQ123456');
      expect(searchChq.getOrElse((_) => []).length, 1);
      expect(searchChq.getOrElse((_) => []).first.id, 'u2');

      // Search by payment mode
      final searchMode = await repository.getAll(searchQuery: 'Cheque');
      expect(searchMode.getOrElse((_) => []).length, 1);

      // Search by paidTo
      final searchPaidTo =
          await repository.getAll(searchQuery: 'Xavier');
      expect(searchPaidTo.getOrElse((_) => []).length, 1);
    });

    test('5. Error Handling returns DatabaseFailure gracefully', () async {
      final throwingRepo =
          FamilyUtilizeRepositoryImpl(ThrowingFamilyUtilizeDataSource());
      final item = FamilyUtilize(
        id: 'u1',
        amount: 1000,
        category: 'Other',
        title: 'Test',
        paymentMode: 'Cash',
        transactionDate: '2026-09-23',
        createdAt: now,
        updatedAt: now,
      );

      expect((await throwingRepo.getAll()).isLeft(), isTrue);
      expect((await throwingRepo.getById('u1')).isLeft(), isTrue);
      expect((await throwingRepo.insert(item)).isLeft(), isTrue);
      expect((await throwingRepo.update(item)).isLeft(), isTrue);
      expect((await throwingRepo.softDelete('u1')).isLeft(), isTrue);
      expect((await throwingRepo.getTotalFamilyUtilized()).isLeft(), isTrue);
    });
  });
}
