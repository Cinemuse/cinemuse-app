import 'package:cast/cast.dart';
import 'package:cinemuse_app/core/services/stream_resolver.dart';

class CastHandler {
  CastSession? _castSession;
  final StreamResolver _resolver;
  final String _rdKey;

  CastHandler(this._resolver, this._rdKey);

  bool get isCasting => _castSession != null;

  Future<void> startCasting(
    CastDevice device, 
    Map<String, dynamic> currentStream, 
    String title, 
    Duration currentPosition,
    Function(Map<String, dynamic>) onStreamResolved,
  ) async {
    try {
      _castSession = await CastSessionManager().startSession(device);
      
      String? urlToCasting = currentStream['url'];

      // Lazy resolution if URL is missing (e.g. magnet source)
      if (urlToCasting == null && currentStream.containsKey('magnet')) {
        print('CastHandler: URL missing, attempting lazy resolution...');
        final streamData = await _resolver.resolveStream(currentStream['magnet'], _rdKey);
        if (streamData != null) {
          urlToCasting = streamData['url'];
          onStreamResolved({...currentStream, ...streamData});
        }
      }

      if (urlToCasting == null) {
        throw Exception("No castable URL found");
      }

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
