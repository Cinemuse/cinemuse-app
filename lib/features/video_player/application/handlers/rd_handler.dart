import 'package:cinemuse_app/core/services/streaming/models/resolved_stream.dart';
import 'package:cinemuse_app/core/services/streaming/unified_stream_resolver.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_candidate.dart';
import 'package:flutter/foundation.dart';

class RdHandler {
  final UnifiedStreamResolver _resolver;

  RdHandler(this._resolver);

  Future<ResolvedStream?> resolveAndMerge(
    StreamCandidate candidate, {
    int? season, 
    int? episode, 
    int? absoluteEpisode,
    int? fileId,
  }) async {
    try {
      final streamData = await _resolver.resolveStream(
        candidate,
        season: season,
        episode: episode,
        fileId: fileId,
      );
      
      if (streamData != null) {
        return streamData;
      }
    } catch (e) {
      debugPrint('RdHandler: Resolve failed: $e');
    }

    return null;
  }

  void dispose() {}
}
