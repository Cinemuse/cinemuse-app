import 'package:cinemuse_app/core/services/streaming/models/media_context.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/core/services/streaming/sources/base_source.dart';

/// A simple mock source to demonstrate how easy it is to add new providers.
class DummySource extends BaseSource {
  @override
  String get name => 'DummySource';

  @override
  Set<String> get supportedCategories => {'movie', 'tv'};

  @override
  Future<List<StreamCandidate>> search(MediaContext context) async {
    // Simulate finding a high quality stream for any search
    return [
      StreamCandidate(
        title: 'Cinemuse [Dummy Source] ${context.type == 'movie' ? 'Movie' : 'Series'} 4K HDR ITA',
        infoHash: 'dummyhash1234567890',
        magnet: 'magnet:?xt=urn:btih:dummyhash1234567890',
        seeds: 999,
        provider: 'DummySource',
      ),
    ];
  }
}
