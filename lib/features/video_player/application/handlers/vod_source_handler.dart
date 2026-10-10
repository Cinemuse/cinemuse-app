import 'dart:async';
import 'package:cinemuse_app/features/media/data/tmdb_service.dart';
import 'package:cinemuse_app/features/streaming/unified_stream_resolver.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/streaming/models/provider_search_status.dart';
import 'package:cinemuse_app/features/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/features/streaming/models/resolved_stream.dart';
import 'package:media_kit/media_kit.dart';
import 'dart:developer' as developer;

class VodInitializationResult {
  final List<StreamCandidate> candidates;
  final ResolvedStream resolvedStream;
  final MediaItem? mediaItem;
  final Map<String, dynamic>? mediaDetails;
  final bool isAnime;

  VodInitializationResult({
    required this.candidates,
    required this.resolvedStream,
    this.mediaItem,
    this.mediaDetails,
    this.isAnime = false,
  });
}

class VodSourceHandler {
  final UnifiedStreamResolver _resolver;
  final TmdbService _tmdbService;
  final Player _player;

  VodSourceHandler(this._resolver, this._tmdbService, this._player);

  Future<VodInitializationResult> initialize(
    PlayerParams params, {
    required Function(List<ProviderSearchStatus>) onStatusUpdate,
    required Function(MediaItem?, Map<String, dynamic>?) onMediaDetailsFetched,
    Future<void>? skipTrigger,
  }) async {
    final detailsResult = await _fetchMediaDetails(
      params,
      onMediaDetailsFetched,
    );

    final searchResult = await _searchAvailableStreams(
      params,
      onStatusUpdate,
      skipTrigger: skipTrigger,
      preloadedDetails: detailsResult.raw,
    );

    final resolution = await _resolveBestStream(
      params,
      searchResult.candidates,
    );

    await _player.open(
      Media(resolution.stream.url, httpHeaders: resolution.stream.headers),
      play: true,
    );

    return VodInitializationResult(
      candidates: searchResult.candidates,
      resolvedStream: resolution.stream,
      mediaItem: detailsResult.item,
      mediaDetails: detailsResult.raw,
      isAnime: searchResult.isAnime,
    );
  }

  Future<({MediaItem? item, Map<String, dynamic>? raw})> _fetchMediaDetails(
    PlayerParams params,
    Function(MediaItem?, Map<String, dynamic>?) onFetched,
  ) async {
    final details = await _tmdbService.getMediaDetails(
      params.queryId,
      params.type,
    );
    final kind = params.type == 'movie' ? MediaKind.movie : MediaKind.tv;
    final item = details != null
        ? MediaItem.fromTmdbDetails(details, kind)
        : null;
    onFetched(item, details);
    return (item: item, raw: details);
  }

  Future<StreamSearchResult> _searchAvailableStreams(
    PlayerParams params,
    Function(List<ProviderSearchStatus>) onStatusUpdate, {
    Future<void>? skipTrigger,
    Map<String, dynamic>? preloadedDetails,
  }) async {
    final result = await _resolver.searchStreams(
      params.queryId,
      params.type,
      season: params.season,
      episode: params.episode,
      onStatusUpdate: onStatusUpdate,
      skipTrigger: skipTrigger,
      preloadedDetails: preloadedDetails,
    );

    if (result.candidates.isEmpty) {
      throw Exception("No streams found for this content.");
    }
    return result;
  }

  Future<({ResolvedStream stream, StreamCandidate candidate})>
  _resolveBestStream(
    PlayerParams params,
    List<StreamCandidate> candidates,
  ) async {
    for (var candidate in candidates) {
      try {
        final resolvedStream = await _resolver.resolveStream(
          candidate,
          season: params.season,
          episode: params.episode,
        );

        if (resolvedStream != null) {
          return (stream: resolvedStream, candidate: candidate);
        }
      } catch (e, st) {
        developer.log(
          'Failed to resolve candidate: ${candidate.title}',
          name: 'VideoPlayer.VodSourceHandler',
          error: e,
          stackTrace: st,
          level: 800,
        );
      }
    }

    throw Exception(
      "All streams failed to resolve. Please try a different provider or quality.",
    );
  }
}
