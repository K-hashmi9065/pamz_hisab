class NotificationTemplate {
  const NotificationTemplate({
    required this.id,
    required this.name,
    required this.templateEnglish,
    required this.templateHindi,
    required this.templateHinglish,
    required this.supportedPlaceholders,
  });

  final String id;
  final String name;
  final String templateEnglish;
  final String templateHindi;
  final String templateHinglish;
  final List<String> supportedPlaceholders;

  NotificationTemplate copyWith({
    String? id,
    String? name,
    String? templateEnglish,
    String? templateHindi,
    String? templateHinglish,
    List<String>? supportedPlaceholders,
  }) {
    return NotificationTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      templateEnglish: templateEnglish ?? this.templateEnglish,
      templateHindi: templateHindi ?? this.templateHindi,
      templateHinglish: templateHinglish ?? this.templateHinglish,
      supportedPlaceholders: supportedPlaceholders ?? this.supportedPlaceholders,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'template_english': templateEnglish,
      'template_hindi': templateHindi,
      'template_hinglish': templateHinglish,
      'supported_placeholders': supportedPlaceholders,
    };
  }

  factory NotificationTemplate.fromMap(Map<String, dynamic> map) {
    return NotificationTemplate(
      id: map['id'] as String,
      name: map['name'] as String,
      templateEnglish: map['template_english'] as String,
      templateHindi: map['template_hindi'] as String,
      templateHinglish: map['template_hinglish'] as String,
      supportedPlaceholders: List<String>.from(map['supported_placeholders'] as List? ?? []),
    );
  }
}
