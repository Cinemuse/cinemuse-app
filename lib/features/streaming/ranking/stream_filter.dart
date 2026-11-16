import 'package:cinemuse_app/features/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/features/streaming/models/stream_metadata.dart';
import 'package:cinemuse_app/features/streaming/ranking/stream_parser.dart';

/// Removes unwanted streams before ranking: low-quality releases (smart
/// filter) and streams above the user's maximum resolution.
///
/// Both filters use only the details [StreamParser] stored with the stream.
class StreamFilter {
  /// Returns [candidates] without the unwanted streams.
  static List<StreamCandidate> apply(
    List<StreamCandidate> candidates, {
    required bool smartFilter,
    required VideoResolution maxResolution,
  }) {
    return candidates.where((c) {
      if (smartFilter && isLowQuality(c)) return false;
      return !isAboveMaxResolution(c, maxResolution);
    }).toList();
  }

  /// True for CAM, telesync, screener and 3D releases.
  static bool isLowQuality(StreamCandidate candidate) {
    final metadata = _metadata(candidate);
    return metadata.quality == ReleaseQuality.cam ||
        metadata.quality == ReleaseQuality.telesync ||
        metadata.flags.contains(ReleaseFlag.screener) ||
        metadata.flags.contains(ReleaseFlag.threeD);
  }

  /// True when the stream's resolution is known and above [maxResolution].
  /// [VideoResolution.unknown] as the limit means "no limit".
  static bool isAboveMaxResolution(
    StreamCandidate candidate,
    VideoResolution maxResolution,
  ) {
    if (maxResolution == VideoResolution.unknown) return false;

    final resolution = _metadata(candidate).video.resolution;
    // Higher resolutions come first in the enum.
    return resolution != VideoResolution.unknown &&
        resolution.index < maxResolution.index;
  }

  static StreamMetadata _metadata(StreamCandidate candidate) =>
      candidate.metadata ?? StreamParser.parse(candidate.title);
}
