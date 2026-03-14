import 'package:cinemuse_app/core/services/streaming/models/resolved_stream.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_metadata.dart';

/// Represents a normalized stream result from various sources.
/// 
/// This class acts as the single source of truth for the UI and the resolution logic,
/// abstracting away source-specific data structures.
class StreamCandidate {
  /// The display title extracted from the source (usually contains metadata like quality, release group).
  final String title;

  /// The InfoHash of the torrent (if applicable). Used for deduplication and availability checks.
  final String infoHash;

  /// The full magnet URI including tracker information.
  final String magnet;

  /// The number of seeders reported by the source. Used for ranking uncached results.
  final int seeds;

  /// The human-readable name of the source that found this result.
  final String provider;

  /// Used specifically for content with absolute sequence numbers (common in some animation formats).
  final int? absoluteEpisode;

  /// Structured metadata about the stream (Video, Audio, Languages, etc.).
  final StreamMetadata? metadata;

  /// The final calculated priority score used for sorting the list in the UI.
  final int score;

  /// Tracks which external services have this file cached (Service Name -> Is Available).
  /// A candidate is considered instantly playable if any value here is true.
  final Map<String, bool> cachedOn;

  /// A direct playback URL.
  /// If this is present, the resolution phase may be bypassed.
  final String? url;

  /// The total file size in bytes. Useful for sorting and user information.
  final int? sizeInBytes;

  /// Explicit resolution string (e.g., '4K', '1080p') for direct access in UI.
  final String? resolution;

  /// Custom HTTP headers required for playback (e.g. Referer, User-Agent).
  final Map<String, String>? headers;

  StreamCandidate({
    required this.title,
    required this.infoHash,
    required this.magnet,
    this.seeds = 0,
    required this.provider,
    this.absoluteEpisode,
    this.metadata,
    this.score = 0,
    this.cachedOn = const {},
    this.url,
    this.sizeInBytes,
    this.resolution,
    this.headers,
  });

  /// True if the stream is cached on at least one Debrid provider.
  bool get isCached => cachedOn.values.any((v) => v);

  /// A robust unique identifier for the stream.
  /// Priority: infoHash > url > fallback (provider:title)
  String get uniqueId {
    if (infoHash.isNotEmpty) return infoHash.toLowerCase();
    if (url != null && url!.isNotEmpty) return url!.toLowerCase();
    // Normalize title for fallback identification
    final normalizedTitle = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return "${provider.toLowerCase()}:$normalizedTitle";
  }

  StreamCandidate copyWith({
    int? score,
    Map<String, bool>? cachedOn,
    StreamMetadata? metadata,
  }) {
    return StreamCandidate(
      title: title,
      infoHash: infoHash,
      magnet: magnet,
      seeds: seeds,
      provider: provider,
      absoluteEpisode: absoluteEpisode,
      metadata: metadata ?? this.metadata,
      score: score ?? this.score,
      cachedOn: cachedOn ?? this.cachedOn,
      url: url,
      sizeInBytes: sizeInBytes,
      resolution: resolution,
      headers: headers,
    );
  }
}
