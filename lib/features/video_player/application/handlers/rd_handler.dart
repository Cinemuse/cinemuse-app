import 'package:cinemuse_app/core/services/streaming/unified_stream_resolver.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_candidate.dart';

class RdHandler {
  final UnifiedStreamResolver _resolver;

  RdHandler(this._resolver);

  Future<Map<String, dynamic>?> resolveAndMerge(
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
        return {...candidate.toLegacyMap(), ...streamData};
      }
    } catch (e) {
      print('RdHandler: Resolve failed: $e');
    }

    return null;
  }
}
