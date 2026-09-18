import '../../../../core/db/hive/hive_registrar.dart';
import '../models/notification_template_model.dart';

class NotificationTemplateRepository {
  const NotificationTemplateRepository();

  static const List<NotificationTemplate> defaultTemplates = [
    NotificationTemplate(
      id: 'loan_voucher',
      name: 'Udhar Loan / Opening Balance Voucher',
      supportedPlaceholders: [
        '{title}',
        '{contact_name}',
        '{amount}',
        '{direction}',
        '{interest_info}',
        '{date}',
        '{total_balance}',
        '{memo_line}',
      ],
      templateEnglish: '''*PAMZ Hisab - {title}*
Dear {contact_name},
Your account entry details:
• Amount: {amount} ({direction})
• Interest: {interest_info}
• Date: {date}
• Total Outstanding: {total_balance}
{memo_line}
Thank you,
PAMZ Hisab''',
      templateHindi: '''*PAMZ Hisab - {title}*
नमस्ते {contact_name} जी,
खाता विवरण:
• राशि: {amount} ({direction})
• ब्याज दर: {interest_info}
• दिनांक: {date}
• कुल बकाया: {total_balance}
{memo_line}
धन्यवाद,
PAMZ Hisab''',
      templateHinglish: '''*PAMZ Hisab - {title}*
Namaste {contact_name} ji,
Aapke khata ki details:
• Amount: {amount} ({direction})
• Byaj (Interest): {interest_info}
• Date: {date}
• Total Outstanding: {total_balance}
{memo_line}
Shukriya,
PAMZ Hisab''',
    ),
    NotificationTemplate(
      id: 'statement_summary',
      name: 'Ledger Statement Account Summary',
      supportedPlaceholders: [
        '{contact_name}',
        '{date}',
        '{total_debit}',
        '{total_credit}',
        '{net_balance}',
        '{balance_type}',
      ],
      templateEnglish: '''*PAMZ Hisab - Ledger Statement*
Dear {contact_name},
Statement as of {date}:
• Total Lent/Dr: {total_debit}
• Total Received/Cr: {total_credit}
• Net Balance: {net_balance} ({balance_type})

Attached is your itemized PDF ledger statement.
Thank you,
PAMZ Hisab''',
      templateHindi: '''*PAMZ Hisab - खाता विवरण*
नमस्ते {contact_name} जी,
दिनांक {date} तक का खाता शेष:
• कुल नामे (Lent): {total_debit}
• कुल जमा (Received): {total_credit}
• शुद्ध बकाया: {net_balance} ({balance_type})

विस्तृत पीडीएफ लेजर पर्ची साथ में संलग्न है।
धन्यवाद,
PAMZ Hisab''',
      templateHinglish: '''*PAMZ Hisab - Ledger Statement*
Namaste {contact_name} ji,
Date {date} tak aapka hisab:
• Total Diya (Lent): {total_debit}
• Total Jama (Received): {total_credit}
• Net Baki (Balance): {net_balance} ({balance_type})

Aapka detailed PDF statement attach hai.
Shukriya,
PAMZ Hisab''',
    ),
    NotificationTemplate(
      id: 'repayment_jama',
      name: 'Repayment (Jama) Acknowledgement',
      supportedPlaceholders: [
        '{contact_name}',
        '{amount}',
        '{date}',
        '{payment_mode}',
        '{remaining_balance}',
      ],
      templateEnglish: '''*PAMZ Hisab - Repayment Received*
Dear {contact_name},
We have received your payment of {amount} on {date}.
• Payment Mode: {payment_mode}
• Remaining Balance: {remaining_balance}

Thank you,
PAMZ Hisab''',
      templateHindi: '''*PAMZ Hisab - जमा रसीद*
नमस्ते {contact_name} जी,
हमें आपका भुगतान {amount} दिनांक {date} को प्राप्त हुआ।
• भुगतान माध्यम: {payment_mode}
• शेष बकाया: {remaining_balance}

धन्यवाद,
PAMZ Hisab''',
      templateHinglish: '''*PAMZ Hisab - Jama Confirmation*
Namaste {contact_name} ji,
Aapka payment {amount} date {date} ko mil gaya hai.
• Mode: {payment_mode}
• Baki Balance: {remaining_balance}

Shukriya,
PAMZ Hisab''',
    ),
  ];

  Future<List<NotificationTemplate>> getTemplates() async {
    final box = HiveRegistrar.templatesBox;
    final List<NotificationTemplate> result = [];

    for (final def in defaultTemplates) {
      final raw = await box.get(def.id);
      if (raw is Map) {
        result.add(NotificationTemplate.fromMap(Map<String, dynamic>.from(raw)));
      } else {
        result.add(def);
      }
    }
    return result;
  }

  Future<NotificationTemplate> getTemplate(String templateId) async {
    final box = HiveRegistrar.templatesBox;
    final raw = await box.get(templateId);
    if (raw is Map) {
      return NotificationTemplate.fromMap(Map<String, dynamic>.from(raw));
    }
    return defaultTemplates.firstWhere(
      (t) => t.id == templateId,
      orElse: () => defaultTemplates.first,
    );
  }

  Future<void> saveTemplate(NotificationTemplate template) async {
    final box = HiveRegistrar.templatesBox;
    await box.put(template.id, template.toMap());
  }

  Future<void> resetToDefaults() async {
    final box = HiveRegistrar.templatesBox;
    for (final def in defaultTemplates) {
      await box.put(def.id, def.toMap());
    }
  }

  static String render(String templateText, Map<String, String> values) {
    String output = templateText;
    values.forEach((key, val) {
      output = output.replaceAll(key, val);
    });
    return output;
  }
}

