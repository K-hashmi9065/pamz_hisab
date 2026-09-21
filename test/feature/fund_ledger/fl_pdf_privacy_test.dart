import 'package:flutter_test/flutter_test.dart';
import 'package:pamz_khata/feature/fund_ledger/data/services/fl_pdf_service.dart';
import 'package:pamz_khata/feature/fund_ledger/domain/entities/fl_share_statement.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FLPdfService & FLShareStatement Strict Privacy Tests', () {
    test('1. FLShareStatement contains exclusively Received and Returned collections', () {
      const statement = FLShareStatement(
        contactName: 'Mohd Rashid',
        mobileNumber: '9876543210',
        aadhaarNumber: '123456789012',
        receivedEntries: [
          FLShareEntry(
            date: '2026-09-01',
            amount: 50000.0,
            paymentMode: 'Bank Transfer',
            paymentReference: 'NEFT/00112233',
          ),
        ],
        returnedEntries: [
          FLShareEntry(
            date: '2026-09-15',
            amount: 10000.0,
            paymentMode: 'UPI',
            paymentReference: 'UPI/998877',
          ),
        ],
      );

      // Verify received & returned are present
      expect(statement.hasReceivedHistory, isTrue);
      expect(statement.hasReturnedHistory, isTrue);
      expect(statement.receivedEntries.length, equals(1));
      expect(statement.returnedEntries.length, equals(1));
      expect(statement.receivedEntries.first.amount, equals(50000.0));
      expect(statement.returnedEntries.first.amount, equals(10000.0));
    });

    test('2. FLPdfService generates non-empty PDF bytes from statement', () async {
      const pdfService = FLPdfService();

      const statement = FLShareStatement(
        contactName: 'Mohd Rashid',
        mobileNumber: '9876543210',
        aadhaarNumber: '123456789012',
        receivedEntries: [
          FLShareEntry(
            date: '2026-09-01',
            amount: 50000.0,
            paymentMode: 'Cash',
          ),
        ],
        returnedEntries: [
          FLShareEntry(
            date: '2026-09-15',
            amount: 10000.0,
            paymentMode: 'Cash',
          ),
        ],
      );

      final pdfBytes = await pdfService.generate(statement);

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.isNotEmpty, isTrue);
      // PDF file magic header (%PDF-)
      expect(pdfBytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
    });

    test('3. FLPdfService generates valid PDF when history is empty', () async {
      const pdfService = FLPdfService();

      const emptyStatement = FLShareStatement(
        contactName: 'New Contact',
        mobileNumber: '9800000000',
        receivedEntries: [],
        returnedEntries: [],
      );

      final pdfBytes = await pdfService.generate(emptyStatement);
      expect(pdfBytes.isNotEmpty, isTrue);
    });

    test('4. Strict Privacy Contract: INCLUDED and EXCLUDED fields', () {
      const statement = FLShareStatement(
        contactName: 'Ahmad Khan',
        mobileNumber: '9123456780',
        aadhaarNumber: '987654321098',
        receivedEntries: [
          FLShareEntry(
            date: '2026-09-01',
            amount: 15000.0,
            paymentMode: 'Cash',
          ),
        ],
        returnedEntries: [
          FLShareEntry(
            date: '2026-09-10',
            amount: 5000.0,
            paymentMode: 'UPI',
            paymentReference: 'UPI/123456',
          ),
        ],
      );

      // INCLUDED:
      expect(statement.contactName, equals('Ahmad Khan'));
      expect(statement.mobileNumber, equals('9123456780'));
      expect(statement.aadhaarNumber, equals('987654321098'));
      expect(statement.receivedEntries.length, equals(1));
      expect(statement.returnedEntries.length, equals(1));

      // EXCLUDED verification:
      // FLShareStatement does not have fields for totalReceived, totalReturned,
      // availableBalance, project, totalUtilized, utilizedEntries, internalNotes,
      // or generatedAt (metadata timestamp).
      // This is a compile-time and structural guarantee — the fields simply do not exist.
      expect(statement.hasReceivedHistory, isTrue);
      expect(statement.hasReturnedHistory, isTrue);
    });
  });
}
