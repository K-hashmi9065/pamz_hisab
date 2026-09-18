import 'package:flutter_test/flutter_test.dart';
import 'package:pamz_khata/feature/settings/presentation/screens/audit_log_screen.dart';

import '../../test_helpers/pump_app.dart';

void main() {
  test('AuditLogItem deserializes cleanly', () {
    final map = {
      'id': 'audit-1',
      'entity_type': 'DirectUdharLoan',
      'entity_id': 'loan-123',
      'action': 'create',
      'changed_fields_json': '{"amount": 50000}',
      'performed_at': '2026-04-15T10:30:00.000',
    };

    final item = AuditLogItem.fromMap(map);

    expect(item.id, 'audit-1');
    expect(item.entityType, 'DirectUdharLoan');
    expect(item.entityId, 'loan-123');
    expect(item.action, 'create');
    expect(item.changedFieldsJson, contains('50000'));
  });

  testWidgets('AuditLogScreen renders empty state cleanly', (tester) async {
    await pumpApp(
      tester,
      const AuditLogScreen(),
      overrides: [
        auditLogsProvider.overrideWith((ref) async => []),
      ],
    );

    await tester.pumpAndSettle();

    expect(find.text('System Audit Logs'), findsOneWidget);
    expect(find.text('All Entities'), findsOneWidget);
  });
}
