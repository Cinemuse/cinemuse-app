class StreamingProviderConfig {
  final String id;
  final String name;
  final bool enabled;
  final int priority;
  final Set<String>? supportedCategories;

  const StreamingProviderConfig({
    required this.id,
    required this.name,
    this.enabled = true,
    required this.priority,
    this.supportedCategories,
  });

  StreamingProviderConfig copyWith({
    String? id,
    String? name,
    bool? enabled,
    int? priority,
    Set<String>? supportedCategories,
  }) {
    return StreamingProviderConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      enabled: enabled ?? this.enabled,
      priority: priority ?? this.priority,
      supportedCategories: supportedCategories ?? this.supportedCategories,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'enabled': enabled,
      'priority': priority,
      'supportedCategories': supportedCategories?.toList(),
    };
  }

  factory StreamingProviderConfig.fromJson(Map<String, dynamic> json) {
    return StreamingProviderConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      enabled: json['enabled'] as bool? ?? true,
      priority: json['priority'] as int,
      supportedCategories: json['supportedCategories'] != null 
        ? (json['supportedCategories'] as List).map((e) => e as String).toSet() 
        : null,
    );
  }
}
