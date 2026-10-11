import 'package:cinemuse_app/features/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/features/streaming/models/stream_metadata.dart';
import 'package:cinemuse_app/features/streaming/ranking/stream_parser.dart';

/// Removes unwanted streams before ranking: low-quality releases (smart
/// filter) and streams above the user's maximum resolution.
///
/// Both filters read [StreamParser]'s metadata, so a tag counts only as a
/// whole word: "Camelot" is not a CAM release and "HDR" is not 720p
/// (STR-01, STR-02).
class StreamFilter {
  /// Release tags the parser has no [ReleaseQuality] for: screeners and 3D.
  static final _screenerOr3d = RegExp(
    r'\b(dvdscr|scr|screener|3d|h?sbs)\b',
    caseSensitive: false,
  );

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
    final quality = _metadata(candidate).quality;
    return quality == ReleaseQuality.cam ||
        quality == ReleaseQuality.telesync ||
        _screenerOr3d.hasMatch(candidate.title);
  }

  /// True when the stream's resolution is known and above [maxResolution].
  /// [VideoResolution.unknown] as the limit means "no limit".
  static bool isAboveMaxResolution(
    StreamCandidate candidate,
    VideoResolution maxResolution,
  ) {
    if (maxResolution == VideoResolution.unknown) return false;

    var resolution =
        candidate.metadata?.video.resolution ?? VideoResolution.unknown;
    if (resolution == VideoResolution.unknown) {
      resolution = StreamParser.parse(candidate.title).video.resolution;
    }
    // Higher resolutions come first in the enum.
    return resolution != VideoResolution.unknown &&
        resolution.index < maxResolution.index;
  }

  static StreamMetadata _metadata(StreamCandidate candidate) =>
      candidate.metadata ?? StreamParser.parse(candidate.title);
}
