class StremioAddon {
  final String id;
  final String name;
  final String baseUrl;
  final String? queryParams;
  final String? version;
  final String? description;
  final String? icon;
  final String? logo;
  final String? background;
  final List<String> types;
  final List<Map<String, dynamic>> resources;
  final List<Map<String, dynamic>> catalogs;
  final bool enabled;
  final int priority;

  const StremioAddon({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.queryParams,
    this.version,
    this.description,
    this.icon,
    this.logo,
    this.background,
    this.types = const [],
    this.resources = const [],
    this.catalogs = const [],
    this.enabled = true,
    this.priority = 10,
  });

  StremioAddon copyWith({
    String? id,
    String? name,
    String? baseUrl,
    String? queryParams,
    String? version,
    String? description,
    String? icon,
    String? logo,
    String? background,
    List<String>? types,
    List<Map<String, dynamic>>? resources,
    List<Map<String, dynamic>>? catalogs,
    bool? enabled,
    int? priority,
  }) {
    return StremioAddon(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      queryParams: queryParams ?? this.queryParams,
      version: version ?? this.version,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      logo: logo ?? this.logo,
      background: background ?? this.background,
      types: types ?? this.types,
      resources: resources ?? this.resources,
      catalogs: catalogs ?? this.catalogs,
      enabled: enabled ?? this.enabled,
      priority: priority ?? this.priority,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'baseUrl': baseUrl,
      'queryParams': queryParams,
      'version': version,
      'description': description,
      'icon': icon,
      'logo': logo,
      'background': background,
      'types': types,
      'resources': resources,
      'catalogs': catalogs,
      'enabled': enabled,
      'priority': priority,
    };
  }

  Map<String, dynamic> toProfile() {
    return {
      'id': id,
      'name': name,
      'baseUrl': baseUrl,
      'queryParams': queryParams,
      'types': types,
      'enabled': enabled,
    };
  }

  factory StremioAddon.fromJson(Map<String, dynamic> json) {
    return StremioAddon(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown',
      baseUrl: json['baseUrl'] as String? ?? '',
      queryParams: json['queryParams'] as String?,
      version: json['version'] as String?,
      description: json['description'] as String?,
      icon: json['icon'] as String?,
      logo: json['logo'] as String?,
      background: json['background'] as String?,
      types: (json['types'] as List?)?.map((e) => e == 'series' ? 'tv' : e.toString()).toList() ?? const [],
      resources: _parseList(json['resources']),
      catalogs: _parseList(json['catalogs']),
      enabled: json['enabled'] as bool? ?? true,
      priority: json['priority'] as int? ?? 10,
    );
  }

  static List<Map<String, dynamic>> _parseList(dynamic list) {
    if (list is! Iterable) return const [];
    return list.map((e) {
      if (e is String) {
        return <String, dynamic>{
          'name': e,
          'types': <String>[],
          'idPrefixes': <String>[],
        };
      }
      if (e is Map) return Map<String, dynamic>.from(e);
      return <String, dynamic>{};
    }).toList();
  }

  bool hasResource(String resourceName, String type) {
    return resources.any((r) {
      final rName = r['name'] as String?;
      final rTypes = (r['types'] as List?)?.cast<String>();
      return rName == resourceName && (rTypes?.contains(type) ?? false);
    });
  }

  bool get isStreamingAddon => resources.any((r) => r['name'] == 'stream');
  bool get hasCatalog => catalogs.isNotEmpty;
}
