import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Centralized manager for player event subscriptions and state bridging.
class EventManager {
  final Ref ref;
  final Player player;
  final List<StreamSubscription> _subscriptions = [];

  // Callbacks to notify Controller of state changes
  final VoidCallback onStateChanged;
  final Function(String) onError;
  final VoidCallback onCompleted;
  final Function(String?) onFormatDetected;

  EventManager({
    required this.ref,
    required this.player,
    required this.onStateChanged,
    required this.onError,
    required this.onCompleted,
    required this.onFormatDetected,
  });

  void initialize() {
    _cancelSubscriptions();

    _subscriptions.add(
      player.stream.playing.listen((playing) {
        if (playing) {
          WakelockPlus.enable().catchError((e, st) {
            developer.log(
              'Failed to enable wakelock',
              name: 'VideoPlayer.EventManager',
              error: e,
              stackTrace: st,
            );
          });
        } else {
          WakelockPlus.disable().catchError((e, st) {
            developer.log(
              'Failed to disable wakelock',
              name: 'VideoPlayer.EventManager',
              error: e,
              stackTrace: st,
            );
          });
        }
        onStateChanged();
      }),
    );
    _subscriptions.add(player.stream.buffering.listen((_) => onStateChanged()));
    _subscriptions.add(
      player.stream.duration.listen((d) {
        if (d.inSeconds > 0) {
          _probeFormat();
        }
        onStateChanged();
      }),
    );

    // Listen for track changes to trigger UI updates and probe format
    _subscriptions.add(
      player.stream.track.listen((_) {
        _probeFormat();
        onStateChanged();
      }),
    );
    // We deliberately omit `player.stream.position` here.
    // MediaKit fires position updates dozens of times per second. Triggering
    // a Riverpod state update (and thus a full UI rebuild) on every tick ruins
    // playback performance and causes severe frame drops.

    _subscriptions.add(
      player.stream.error.listen((error) {
        developer.log(
          'Player Error: $error',
          name: 'VideoPlayer.EventManager',
          level: 900,
        );
        onError(error);
      }),
    );

    _subscriptions.add(
      player.stream.completed.listen((completed) {
        if (completed) {
          developer.log(
            'Playback Completed',
            name: 'VideoPlayer.EventManager',
          );
          onCompleted();
        }
      }),
    );
  }

  void _cancelSubscriptions() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }

  void _probeFormat() {
    try {
      // Accessing mpv property directly via Platform Player (native)
      final format = (player.platform as dynamic).getProperty('file-format');
      if (format is String) {
        onFormatDetected(format);
      }
    } catch (e, st) {
      developer.log(
        'Format probe unavailable on current platform/state',
        name: 'VideoPlayer.EventManager',
        error: e,
        stackTrace: st,
        level: 500,
      );
    }
  }

  void dispose() {
    WakelockPlus.disable().catchError((e, st) {
      developer.log(
        'Failed to disable wakelock during dispose',
        name: 'VideoPlayer.EventManager',
        error: e,
        stackTrace: st,
      );
    });
    _cancelSubscriptions();
  }
}
