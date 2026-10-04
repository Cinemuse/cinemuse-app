import 'dart:developer' as developer;
import 'package:cinemuse_app/core/services/streaming/models/resolved_stream.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/core/services/streaming/unified_stream_resolver.dart';
import 'package:media_kit/media_kit.dart';

/// Manages retry counters, candidate deduplication, and automatic soft-retries
/// or candidate fallbacks during playback errors or premature video completions.
class StreamFallbackManager {
  final Set<String> _exhaustedCandidateIds = {};
  int _retryCount = 0;

  static const int maxRetries = 2;

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

  /// Selects the next untried candidate from [availableStreams], marking the
  /// [currentStream] and selected candidate as exhausted.
  ///
  /// Returns `null` if all candidates have been exhausted.
  StreamCandidate? selectNextCandidate({
    required List<StreamCandidate> availableStreams,
    ResolvedStream? currentStream,
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
      return true;
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
    final lastPosition = player.state.position;
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

      await player.open(
        Media(resolvedStream.url, httpHeaders: resolvedStream.headers),
        play: false,
      );

      final duration = await player.stream.duration
          .firstWhere((d) => d.inSeconds > 0)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => Duration.zero,
          );

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
