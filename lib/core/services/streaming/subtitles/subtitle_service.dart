import 'package:cinemuse_app/core/services/streaming/subtitles/external_subtitle.dart';
import 'package:cinemuse_app/core/services/streaming/subtitles/opensubtitles_provider.dart';
import 'package:cinemuse_app/core/services/streaming/subtitles/subtitle_provider.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SubtitleService {
  final Ref _ref;

  SubtitleService(this._ref);

  List<SubtitleProvider> get _providers {
    final settings = _ref.read(settingsProvider);
    final providers = <SubtitleProvider>[];

    if (settings.openSubtitlesKey.isNotEmpty) {
      providers.add(OpenSubtitlesProvider(settings.openSubtitlesKey));
    }

    // Add other providers here in the future
    return providers;
  }

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
    if (activeProviders.isEmpty) return [];

    final List<ExternalSubtitle> allResults = [];

    // Run searches in parallel
    final futures = activeProviders.map((provider) => provider.search(
          imdbId: imdbId,
          tmdbId: tmdbId,
          season: season,
          episode: episode,
          query: query,
          language: language,
        ));

    final resultsList = await Future.wait(futures);

    for (var list in resultsList) {
      allResults.addAll(list);
    }

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

final subtitleServiceProvider = Provider<SubtitleService>((ref) {
  return SubtitleService(ref);
});
