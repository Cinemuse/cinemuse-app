import 'dart:async';
import 'package:media_kit/media_kit.dart';

class PlayerProgressTracker {
  final Player player;
  final Function(int position, int duration) onProgress;
  
  StreamSubscription? _posSub;
  int _lastPlaybackTick = -1;
  int _actualSecondsWatched = 0;
  int _lastSavedPosition = 0;

  int get actualSecondsWatched => _actualSecondsWatched;

  PlayerProgressTracker({
    required this.player,
    required this.onProgress,
  });

  void start() {
    _posSub?.cancel();
    _posSub = player.stream.position.listen((duration) {
      final seconds = duration.inSeconds;
      final totalDuration = player.state.duration.inSeconds;

      // Intent Detection: Track actual time watched
      if (_lastPlaybackTick != -1) {
        final delta = seconds - _lastPlaybackTick;
        if (delta > 0 && delta <= 2) {
          _actualSecondsWatched += delta;
        }
      }
      _lastPlaybackTick = seconds;

      // Notify every 15 seconds or on significant change
      if ((seconds - _lastSavedPosition).abs() > 15) {
        onProgress(seconds, totalDuration);
        _lastSavedPosition = seconds;
      }
    });
  }

  void stop() {
    _posSub?.cancel();
    _posSub = null;
  }

  void dispose() {
    stop();
  }
}
