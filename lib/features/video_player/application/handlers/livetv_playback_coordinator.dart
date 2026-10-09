import 'dart:developer' as developer;
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/stream_link.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
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

  LiveTvPlaybackCoordinator({
    required this.player,
    required this.controller,
    required this.getSettings,
    required this.isMounted,
    required this.getCurrentState,
    required this.onStateChanged,
    required this.onError,
  });

  Channel? _currentChannel;
  StreamLink? _currentLink;
  bool _isChangingChannel = false;
  int _activeRequestId = 0;
  LiveTvSourceHandler? _sourceHandler;

  /// Max retries on a connection error before rotating to the next link.
  /// EOS (stream ended) retries the same link infinitely since the server was working.
  static const int _maxErrorRetries = 1;

  Channel? get currentChannel => _currentChannel;
  StreamLink? get currentLink => _currentLink;
  bool get isChangingChannel => _isChangingChannel;

  void dispose() {
    _sourceHandler?.dispose();
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
      }

      final settings = getSettings();
      _currentLink = _selectPreferredLink(channel, settings.liveTvQuality);

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
                currentChannel: channel,
                currentLiveLink: _currentLink,
              ) ??
              CinemaPlayerState(
                controller: controller,
                availableStreams: const [],
                currentStream: null,
                title: channel.name,
                isResolving: true,
                isLive: true,
                currentChannel: channel,
                currentLiveLink: _currentLink,
              ),
        );
      }

      // Ensure previous stall watchdogs are stopped
      _sourceHandler?.dispose();
      _sourceHandler = LiveTvSourceHandler(player);

      final result = _currentLink != null
          ? await _sourceHandler!.initializeWithLink(
              channel,
              _currentLink!,
              settings,
              onStall: () => handleFailover('Stream stalled'),
            )
          : await _sourceHandler!.initialize(
              channel,
              settings,
              onStall: () => handleFailover('Stream stalled'),
            );

      if (isMounted() && requestId == _activeRequestId) {
        final current = getCurrentState();
        if (current != null) {
          onStateChanged(
            current.copyWith(
              currentStream: result.resolvedStream,
              currentLiveLink: _currentLink,
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
    final channel = _currentChannel!;
    final requestId = ++_activeRequestId;
    _isChangingChannel = true;
    _currentLink = link;

    try {
      if (isMounted()) {
        final current = getCurrentState();
        if (current != null) {
          onStateChanged(
            current.copyWith(
              isResolving: true,
              currentLiveLink: link,
              error: null,
            ),
          );
        }
      }

      final settings = getSettings();
      _sourceHandler?.dispose();
      _sourceHandler = LiveTvSourceHandler(player);

      final result = await _sourceHandler!.initializeWithLink(
        channel,
        link,
        settings,
        onStall: () => handleFailover('Stream stalled'),
      );

      if (isMounted() && requestId == _activeRequestId) {
        final current = getCurrentState();
        if (current != null) {
          onStateChanged(
            current.copyWith(
              currentStream: result.resolvedStream,
              currentLiveLink: link,
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
    if (_currentChannel == null) return;

    if (_currentLink != null) {
      if (isConnectionError) {
        _currentLink!.softRetryCount++;
        if (_currentLink!.softRetryCount >= _maxErrorRetries) {
          developer.log(
            'Link unreachable after ${_currentLink!.softRetryCount} errors. Rotating.',
            name: 'VideoPlayer.LiveTvCoordinator',
          );
          _currentLink!.isFailed = true;
          _currentLink!.softRetryCount = 0;
        } else {
          developer.log(
            'Connection error (${_currentLink!.softRetryCount}/$_maxErrorRetries). Retrying SAME link.',
            name: 'VideoPlayer.LiveTvCoordinator',
          );
        }
      } else {
        // EOS: the server was streaming. Retry same link.
        developer.log(
          'EOS on link. Retrying SAME link (server was active).',
          name: 'VideoPlayer.LiveTvCoordinator',
        );
      }
    }

    final hasWorkingLinks = _currentChannel!.links.any((l) => !l.isFailed);
    if (!hasWorkingLinks) {
      developer.log(
        'All links exhausted. Restarting loop...',
        name: 'VideoPlayer.LiveTvCoordinator',
      );
      _resetChannelLinkCounters(_currentChannel!);
    }

    if (isMounted()) {
      await changeChannel(_currentChannel!, isFailover: true);
    }
  }

  void _resetChannelLinkCounters(Channel channel) {
    for (final link in channel.links) {
      link.isFailed = false;
      link.softRetryCount = 0;
    }
  }

  StreamLink? _selectPreferredLink(
    Channel channel,
    StreamQuality preferredQuality,
  ) {
    if (channel.links.isEmpty) return null;

    final qualityLinks = channel.links
        .where((l) => l.quality == preferredQuality && !l.isFailed)
        .toList();

    if (qualityLinks.isNotEmpty) {
      return qualityLinks.first;
    }

    return channel.links.firstWhere(
      (l) => !l.isFailed,
      orElse: () => channel.links.first,
    );
  }
}
