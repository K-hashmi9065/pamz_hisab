import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/notification_template_model.dart';
import '../../data/repositories/notification_template_repository.dart';

final notificationTemplateRepositoryProvider = Provider<NotificationTemplateRepository>((ref) {
  return const NotificationTemplateRepository();
});

final notificationTemplatesProvider = FutureProvider<List<NotificationTemplate>>((ref) async {
  final repo = ref.watch(notificationTemplateRepositoryProvider);
  return repo.getTemplates();
});

final activeTemplateProvider = FutureProvider.family<NotificationTemplate, String>((ref, id) async {
  final repo = ref.watch(notificationTemplateRepositoryProvider);
  return repo.getTemplate(id);
});
