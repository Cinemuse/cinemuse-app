import 'package:cinemuse_app/core/services/streaming/models/stream_candidate.dart';

class ResolvedStream {
  final String url;
  final String? mimeType;
  final String? filename;
  final List<Map<String, dynamic>> files;
  final int? activeFileId;
  final String provider; // The name of the service that resolved this stream
  final StreamCandidate candidate; // The original candidate this came from
  final Map<String, String>? headers;

  ResolvedStream({
    required this.url,
    this.mimeType,
    this.filename,
    this.files = const [],
    this.activeFileId,
    required this.provider,
    required this.candidate,
    this.headers,
  });

  // Legacy map support removed to favor typed models
}
