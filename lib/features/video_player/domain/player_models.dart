import 'package:media_kit_video/media_kit_video.dart';
import 'package:cast/cast.dart';

// Simple data class for params
class PlayerParams {
  final String queryId;
  final String type;
  final int? season;
  final int? episode;
  final String? episodeTitle;
  final int startPosition;

  const PlayerParams(this.queryId, this.type, {
    this.season, 
    this.episode, 
    this.episodeTitle,
    this.startPosition = 0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayerParams &&
          runtimeType == other.runtimeType &&
          queryId == other.queryId &&
          type == other.type &&
          season == other.season &&
          episode == other.episode &&
          episodeTitle == other.episodeTitle &&
          startPosition == other.startPosition;

  @override
  int get hashCode => Object.hash(queryId, type, season, episode, episodeTitle, startPosition);
}

class NextEpisodeInfo {
  final int season;
  final int episode;
  final String? title;

  NextEpisodeInfo({required this.season, required this.episode, this.title});
}

class CinemaPlayerState {
  final VideoController controller;
  final List<Map<String, dynamic>> availableStreams;
  final Map<String, dynamic> currentStream;
  final String title;
  final NextEpisodeInfo? nextEpisode;
  final bool isCasting;
  final CastDevice? selectedCastDevice;

  CinemaPlayerState({
    required this.controller,
    required this.availableStreams,
    required this.currentStream,
    required this.title,
    this.nextEpisode,
    this.isCasting = false,
    this.selectedCastDevice,
  });

  CinemaPlayerState copyWith({
    VideoController? controller,
    List<Map<String, dynamic>>? availableStreams,
    Map<String, dynamic>? currentStream,
    String? title,
    NextEpisodeInfo? nextEpisode,
    bool? isCasting,
    CastDevice? selectedCastDevice,
  }) {
    return CinemaPlayerState(
      controller: controller ?? this.controller,
      availableStreams: availableStreams ?? this.availableStreams,
      currentStream: currentStream ?? this.currentStream,
      title: title ?? this.title,
      nextEpisode: nextEpisode ?? this.nextEpisode,
      isCasting: isCasting ?? this.isCasting,
      selectedCastDevice: selectedCastDevice ?? this.selectedCastDevice,
    );
  }
}
