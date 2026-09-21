import 'package:mocktail/mocktail.dart';

import 'package:pamz_khata/feature/contacts/domain/entities/contact.dart';
import 'package:pamz_khata/feature/contacts/domain/repositories/contact_repository.dart';
import 'package:pamz_khata/core/security/biometric_service.dart';
import 'package:pamz_khata/feature/notifications/data/models/notification_template_model.dart';
import 'package:pamz_khata/feature/notifications/data/repositories/notification_template_repository.dart';

// ─── Mock Classes ─────────────────────────────────────────────────────────

class MockContactRepository extends Mock implements ContactRepository {}

class MockBiometricService extends Mock implements BiometricService {}

// ─── Fake Classes (for registerFallbackValue) ─────────────────────────────

class FakeContact extends Fake implements Contact {}

/// In-memory fake repository for deterministic widget tests without real Hive disk I/O.
class FakeNotificationTemplateRepository implements NotificationTemplateRepository {
  FakeNotificationTemplateRepository({List<NotificationTemplate>? initialTemplates})
      : _templates = {
          for (final t in (initialTemplates ?? NotificationTemplateRepository.defaultTemplates))
            t.id: t,
        };

  final Map<String, NotificationTemplate> _templates;
  bool resetToDefaultsCalled = false;
  bool saveTemplateCalled = false;

  @override
  Future<List<NotificationTemplate>> getTemplates() async {
    return _templates.values.toList();
  }

  @override
  Future<NotificationTemplate> getTemplate(String templateId) async {
    return _templates[templateId] ??
        NotificationTemplateRepository.defaultTemplates.firstWhere(
          (t) => t.id == templateId,
          orElse: () => NotificationTemplateRepository.defaultTemplates.first,
        );
  }

  @override
  Future<void> saveTemplate(NotificationTemplate template) async {
    saveTemplateCalled = true;
    _templates[template.id] = template;
  }

  @override
  Future<void> resetToDefaults() async {
    resetToDefaultsCalled = true;
    _templates.clear();
    for (final def in NotificationTemplateRepository.defaultTemplates) {
      _templates[def.id] = def;
    }
  }
}

// ─── Setup function — call in setUpAll() ─────────────────────────────────

void registerFallbacks() {
  registerFallbackValue(FakeContact());
  registerFallbackValue(ContactType.buyer);
}
