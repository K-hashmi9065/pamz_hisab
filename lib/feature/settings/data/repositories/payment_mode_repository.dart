import 'package:uuid/uuid.dart';

import '../../../../core/db/hive/hive_registrar.dart';
import '../models/payment_mode_model.dart';

class PaymentModeRepository {
  const PaymentModeRepository();

  static const _storageKey = 'configured_payment_modes';

  static const List<PaymentMode> defaultPresets = [
    PaymentMode(id: 'pm_cash', code: 'cash', name: 'Cash', iconKey: '💵', isSystemPreset: true),
    PaymentMode(id: 'pm_upi', code: 'upi', name: 'UPI / QR Code', iconKey: '📱', isSystemPreset: true),
    PaymentMode(id: 'pm_bank', code: 'bank', name: 'Bank Transfer (NEFT/IMPS)', iconKey: '🏦', isSystemPreset: true),
    PaymentMode(id: 'pm_cheque', code: 'cheque', name: 'Cheque', iconKey: '📝', isSystemPreset: true),
  ];

  Future<List<PaymentMode>> getPaymentModes() async {
    final box = HiveRegistrar.settingsBox;
    final rawList = box.get(_storageKey);
    if (rawList is List) {
      return rawList
          .map((item) => PaymentMode.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();
    }
    // Seed defaults
    await saveAll(defaultPresets);
    return List<PaymentMode>.from(defaultPresets);
  }

  Future<void> saveAll(List<PaymentMode> modes) async {
    final box = HiveRegistrar.settingsBox;
    await box.put(_storageKey, modes.map((m) => m.toMap()).toList());
  }

  Future<PaymentMode> addPaymentMode(String name, String iconKey) async {
    final list = await getPaymentModes();
    final newMode = PaymentMode(
      id: const Uuid().v4(),
      code: name.toLowerCase().replaceAll(RegExp(r'\s+'), '_'),
      name: name.trim(),
      iconKey: iconKey,
      isActive: true,
      isSystemPreset: false,
    );
    list.add(newMode);
    await saveAll(list);
    return newMode;
  }

  Future<void> toggleModeActive(String id, bool active) async {
    final list = await getPaymentModes();
    final updated = list.map((m) {
      if (m.id == id) {
        return m.copyWith(isActive: active);
      }
      return m;
    }).toList();
    await saveAll(updated);
  }

  Future<void> deletePaymentMode(String id) async {
    final list = await getPaymentModes();
    list.removeWhere((m) => m.id == id && !m.isSystemPreset);
    await saveAll(list);
  }
}
