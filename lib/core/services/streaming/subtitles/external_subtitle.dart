class ExternalSubtitle {
  final String id;
  final String language;     // Language code, e.g., 'en', 'it'
  final String languageName; // Display name, e.g., 'English', 'Italian'
  final String format;       // e.g., 'srt', 'vtt'
  final String? url;         // Direct download URL if available immediately
  final String providerName; // The service that provided this, e.g., 'OpenSubtitles'
  final String title;        // The filename or release name this subtitle is meant for
  final double? rating;      // Optional rating from the provider
  final int? downloadCount;  // Optional download count from the provider

  const ExternalSubtitle({
    required this.id,
    required this.language,
    required this.languageName,
    required this.format,
    this.url,
    required this.providerName,
    required this.title,
    this.rating,
    this.downloadCount,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExternalSubtitle &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          providerName == other.providerName;

  @override
  int get hashCode => id.hashCode ^ providerName.hashCode;
}
