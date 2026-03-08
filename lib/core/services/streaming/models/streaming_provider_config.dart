class StreamingProviderConfig {
  final String id;
  final String name;
  final bool enabled;
  final int priority;

  const StreamingProviderConfig({
    required this.id,
    required this.name,
    this.enabled = true,
    required this.priority,
  });

  StreamingProviderConfig copyWith({
    String? id,
    String? name,
    bool? enabled,
    int? priority,
  }) {
    return StreamingProviderConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      enabled: enabled ?? this.enabled,
      priority: priority ?? this.priority,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'enabled': enabled,
      'priority': priority,
    };
  }

  factory StreamingProviderConfig.fromJson(Map<String, dynamic> json) {
    return StreamingProviderConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      enabled: json['enabled'] as bool? ?? true,
      priority: json['priority'] as int,
    );
  }
}
