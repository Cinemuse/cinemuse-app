import 'dart:developer' as developer;
import 'package:cinemuse_app/features/streaming/models/resolved_stream.dart';
import 'package:cinemuse_app/features/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/features/streaming/ranking/language_codes.dart';
import 'package:cinemuse_app/features/streaming/unified_stream_resolver.dart';
import 'package:cinemuse_app/features/video_player/application/helpers/player_engine_configurator.dart';
import 'package:media_kit/media_kit.dart';

/// Whether [candidate]'s name says it has sound in [language] (a setting's
/// code, such as `it`), or MULTI, which often does.
bool soundMayBeIn(StreamCandidate candidate, String language) {
  final languages = candidate.metadata?.languages ?? const [];
  return languages.contains(LanguageCodes.normalize(language)) ||
      languages.contains(LanguageCodes.multi);
}

/// Manages retry counters, candidate deduplication, and automatic soft-retries
/// or candidate fallbacks during playback errors or premature video completions.
class StreamFallbackManager {
  final Set<String> _exhaustedCandidateIds = {};
  int _retryCount = 0;

  static const int maxRetries = 2;

  /// The saved spot the film or episode opened at, until the player shows
  /// it got there. A source switch or a reconnect in the first seconds read
  /// the player's 0:00 and started the next source from the beginning.
  Duration? _resumeAt;

  /// How close to the saved spot counts as there: mpv may start a little
  /// before it.
  static const _arrivedMargin = Duration(seconds: 5);

  /// The film or episode opens at [position]; zero is the beginning.
  void resumeAt(Duration position) =>
      _resumeAt = position > Duration.zero ? position : null;

  /// The user moved the video: from now on their spot counts.
  void forgetResumePoint() => _resumeAt = null;

  /// Where the next source or a reconnect starts: the saved spot until
  /// [playerPosition] shows the player got there, then [playerPosition].
  Duration restartPosition(Duration playerPosition) {
    final resume = _resumeAt;
    if (resume == null) return playerPosition;
    if (playerPosition >= resume - _arrivedMargin) {
      _resumeAt = null;
      return playerPosition;
    }
    return resume;
  }

  int get retryCount => _retryCount;
  bool get canSoftRetry => _retryCount < maxRetries;

  void recordRetryAttempt() {
    _retryCount++;
  }

  void resetRetryCount() {
    _retryCount = 0;
  }

  void clearExhausted() {
    _exhaustedCandidateIds.clear();
  }

  void markExhausted(StreamCandidate candidate) {
    _exhaustedCandidateIds.add(candidate.uniqueId);
    if (candidate.infoHash.isNotEmpty) {
      _exhaustedCandidateIds.add(candidate.infoHash.toLowerCase());
    }
  }

  /// Selects the next untried candidate from [availableStreams] (only one
  /// that passes [where], when given), marking the [currentStream] and
  /// selected candidate as exhausted.
  ///
  /// Returns `null` if all candidates have been exhausted.
  StreamCandidate? selectNextCandidate({
    required List<StreamCandidate> availableStreams,
    ResolvedStream? currentStream,
    bool Function(StreamCandidate)? where,
  }) {
    if (currentStream != null) {
      _exhaustedCandidateIds.add(currentStream.candidate.uniqueId);
      if (currentStream.candidate.infoHash.isNotEmpty) {
        _exhaustedCandidateIds.add(
          currentStream.candidate.infoHash.toLowerCase(),
        );
      }
      if (currentStream.url.isNotEmpty) {
        _exhaustedCandidateIds.add(currentStream.url);
      }
      final candidateUrl = currentStream.candidate.url;
      if (candidateUrl != null && candidateUrl.isNotEmpty) {
        _exhaustedCandidateIds.add(candidateUrl);
      }
    }

    final nextCandidate = availableStreams.where((c) {
      if (_exhaustedCandidateIds.contains(c.uniqueId)) return false;
      if (c.infoHash.isNotEmpty &&
          _exhaustedCandidateIds.contains(c.infoHash.toLowerCase())) {
        return false;
      }
      if (c.url != null && _exhaustedCandidateIds.contains(c.url)) {
        return false;
      }
      return where == null || where(c);
    }).firstOrNull;

    if (nextCandidate == null) return null;

    markExhausted(nextCandidate);
    _retryCount = 0;
    return nextCandidate;
  }

  /// Performs a soft reconnection attempt on the current candidate at its last known position.
  Future<void> performSoftRetry({
    required Player player,
    required UnifiedStreamResolver resolver,
    required StreamCandidate candidate,
    required int? season,
    required int? episode,
    required int? fileId,
    required void Function() onResolving,
    required void Function(ResolvedStream stream) onSuccess,
    required void Function(dynamic error, StackTrace st) onError,
  }) async {
    final lastPosition = restartPosition(player.state.position);
    onResolving();

    try {
      final resolvedStream = await resolver.resolveStream(
        candidate,
        season: season,
        episode: episode,
        fileId: fileId,
      );

      if (resolvedStream == null) {
        throw Exception('Failed to re-resolve stream during auto-retry');
      }

      // Same file again: it opens where it was, even when its length
      // comes too late for the seek below.
      await PlayerEngineConfigurator.openStream(
        player,
        resolvedStream,
        play: false,
        start: lastPosition > Duration.zero ? lastPosition : null,
      );

      final duration = await player.stream.duration
          .firstWhere((d) => d.inSeconds > 0)
          .timeout(const Duration(seconds: 5), onTimeout: () => Duration.zero);

      if (duration > Duration.zero) {
        final seekTo = lastPosition < duration ? lastPosition : Duration.zero;
        await player.seek(seekTo);
      }

      await player.play();
      onSuccess(resolvedStream);
    } catch (e, st) {
      developer.log(
        'Auto-retry failed',
        name: 'VideoPlayer.StreamFallbackManager',
        error: e,
        stackTrace: st,
        level: 900,
      );
      onError(e, st);
    }
  }
}
