import 'dart:async';
import 'package:cinemuse_app/features/video_player/application/managers/base_manager.dart';
import 'package:flutter/foundation.dart';

/// Centralized manager for player event subscriptions and state bridging.
class EventManager extends BaseManager {
  final List<StreamSubscription> _subscriptions = [];
  
  // Callbacks to notify Controller of state changes
  final VoidCallback onStateChanged;
  final Function(String) onError;
  final VoidCallback onCompleted;
  final Function(String?) onFormatDetected;

  EventManager({
    required super.ref,
    required super.player,
    required this.onStateChanged,
    required this.onError,
    required this.onCompleted,
    required this.onFormatDetected,
  });

  void initialize() {
    _cancelSubscriptions();

    _subscriptions.add(player.stream.playing.listen((_) => onStateChanged()));
    _subscriptions.add(player.stream.buffering.listen((_) => onStateChanged()));
    _subscriptions.add(player.stream.duration.listen((d) {
       if (d.inSeconds > 0) {
         _probeFormat();
       }
       onStateChanged();
    }));
    
    // Listen for track changes as a hint to probe format (Probing done)
    _subscriptions.add(player.stream.track.listen((_) => _probeFormat()));
    // We deliberately omit `player.stream.position` here.
    // MediaKit fires position updates dozens of times per second. Triggering
    // a Riverpod state update (and thus a full UI rebuild) on every tick ruins
    // playback performance and causes severe frame drops.

    _subscriptions.add(player.stream.error.listen((error) {
      debugPrint('EventManager: Player Error: $error');
      onError(error);
    }));

    _subscriptions.add(player.stream.completed.listen((completed) {
      if (completed) {
        debugPrint('EventManager: Playback Completed');
        onCompleted();
      }
    }));
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
    } catch (_) {
      // Property might not be available on all platforms/states
    }
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }
}
