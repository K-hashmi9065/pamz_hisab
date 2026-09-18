import 'package:mocktail/mocktail.dart';

import 'package:pamz_khata/feature/contacts/domain/entities/contact.dart';
import 'package:pamz_khata/feature/contacts/domain/repositories/contact_repository.dart';
import 'package:pamz_khata/feature/direct_udhar/domain/entities/direct_udhar_loan.dart';
import 'package:pamz_khata/feature/direct_udhar/domain/repositories/direct_udhar_repository.dart';
import 'package:pamz_khata/core/security/biometric_service.dart';
import 'package:pamz_khata/feature/family_finance/domain/entities/category_budget.dart';
import 'package:pamz_khata/feature/family_finance/domain/entities/family_transaction.dart';
import 'package:pamz_khata/feature/family_finance/domain/repositories/family_finance_repository.dart';

// ─── Mock Classes ─────────────────────────────────────────────────────────

class MockContactRepository extends Mock implements ContactRepository {}

class MockDirectUdharRepository extends Mock implements DirectUdharRepository {}

class MockFamilyFinanceRepository extends Mock implements FamilyFinanceRepository {}

class MockBiometricService extends Mock implements BiometricService {}

// ─── Fake Classes (for registerFallbackValue) ─────────────────────────────

class FakeContact extends Fake implements Contact {}

class FakeDirectUdharLoan extends Fake implements DirectUdharLoan {}

class FakeRepayment extends Fake implements Repayment {}

class FakeFamilyTransaction extends Fake implements FamilyTransaction {}

class FakeTransactionCategory extends Fake implements TransactionCategory {}

class FakeAccount extends Fake implements Account {}

class FakeCategoryBudget extends Fake implements CategoryBudget {}

// ─── Setup function — call in setUpAll() ─────────────────────────────────

void registerFallbacks() {
  registerFallbackValue(FakeContact());
  registerFallbackValue(FakeDirectUdharLoan());
  registerFallbackValue(FakeRepayment());
  registerFallbackValue(FakeFamilyTransaction());
  registerFallbackValue(FakeTransactionCategory());
  registerFallbackValue(FakeAccount());
  registerFallbackValue(FakeCategoryBudget());
  registerFallbackValue(ContactType.buyer);
  registerFallbackValue(LoanStatus.open);
}

