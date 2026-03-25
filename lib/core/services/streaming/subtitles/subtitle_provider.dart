import 'package:cinemuse_app/core/services/streaming/subtitles/external_subtitle.dart';

abstract class SubtitleProvider {
  /// The display name of the provider (e.g., 'OpenSubtitles').
  String get name;

  /// Whether this provider is currently configured and ready to use.
  bool get isReady;

  /// Search for subtitles matching the given criteria.
  /// 
  /// At least one of [imdbId] or [tmdbId] is usually required,
  /// but some providers might support text [query].
  Future<List<ExternalSubtitle>> search({
    String? imdbId,
    String? tmdbId,
    int? season,
    int? episode,
    String? query,
    required String language,
  });

  /// Get the direct download URL for a specific subtitle.
  /// 
  /// If the [subtitle] already has a [url], this might just return it.
  /// Otherwise, it performs the necessary API call to get the download link.
  Future<String?> getDownloadUrl(ExternalSubtitle subtitle);
}
