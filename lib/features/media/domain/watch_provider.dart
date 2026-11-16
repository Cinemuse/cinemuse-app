/// A streaming service TMDB knows in one country.
class WatchProvider {
  final int id;
  final String name;
  final String? logoPath;

  /// TMDB's rank for the service in that country, lower first; null when
  /// TMDB gives none.
  final int? priority;

  const WatchProvider({
    required this.id,
    required this.name,
    this.logoPath,
    this.priority,
  });

  /// Reads one of TMDB's services for [region]: its rank there, or its
  /// global rank when TMDB has none for the country.
  factory WatchProvider.fromTmdbMap(Map<String, dynamic> map, String region) {
    final byRegion = map['display_priorities'];
    final regional = byRegion is Map ? byRegion[region] : null;
    return WatchProvider(
      id: (map['provider_id'] as num?)?.toInt() ?? 0,
      name: (map['provider_name'] as String?) ?? '',
      logoPath: map['logo_path'] as String?,
      priority: ((regional ?? map['display_priority']) as num?)?.toInt(),
    );
  }
}

/// A country TMDB has streaming data for (the "Streaming country" setting).
typedef WatchRegion = ({String code, String name});

/// Reads one of TMDB's countries, named in the language asked for; null when
/// TMDB sends no country code.
WatchRegion? watchRegionFromTmdbMap(Map<String, dynamic> map) {
  final code = map['iso_3166_1'];
  if (code is! String) return null;
  return (
    code: code,
    name: (map['native_name'] ?? map['english_name'] ?? code) as String,
  );
}
