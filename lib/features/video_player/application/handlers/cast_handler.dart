import 'package:cast/cast.dart';
import 'package:cinemuse_app/core/services/streaming/unified_stream_resolver.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_candidate.dart';

class CastHandler {
  CastSession? _castSession;
  final UnifiedStreamResolver _resolver;

  CastHandler(this._resolver);

  bool get isCasting => _castSession != null;

  Future<void> startCasting(
    CastDevice device, 
    StreamCandidate candidate, 
    String title, 
    Duration currentPosition,
    Function(Map<String, dynamic>) onStreamResolved, {
    int? season,
    int? episode,
    int? absoluteEpisode,
  }) async {
    try {
      _castSession = await CastSessionManager().startSession(device);
      
      // Attempt to resolve if it's just a magnet
      final streamData = await _resolver.resolveStream(
        candidate,
        season: season,
        episode: episode,
      );

      if (streamData == null || streamData['url'] == null) {
        throw Exception("No castable URL found");
      }

      final urlToCasting = streamData['url'];
      onStreamResolved({...candidate.toLegacyMap(), ...streamData});

      _castSession!.sendMessage('Media', {
        'type': 'LOAD',
        'autoPlay': true,
        'currentTime': currentPosition.inSeconds,
        'media': {
          'contentId': urlToCasting,
          'contentType': 'video/mp4',
          'streamType': 'BUFFERED',
          'metadata': {
            'metadataType': 0,
            'title': title,
          },
        },
      });
      
      print('CastHandler: Casting started to ${device.name}');
    } catch (e) {
      print('CastHandler: Error starting cast: $e');
      stopCasting();
      rethrow;
    }
  }

  void stopCasting() {
    _castSession = null;
  }
}
