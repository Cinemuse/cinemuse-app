import 'dart:async';
import 'dart:developer' as developer;
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/stream_link.dart';
import 'package:cinemuse_app/features/settings/domain/user_settings.dart';
import 'package:cinemuse_app/features/video_player/application/handlers/livetv_picture_size_switcher.dart';
import 'package:cinemuse_app/features/video_player/application/handlers/livetv_source_handler.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Coordinates channel switching, link selection, stall detection,
/// and automatic failover for Live TV playback.
class LiveTvPlaybackCoordinator {
  final Player player;
  final VideoController controller;
  final UserSettings Function() getSettings;
  final bool Function() isMounted;
  final CinemaPlayerState? Function() getCurrentState;
  final void Function(CinemaPlayerState newState) onStateChanged;
  final void Function(dynamic error, StackTrace st) onError;

  /// Translated "channel not available" text, shown when every link failed.
  final String Function() unavailableMessage;

  /// Translated "try a lower quality" text.
  final String Function() lowerSizeSuggestion;

  LiveTvPlaybackCoordinator({
    required this.player,
    required this.controller,
    required this.getSettings,
    required this.isMounted,
    required this.getCurrentState,
    required this.onStateChanged,
    required this.onError,
    required this.unavailableMessage,
    required this.lowerSizeSuggestion,
    Future<String> Function()? readTrackList,
  }) {
    _pictureSize = LivePictureSizeSwitcher(
      player: player,
      readTrackList:
          readTrackList ??
          () => (player.platform as NativePlayer).getProperty('track-list'),
      reopen: () => unawaited(_reopen(showSpinner: false)),
      onChanged: _emitPictureSizes,
      onSuggestLower: () => _notify(lowerSizeSuggestion()),
    );
  }

  late final LivePictureSizeSwitcher _pictureSize;
  Channel? _currentChannel;
  StreamLink? _currentLink;
  bool _isChangingChannel = false;
  int _activeRequestId = 0;
  LiveTvSourceHandler? _sourceHandler;

  /// Rounds in which every link failed; at [_maxFailedRounds] we give up.
  int _failedRounds = 0;
  Timer? _nextRoundTimer;
  StreamSubscription<Duration>? _positionSub;
  Duration? _firstPosition;

  /// An EOS means the server was streaming, so the link gets one more try.
  static const int _maxEosRetries = 1;
  static const int _maxFailedRounds = 3;

  /// A link that played this long counts as working: the counters reset.
  static const Duration _healthyPlayback = Duration(seconds: 30);

  Channel? get currentChannel => _currentChannel;
  StreamLink? get currentLink => _currentLink;
  bool get isChangingChannel => _isChangingChannel;

  void dispose() {
    _pictureSize.dispose();
    _sourceHandler?.dispose();
    _nextRoundTimer?.cancel();
    unawaited(_positionSub?.cancel());
  }

  /// Sets up a bare "ready-but-idle" initial state for Live TV.
  void initializeIdleState({required String defaultTitle}) {
    if (!isMounted()) return;
    onStateChanged(
      CinemaPlayerState(
        controller: controller,
        availableStreams: const [],
        currentStream: null,
        title: defaultTitle,
        isResolving: false,
        isLive: true,
      ),
    );
  }

  /// Switches playback to [channel].
  ///
  /// If [isFailover] is true, preserves the existing frame to prevent screen flicker.
  Future<void> changeChannel(Channel channel, {bool isFailover = false}) async {
    // Guard against multiple simultaneous failover attempts for the same issue.
    // Manual changes (!isFailover) always proceed and override.
    if (isFailover && _isChangingChannel) {
      developer.log(
        'Skipping failover request; change already in progress.',
        name: 'VideoPlayer.LiveTvCoordinator',
      );
      return;
    }

    final requestId = ++_activeRequestId;
    _isChangingChannel = true;
    _currentChannel = channel;

    try {
      if (!isFailover) {
        _resetChannelLinkCounters(channel);
        _resetFailedRounds();
      }
      _pictureSize.reset();
      _watchPlayback();

      final settings = getSettings();
      _currentLink = _firstWorkingLink(channel);

      // During failover, keep the last video frame visible ("freeze frame")
      // instead of showing the resolving spinner (black screen).
      if (isMounted() && requestId == _activeRequestId) {
        final current = getCurrentState();
        onStateChanged(
          current?.copyWith(
                title: channel.name,
                isResolving: !isFailover,
                currentStream: isFailover ? current.currentStream : null,
                error: null,
                // The suggestion shows again on this channel.
                notification: null,
                live: _live(channel),
              ) ??
              CinemaPlayerState(
                controller: controller,
                availableStreams: const [],
                currentStream: null,
                title: channel.name,
                isResolving: true,
                isLive: true,
                live: _live(channel),
              ),
        );
      }

      final result = await _open(channel, settings);

      if (result != null && isMounted() && requestId == _activeRequestId) {
        final current = getCurrentState();
        if (current != null) {
          onStateChanged(
            current.copyWith(
              currentStream: result.resolvedStream,
              live: _live(channel),
              isResolving: false,
              error: null,
            ),
          );
        }
      }
    } catch (e, st) {
      if (requestId == _activeRequestId) {
        onError(e, st);
      }
    } finally {
      if (requestId == _activeRequestId) {
        _isChangingChannel = false;
      }
    }
  }

  /// Manually switches the active Live TV stream source for the current channel.
  Future<void> switchLiveSource(StreamLink link) async {
    if (_currentChannel == null) return;
    _currentLink = link;
    _resetFailedRounds();
    _pictureSize.reset();
    await _reopen(showSpinner: true);
  }

  /// Plays the channel at [height] until the channel changes.
  void pickPictureSize(int height) => _pictureSize.pick(height);

  /// The user moved in the stream: its loading isn't the stream struggling.
  void onSeek() => _pictureSize.onSeek();

  /// Opens the current link again: another source ([showSpinner]), or
  /// another picture size, where the last frame stays until the new one.
  Future<void> _reopen({required bool showSpinner}) async {
    final channel = _currentChannel;
    if (channel == null) return;
    final requestId = ++_activeRequestId;
    _isChangingChannel = true;
    _watchPlayback();

    try {
      if (isMounted()) {
        final current = getCurrentState();
        if (current != null) {
          onStateChanged(
            current.copyWith(
              isResolving: showSpinner,
              live: _live(channel),
              error: null,
              // A later suggestion shows again.
              notification: null,
            ),
          );
        }
      }

      final result = await _open(channel, getSettings());

      if (result != null && isMounted() && requestId == _activeRequestId) {
        final current = getCurrentState();
        if (current != null) {
          onStateChanged(
            current.copyWith(
              currentStream: result.resolvedStream,
              live: _live(channel),
              isResolving: false,
              error: null,
            ),
          );
        }
      }
    } catch (e, st) {
      if (requestId == _activeRequestId) {
        onError(e, st);
      }
    } finally {
      if (requestId == _activeRequestId) {
        _isChangingChannel = false;
      }
    }
  }

  /// Handles playback failures, connection errors, stalls, and EOS
  /// by rotating or retrying links.
  Future<void> handleFailover(
    String error, {
    bool isConnectionError = false,
  }) async {
    final channel = _currentChannel;
    // Already given up, or already waiting for the next round: the dead
    // stream's later errors must not count again.
    if (channel == null ||
        _failedRounds >= _maxFailedRounds ||
        (_nextRoundTimer?.isActive ?? false)) {
      return;
    }

    final link = _currentLink;
    if (link != null) {
      if (!isConnectionError && link.softRetryCount < _maxEosRetries) {
        link.softRetryCount++;
      } else {
        link.isFailed = true;
      }
    }
    developer.log(
      'Live failover ($error), link failed: ${link?.isFailed ?? true}',
      name: 'VideoPlayer.LiveTvCoordinator',
    );

    // Without links the channel's own URL is the only one, so it always
    // ends a round.
    if (channel.links.every((l) => l.isFailed)) {
      _endFailedRound(channel);
      return;
    }

    if (isMounted()) {
      await changeChannel(channel, isFailover: true);
    }
  }

  /// Every link failed: wait longer each round before trying them all again
  /// (a dead channel used to reopen in a tight loop), and after
  /// [_maxFailedRounds] stop and say so (REV-145).
  void _endFailedRound(Channel channel) {
    _failedRounds++;
    if (_failedRounds >= _maxFailedRounds) {
      _showUnavailable();
      return;
    }
    _resetChannelLinkCounters(channel);
    final delay = Duration(seconds: 2 * _failedRounds);
    developer.log(
      'All links failed (round $_failedRounds). Retrying in ${delay.inSeconds}s.',
      name: 'VideoPlayer.LiveTvCoordinator',
    );
    _nextRoundTimer = Timer(delay, () {
      if (isMounted() && identical(_currentChannel, channel)) {
        unawaited(changeChannel(channel, isFailover: true));
      }
    });
  }

  void _showUnavailable() {
    _sourceHandler?.dispose();
    // Stops mpv's own reconnect attempts; the user can still zap away.
    unawaited(player.stop());
    final current = getCurrentState();
    if (!isMounted() || current == null) return;
    onStateChanged(
      current.copyWith(
        isResolving: false,
        currentStream: null,
        error: unavailableMessage(),
      ),
    );
  }

  /// Opens [channel] on the current link (or its own URL) at the picture
  /// size wanted, with a fresh stall watchdog.
  Future<LiveTvInitializationResult?> _open(
    Channel channel,
    UserSettings settings,
  ) {
    _sourceHandler?.dispose();
    _sourceHandler = LiveTvSourceHandler(player);
    _pictureSize.onOpening();
    final link = _currentLink;
    final videoTrack = _pictureSize.videoTrack;
    return link != null
        ? _sourceHandler!.initializeWithLink(
            channel,
            link,
            settings,
            onStall: _onStall,
            videoTrack: videoTrack,
          )
        : _sourceHandler!.initialize(
            channel,
            settings,
            onStall: _onStall,
            videoTrack: videoTrack,
          );
  }

  LivePlayback _live(Channel channel) => LivePlayback(
    channel: channel,
    link: _currentLink,
    pictureSizes: _pictureSize.value,
  );

  void _emitPictureSizes() {
    final channel = _currentChannel;
    final current = getCurrentState();
    if (!isMounted() || channel == null || current == null) return;
    onStateChanged(current.copyWith(live: _live(channel)));
  }

  void _notify(String message) {
    final current = getCurrentState();
    if (!isMounted() || current == null) return;
    onStateChanged(current.copyWith(notification: message));
  }

  /// A stall means the link stopped delivering: rotate like a connection
  /// error (before, it retried the same link forever).
  void _onStall() {
    unawaited(handleFailover('Stream stalled', isConnectionError: true));
  }

  void _resetFailedRounds() {
    _failedRounds = 0;
    _nextRoundTimer?.cancel();
  }

  /// Resets the counters once a link has played for [_healthyPlayback], so an
  /// occasional drop on a working channel never adds up to "unavailable".
  void _watchPlayback() {
    _firstPosition = null;
    _positionSub ??= player.stream.position.listen((position) {
      if (_isChangingChannel) return;
      final first = _firstPosition ??= position;
      if (position - first < _healthyPlayback) return;
      _failedRounds = 0;
      _currentLink?.softRetryCount = 0;
    });
  }

  void _resetChannelLinkCounters(Channel channel) {
    for (final link in channel.links) {
      link.isFailed = false;
      link.softRetryCount = 0;
    }
  }

  /// The playlist's order decides: the first source that hasn't failed.
  StreamLink? _firstWorkingLink(Channel channel) {
    if (channel.links.isEmpty) return null;
    return channel.links.firstWhere(
      (l) => !l.isFailed,
      orElse: () => channel.links.first,
    );
  }
}
