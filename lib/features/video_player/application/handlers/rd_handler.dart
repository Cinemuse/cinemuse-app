import 'package:cinemuse_app/core/services/stream_resolver.dart';

class RdHandler {
  final StreamResolver _resolver;
  final String _rdKey;

  RdHandler(this._resolver, this._rdKey);

  Future<Map<String, dynamic>?> resolveAndMerge(Map<String, dynamic> stream) async {
    int retryCount = 0;
    const maxRetries = 3;
    Map<String, dynamic>? streamData;

    while (retryCount < maxRetries) {
      try {
        streamData = await _resolver.resolveStream(stream['magnet'], _rdKey);
        if (streamData != null && streamData['url'] != null) {
          return {...stream, ...streamData};
        }
      } catch (e) {
        print('RdHandler: Stream resolution attempt ${retryCount + 1} failed: $e');
      }
      
      retryCount++;
      if (retryCount < maxRetries) {
        await Future.delayed(Duration(seconds: retryCount));
      }
    }

    return null;
  }
}
