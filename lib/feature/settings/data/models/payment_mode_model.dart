class PaymentMode {
  const PaymentMode({
    required this.id,
    required this.code,
    required this.name,
    this.iconKey = '💳',
    this.isActive = true,
    this.isSystemPreset = false,
  });

  final String id;
  final String code;
  final String name;
  final String iconKey;
  final bool isActive;
  final bool isSystemPreset;

  PaymentMode copyWith({
    String? id,
    String? code,
    String? name,
    String? iconKey,
    bool? isActive,
    bool? isSystemPreset,
  }) {
    return PaymentMode(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      iconKey: iconKey ?? this.iconKey,
      isActive: isActive ?? this.isActive,
      isSystemPreset: isSystemPreset ?? this.isSystemPreset,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'icon_key': iconKey,
      'is_active': isActive ? 1 : 0,
      'is_system_preset': isSystemPreset ? 1 : 0,
    };
  }

  factory PaymentMode.fromMap(Map<String, dynamic> map) {
    return PaymentMode(
      id: map['id'] as String,
      code: map['code'] as String,
      name: map['name'] as String,
      iconKey: map['icon_key'] as String? ?? '💳',
      isActive: (map['is_active'] as int? ?? 1) == 1,
      isSystemPreset: (map['is_system_preset'] as int? ?? 0) == 1,
    );
  }
}
