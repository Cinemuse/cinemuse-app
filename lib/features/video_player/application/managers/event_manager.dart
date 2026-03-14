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

  EventManager({
    required super.ref,
    required super.player,
    required this.onStateChanged,
    required this.onError,
    required this.onCompleted,
  });

  void initialize() {
    _cancelSubscriptions();

    _subscriptions.add(player.stream.playing.listen((_) => onStateChanged()));
    _subscriptions.add(player.stream.buffering.listen((_) => onStateChanged()));
    _subscriptions.add(player.stream.duration.listen((_) => onStateChanged()));
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

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }
}
