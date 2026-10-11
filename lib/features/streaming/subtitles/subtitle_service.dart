import 'package:cinemuse_app/features/streaming/subtitles/external_subtitle.dart';
import 'package:cinemuse_app/features/streaming/subtitles/opensubtitles_provider.dart';
import 'package:cinemuse_app/features/streaming/subtitles/subtitle_provider.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Searches subtitles across the configured providers.
class SubtitleService {
  final List<SubtitleProvider> _providers;

  SubtitleService(this._providers);

  /// Checks if there are any configured and ready providers available
  bool get hasActiveProviders => _providers.any((p) => p.isReady);

  /// Search across all configured subtitle providers
  Future<List<ExternalSubtitle>> search({
    String? imdbId,
    String? tmdbId,
    int? season,
    int? episode,
    String? query,
    required String language,
  }) async {
    final activeProviders = _providers.where((p) => p.isReady).toList();
    debugPrint(
      '[SubtitleService] search called — imdb=$imdbId, tmdb=$tmdbId, lang=$language, providers=${activeProviders.length}',
    );
    if (activeProviders.isEmpty) {
      debugPrint('[SubtitleService] No active providers, returning empty');
      return [];
    }

    final List<ExternalSubtitle> allResults = [];

    // Run searches in parallel
    final futures = activeProviders.map(
      (provider) => provider.search(
        imdbId: imdbId,
        tmdbId: tmdbId,
        season: season,
        episode: episode,
        query: query,
        language: language,
      ),
    );

    final resultsList = await Future.wait(futures);

    for (var list in resultsList) {
      allResults.addAll(list);
    }

    debugPrint('[SubtitleService] Total results: ${allResults.length}');
    return allResults;
  }

  /// Get the direct download URL for a specific subtitle
  Future<String?> getDownloadUrl(ExternalSubtitle subtitle) async {
    if (subtitle.url != null && subtitle.url!.isNotEmpty) {
      return subtitle.url;
    }

    // Find the provider that supplied this subtitle
    try {
      final provider = _providers.firstWhere(
        (p) => p.name == subtitle.providerName,
      );
      return provider.getDownloadUrl(subtitle);
    } catch (e) {
      // Provider not found or not configured anymore
      return null;
    }
  }
}

/// The configured subtitle providers. Rebuilt only when a provider key
/// changes, so each one keeps its HTTP client between calls (REV-35).
///
/// Not autoDispose: callers use `ref.read`, so an autoDispose provider would
/// be thrown away and rebuilt on every call.
final subtitleProvidersProvider = Provider<List<SubtitleProvider>>((ref) {
  final openSubtitlesKey = ref.watch(
    settingsProvider.select((s) => s.openSubtitlesKey),
  );
  final providers = <SubtitleProvider>[];

  if (openSubtitlesKey.isNotEmpty) {
    final openSubtitles = OpenSubtitlesProvider(openSubtitlesKey);
    ref.onDispose(openSubtitles.close);
    providers.add(openSubtitles);
  }

  return providers;
});

// Not autoDispose, same reason as subtitleProvidersProvider.
final subtitleServiceProvider = Provider<SubtitleService>((ref) {
  return SubtitleService(ref.watch(subtitleProvidersProvider));
});
