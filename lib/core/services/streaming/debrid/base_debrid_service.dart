import 'package:cinemuse_app/core/services/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/core/services/streaming/models/resolved_stream.dart';

abstract class BaseDebridService {
  String get name;
  bool get isEnabled;
  Future<Map<String, bool>> checkAvailability(List<String> hashes);
  Future<ResolvedStream?> resolve(
    StreamCandidate candidate, {
    int? season,
    int? episode,
    int? fileId,
  });
}
