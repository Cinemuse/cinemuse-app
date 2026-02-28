import 'package:media_kit/media_kit.dart';
import 'dart:async';

class PreferenceHandler {
  final Player _player;

  PreferenceHandler(this._player);

  /// Applies both audio and subtitle preferences, waiting for tracks to be loaded if necessary.
  Future<void> applyPreferences(String prefLang) async {
    if (prefLang.isEmpty) return;
    final term = prefLang.toLowerCase();

    try {
      // Wait for tracks to be available (up to 5 seconds). 
      // Media-kit sometimes emits an empty list initially while probing.
      final tracks = await _player.stream.tracks.firstWhere(
        (t) => t.audio.isNotEmpty,
      ).timeout(const Duration(seconds: 5), onTimeout: () => _player.state.tracks);

      // 1. Audio Tracking
      for (var track in tracks.audio) {
        if (track.id == 'auto' || track.id == 'no') continue;
        final title = track.title?.toLowerCase() ?? '';
        final lang = track.language?.toLowerCase() ?? '';

        if (title.contains(term) || lang.contains(term)) {
          print('PreferenceHandler: Auto-enabling audio: ${track.title ?? track.language ?? track.id}');
          await _player.setAudioTrack(track);
          break;
        }
      }

      // 2. Subtitle Tracking
      for (var track in tracks.subtitle) {
        if (track.id == 'auto' || track.id == 'no') continue;
        final title = track.title?.toLowerCase() ?? '';
        final lang = track.language?.toLowerCase() ?? '';

        if (title.contains(term) || lang.contains(term)) {
          print('PreferenceHandler: Auto-enabling subtitle: ${track.title ?? track.language ?? track.id}');
          await _player.setSubtitleTrack(track);
          break;
        }
      }
    } catch (e) {
      print('PreferenceHandler: Error applying preferences: $e');
    }
  }
}
