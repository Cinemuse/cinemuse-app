import 'dart:async';
import 'package:cinemuse_app/core/services/media/tmdb_service.dart';
import 'package:cinemuse_app/core/services/streaming/unified_stream_resolver.dart';
import 'package:cinemuse_app/features/video_player/application/handlers/rd_handler.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/core/services/streaming/models/provider_search_status.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/core/services/streaming/models/resolved_stream.dart';
import 'package:media_kit/media_kit.dart';
import 'package:flutter/foundation.dart';

class VodInitializationResult {
  final List<StreamCandidate> candidates;
  final ResolvedStream resolvedStream;
  final Map<String, dynamic>? mediaDetails;

  VodInitializationResult({
    required this.candidates,
    required this.resolvedStream,
    this.mediaDetails,
  });
}

class VodSourceHandler {
  final RdHandler _rdHandler;
  final UnifiedStreamResolver _resolver;
  final TmdbService _tmdbService;
  final Player _player;

  VodSourceHandler(this._rdHandler, this._resolver, this._tmdbService, this._player);

  Future<VodInitializationResult> initialize(
    PlayerParams params, {
    required Function(List<ProviderSearchStatus>) onStatusUpdate,
    required Function(Map<String, dynamic>?) onMediaDetailsFetched,
  }) async {
    final mediaDetails = await _fetchMediaDetails(params, onMediaDetailsFetched);
    final candidates = await _searchAvailableStreams(params, onStatusUpdate);
    final resolution = await _resolveBestStream(params, candidates);
    
    await _player.open(Media(resolution.stream.url), play: true);

    return VodInitializationResult(
      candidates: candidates,
      resolvedStream: resolution.stream,
      mediaDetails: mediaDetails,
    );
  }

  Future<Map<String, dynamic>?> _fetchMediaDetails(
    PlayerParams params, 
    Function(Map<String, dynamic>?) onFetched
  ) async {
    final details = await _tmdbService.getMediaDetails(params.queryId, params.type);
    onFetched(details);
    return details;
  }

  Future<List<StreamCandidate>> _searchAvailableStreams(
    PlayerParams params,
    Function(List<ProviderSearchStatus>) onStatusUpdate
  ) async {
    final candidates = await _resolver.searchStreams(
      params.queryId, 
      params.type, 
      season: params.season, 
      episode: params.episode,
      onStatusUpdate: onStatusUpdate,
    );

    if (candidates.isEmpty) {
      throw Exception("No streams found for this content.");
    }
    return candidates;
  }

  Future<({ResolvedStream stream, StreamCandidate candidate})> _resolveBestStream(
    PlayerParams params,
    List<StreamCandidate> candidates
  ) async {
    for (var candidate in candidates) {
      try {
        final resolvedStream = await _rdHandler.resolveAndMerge(
          candidate,
          season: params.season,
          episode: params.episode,
        );

        if (resolvedStream != null) {
          return (stream: resolvedStream, candidate: candidate);
        }
      } catch (e) {
        debugPrint('VodSourceHandler: Failed to resolve candidate: $e');
      }
    }

    throw Exception("All streams failed to resolve. Please try a different provider or quality.");
  }
}
