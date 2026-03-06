import 'package:cinemuse_app/core/services/streaming/models/media_context.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_candidate.dart';

abstract class BaseSource {
  String get name;
  Future<List<StreamCandidate>> search(MediaContext context);
}
