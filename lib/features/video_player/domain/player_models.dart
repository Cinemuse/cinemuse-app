import 'package:cinemuse_app/core/services/streaming/models/resolved_stream.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_candidate.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:cast/cast.dart';
import 'package:cinemuse_app/core/services/streaming/models/provider_search_status.dart';
import 'package:cinemuse_app/features/media/application/series_domain_service.dart';

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

class CinemaPlayerState {
  final VideoController controller;
  final List<StreamCandidate> availableStreams;
  final ResolvedStream? currentStream;
  final String title;
  final NextEpisodeInfo? nextEpisode;
  final bool isCasting;
  final bool isResolving;
  final String? error;
  final CastDevice? selectedCastDevice;
  final Duration remotePosition;
  final Duration remoteDuration;
  final bool remotePlaying;
  final List<ProviderSearchStatus> providerStatuses;

  CinemaPlayerState({
    required this.controller,
    required this.availableStreams,
    required this.currentStream,
    required this.title,
    this.nextEpisode,
    this.isCasting = false,
    this.isResolving = false,
    this.error,
    this.selectedCastDevice,
    this.remotePosition = Duration.zero,
    this.remoteDuration = Duration.zero,
    this.remotePlaying = false,
    this.providerStatuses = const [],
  });

  CinemaPlayerState copyWith({
    VideoController? controller,
    List<StreamCandidate>? availableStreams,
    Object? currentStream = _sentinel,
    String? title,
    Object? nextEpisode = _sentinel,
    bool? isCasting,
    bool? isResolving,
    Object? error = _sentinel,
    Object? selectedCastDevice = _sentinel,
    Duration? remotePosition,
    Duration? remoteDuration,
    bool? remotePlaying,
    List<ProviderSearchStatus>? providerStatuses,
  }) {
    return CinemaPlayerState(
      controller: controller ?? this.controller,
      availableStreams: availableStreams ?? this.availableStreams,
      currentStream: currentStream == _sentinel ? this.currentStream : (currentStream as ResolvedStream?),
      title: title ?? this.title,
      nextEpisode: nextEpisode == _sentinel ? this.nextEpisode : (nextEpisode as NextEpisodeInfo?),
      isCasting: isCasting ?? this.isCasting,
      isResolving: isResolving ?? this.isResolving,
      error: error == _sentinel ? this.error : (error as String?),
      selectedCastDevice: selectedCastDevice == _sentinel ? this.selectedCastDevice : (selectedCastDevice as CastDevice?),
      remotePosition: remotePosition ?? this.remotePosition,
      remoteDuration: remoteDuration ?? this.remoteDuration,
      remotePlaying: remotePlaying ?? this.remotePlaying,
      providerStatuses: providerStatuses ?? this.providerStatuses,
    );
  }
}

const Object _sentinel = Object();
