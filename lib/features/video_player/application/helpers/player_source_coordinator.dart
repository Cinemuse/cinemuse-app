import 'dart:async';
import 'dart:developer' as developer;
import 'package:cinemuse_app/core/application/l10n_provider.dart';
import 'package:cinemuse_app/core/error/error_mappers.dart';
import 'package:cinemuse_app/core/services/streaming/models/resolved_stream.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/core/services/streaming/unified_stream_resolver.dart';
import 'package:cinemuse_app/features/video_player/application/handlers/livetv_playback_coordinator.dart';
import 'package:cinemuse_app/features/video_player/application/handlers/youtube_source_handler.dart';
import 'package:cinemuse_app/features/video_player/application/helpers/stream_fallback_manager.dart';
import 'package:cinemuse_app/features/video_player/application/managers/track_manager.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

/// Coordinates source switching, file switching, errors, and failover fallbacks.
class PlayerSourceCoordinator {
  final Ref ref;
  final Player player;
  final PlayerParams Function() getResolvedParams;
  final YouTubeSourceHandler youtubeSourceHandler;
  final UnifiedStreamResolver resolver;
  final StreamFallbackManager fallbackManager;
  final TrackManager? Function() getTrackManager;
  final LiveTvPlaybackCoordinator? Function() getLiveTvCoordinator;
  final bool Function() isMounted;
  final CinemaPlayerState? Function() getCurrentState;
  final void Function(CinemaPlayerState) onStateChanged;
  final void Function(dynamic error, StackTrace st) onError;
  final Future<void> Function({bool force}) saveProgress;

  PlayerSourceCoordinator({
    required this.ref,
    required this.player,
    required this.getResolvedParams,
    required this.youtubeSourceHandler,
    required this.resolver,
    required this.fallbackManager,
    required this.getTrackManager,
    required this.getLiveTvCoordinator,
    required this.isMounted,
    required this.getCurrentState,
    required this.onStateChanged,
    required this.onError,
    required this.saveProgress,
  });

  Future<void> changeSource(
    StreamCandidate candidate, {
    bool isManual = true,
  }) async {
    final currentState = getCurrentState();
    if (currentState == null) return;

    if (isManual) fallbackManager.clearExhausted();

    onStateChanged(
      currentState.copyWith(
        isResolving: true,
        error: null,
        notification: isManual ? null : currentState.notification,
      ),
    );

    try {
      final position = player.state.position;

      switch (candidate.kind) {
        case StreamSourceKind.youtube:
          await _changeToYouTubeSource(candidate, position);
          break;
        case StreamSourceKind.vod:
          await _changeToVodSource(candidate, position);
          break;
        case StreamSourceKind.live:
          throw Exception(
            "Cannot change source on Live TV kind via changeSource.",
          );
      }
    } catch (e, st) {
      developer.log(
        'Error changing source: $e',
        name: 'VideoPlayer.PlayerSourceCoordinator',
        error: e,
        stackTrace: st,
        level: 900,
      );
      if (!isManual) {
        if (tryNextCandidate()) return;
      }
      if (isMounted()) {
        final current = getCurrentState();
        if (current != null) {
          onStateChanged(
            current.copyWith(
              isResolving: false,
              error: ref.read(errorMapperProvider).map(e).message,
            ),
          );
        }
      }
    }
  }

  Future<void> _changeToYouTubeSource(
    StreamCandidate candidate,
    Duration position,
  ) async {
    final meta = candidate.metadata;
    String? localAudioPath;
    if (meta?.custom?['needsAudio'] == true) {
      localAudioPath = await youtubeSourceHandler.downloadAudioToTempFile();
    }

    final resolvedStream = ResolvedStream(
      url: candidate.url!,
      provider: candidate.provider,
      candidate: candidate,
      headers: youtubeSourceHandler.youtubeHeaders,
    );

    await player.open(
      Media(resolvedStream.url, httpHeaders: resolvedStream.headers),
      play: false,
    );

    if (localAudioPath != null) {
      await player.setAudioTrack(AudioTrack.uri(localAudioPath));
    }

    await _finalizeSourceChange(resolvedStream, position);
  }

  Future<void> _changeToVodSource(
    StreamCandidate candidate,
    Duration position,
  ) async {
    final resolvedParams = getResolvedParams();
    final resolvedStream = await resolver.resolveStream(
      candidate,
      season: resolvedParams.season,
      episode: resolvedParams.episode,
    );

    if (resolvedStream == null) {
      throw Exception(
        ref.read(localizationsProvider).streamingErrorResolutionFailed,
      );
    }

    await player.open(
      Media(resolvedStream.url, httpHeaders: resolvedStream.headers),
      play: false,
    );
    unawaited(
      getTrackManager()?.ensurePreferredTrack(
            isAnime: getCurrentState()?.isAnime ?? false,
          ) ??
          Future.value(),
    );

    await _finalizeSourceChange(resolvedStream, position);
  }

  Future<void> _finalizeSourceChange(
    ResolvedStream resolvedStream,
    Duration position,
  ) async {
    final newDuration = await player.stream.duration.firstWhere(
      (d) => d.inSeconds > 0,
    );
    final seekTo = position.inSeconds < newDuration.inSeconds
        ? position
        : Duration(seconds: newDuration.inSeconds - 2);

    await player.seek(seekTo.isNegative ? Duration.zero : seekTo);
    await player.play();

    if (isMounted()) {
      fallbackManager.resetRetryCount();
      final current = getCurrentState();
      if (current != null) {
        onStateChanged(
          current.copyWith(
            currentStream: resolvedStream,
            isResolving: false,
            error: null,
          ),
        );
      }
    }
  }

  Future<void> changeFile(int fileId) async {
    final current = getCurrentState();
    if (current == null || current.currentStream == null) {
      return;
    }

    onStateChanged(current.copyWith(isResolving: true, error: null));

    try {
      final resolvedStream = await resolver.resolveStream(
        current.currentStream!.candidate,
        fileId: fileId,
      );

      if (resolvedStream != null) {
        await player.open(Media(resolvedStream.url), play: true);
        unawaited(
          getTrackManager()?.ensurePreferredTrack(
                isAnime: getCurrentState()?.isAnime ?? false,
              ) ??
              Future.value(),
        );

        if (isMounted()) {
          final updated = getCurrentState();
          if (updated != null) {
            onStateChanged(
              updated.copyWith(
                currentStream: resolvedStream,
                isResolving: false,
                error: null,
              ),
            );
          }
        }
      } else {
        if (isMounted()) {
          final updated = getCurrentState();
          if (updated != null) {
            onStateChanged(
              updated.copyWith(
                isResolving: false,
                error: "Failed to resolve the selected file.",
              ),
            );
          }
        }
      }
    } catch (e, st) {
      developer.log(
        'Error changing file: $e',
        name: 'VideoPlayer.PlayerSourceCoordinator',
        error: e,
        stackTrace: st,
        level: 900,
      );
      if (isMounted()) {
        final updated = getCurrentState();
        if (updated != null) {
          onStateChanged(
            updated.copyWith(
              isResolving: false,
              error: "Error changing file: ${e.toString()}",
            ),
          );
        }
      }
    }
  }

  Future<void> handlePlaybackCompleted() async {
    final resolvedParams = getResolvedParams();
    if (resolvedParams.type == 'livetv') {
      final liveTvCoordinator = getLiveTvCoordinator();
      if (liveTvCoordinator?.isChangingChannel == true) {
        developer.log(
          'Ignoring EOS during channel change.',
          name: 'VideoPlayer.PlayerSourceCoordinator',
        );
        return;
      }
      developer.log(
        'Live TV EOS. Retrying same link...',
        name: 'VideoPlayer.PlayerSourceCoordinator',
      );
      liveTvCoordinator?.handleFailover(
        'Stream ended (EOS)',
        isConnectionError: false,
      );
      return;
    }

    if (resolvedParams.type != 'youtube') {
      final position = player.state.position;
      final duration = player.state.duration;
      if (duration > Duration.zero &&
          (duration < const Duration(seconds: 30) ||
              (position < const Duration(seconds: 30) &&
                  duration < const Duration(minutes: 3)))) {
        developer.log(
          'Premature playback completion detected (duration: $duration, pos: $position). Triggering candidate failover...',
          name: 'VideoPlayer.PlayerSourceCoordinator',
          level: 800,
        );
        if (tryNextCandidate()) return;
      }
    }

    await saveProgress(force: true);

    developer.log(
      'Playback finished. Ready for next actions.',
      name: 'VideoPlayer.PlayerSourceCoordinator',
    );
  }

  void handlePlayerError(String error) {
    final resolvedParams = getResolvedParams();
    if (resolvedParams.type == 'livetv') {
      final liveTvCoordinator = getLiveTvCoordinator();
      if (liveTvCoordinator?.isChangingChannel == true) {
        developer.log(
          'Ignoring Error during channel change: $error',
          name: 'VideoPlayer.PlayerSourceCoordinator',
        );
        return;
      }
      liveTvCoordinator?.handleFailover(error, isConnectionError: true);
      return;
    }

    final lowerError = error.toLowerCase();
    if (lowerError.contains('already selected') ||
        lowerError.contains('track')) {
      developer.log(
        'Ignoring benign MPV error: $error',
        name: 'VideoPlayer.PlayerSourceCoordinator',
        level: 500,
      );
      return;
    }

    if (isMounted()) {
      final currentState = getCurrentState();
      if (currentState != null &&
          currentState.currentStream != null &&
          fallbackManager.canSoftRetry) {
        fallbackManager.recordRetryAttempt();
        developer.log(
          'Auto-retrying playback (attempt ${fallbackManager.retryCount}/${StreamFallbackManager.maxRetries}) after error: $error',
          name: 'VideoPlayer.PlayerSourceCoordinator',
          level: 800,
        );
        performSoftRetry();
        return;
      }

      if (tryNextCandidate()) return;

      onError(error, StackTrace.current);
    }
  }

  bool tryNextCandidate() {
    final currentState = getCurrentState();
    if (currentState == null) return false;

    final nextCandidate = fallbackManager.selectNextCandidate(
      availableStreams: currentState.availableStreams,
      currentStream: currentState.currentStream,
    );

    if (nextCandidate == null) return false;

    developer.log(
      'Falling back to next candidate: ${nextCandidate.provider} (${nextCandidate.title})',
      name: 'VideoPlayer.PlayerSourceCoordinator',
    );

    final message = ref.read(localizationsProvider).playerTryingNextSource;
    if (isMounted() && getCurrentState() != null) {
      onStateChanged(getCurrentState()!.copyWith(notification: message));
    }

    changeSource(nextCandidate, isManual: false);
    return true;
  }

  Future<void> performSoftRetry() async {
    final currentState = getCurrentState();
    if (currentState == null || currentState.currentStream == null) {
      return;
    }

    final candidate = currentState.currentStream!.candidate;
    final resolvedParams = getResolvedParams();

    await fallbackManager.performSoftRetry(
      player: player,
      resolver: resolver,
      candidate: candidate,
      season: resolvedParams.season,
      episode: resolvedParams.episode,
      fileId: currentState.currentStream?.activeFileId,
      onResolving: () {
        if (isMounted()) {
          final current = getCurrentState();
          if (current != null) {
            onStateChanged(
              current.copyWith(
                isResolving: true,
                providerStatuses: const [],
                error: null,
              ),
            );
          }
        }
      },
      onSuccess: (resolvedStream) {
        if (isMounted()) {
          final current = getCurrentState();
          if (current != null) {
            onStateChanged(
              current.copyWith(
                currentStream: resolvedStream,
                isResolving: false,
              ),
            );
          }
        }
      },
      onError: (e, st) {
        if (isMounted()) {
          onError(e.toString(), st);
        }
      },
    );
  }
}
