import 'package:flutter_test/flutter_test.dart';
import 'package:pamz_khata/feature/fund_ledger/data/models/fl_contact_model.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/entities/fl_contact.dart';

void main() {
  group('FLContact Entity & Model Tests', () {
    final now = DateTime(2026, 9, 21, 10, 0);

    final testContact = FLContact(
      id: 'contact-001',
      name: 'Mohd Rashid',
      mobileNumber: '9876543210',
      aadhaarNumber: '123456789012',
      project: 'Community Aid',
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
    );

    test('1. FLContact copyWith creates modified instance correctly', () {
      final updated = testContact.copyWith(
        name: 'Rashid Khan',
        project: 'Hospital Relief',
      );

      expect(updated.id, equals('contact-001'));
      expect(updated.name, equals('Rashid Khan'));
      expect(updated.mobileNumber, equals('9876543210'));
      expect(updated.project, equals('Hospital Relief'));
      expect(updated.aadhaarNumber, equals('123456789012'));
    });

    test('2. FLContactModel fromEntity and toEntity map bidirectionally', () {
      final model = FLContactModel.fromEntity(testContact);
      final entity = model.toEntity();

      expect(entity.id, equals(testContact.id));
      expect(entity.name, equals(testContact.name));
      expect(entity.mobileNumber, equals(testContact.mobileNumber));
      expect(entity.aadhaarNumber, equals(testContact.aadhaarNumber));
      expect(entity.project, equals(testContact.project));
      expect(entity.createdAt, equals(testContact.createdAt));
      expect(entity.updatedAt, equals(testContact.updatedAt));
      expect(entity.isDeleted, equals(testContact.isDeleted));
    });

    test('3. FLContactModel SQLite map serialization and deserialization', () {
      final model = FLContactModel.fromEntity(testContact);
      final map = model.toMap();

      expect(map['id'], equals('contact-001'));
      expect(map['name'], equals('Mohd Rashid'));
      expect(map['mobile_number'], equals('9876543210'));
      expect(map['aadhaar_number'], equals('123456789012'));
      expect(map['project'], equals('Community Aid'));
      expect(map['is_deleted'], equals(0));

      final restoredModel = FLContactModel.fromMap(map);
      expect(restoredModel.id, equals(model.id));
      expect(restoredModel.name, equals(model.name));
      expect(restoredModel.mobileNumber, equals(model.mobileNumber));
      expect(restoredModel.isDeleted, isFalse);
    });

    test('4. Soft-delete flag is handled correctly in SQLite mapping', () {
      final deletedContact = testContact.copyWith(isDeleted: true);
      final model = FLContactModel.fromEntity(deletedContact);
      final map = model.toMap();

      expect(map['is_deleted'], equals(1));
      final restored = FLContactModel.fromMap(map);
      expect(restored.isDeleted, isTrue);
    });
  });
}
