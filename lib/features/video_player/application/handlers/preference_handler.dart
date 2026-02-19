import 'package:media_kit/media_kit.dart';

class PreferenceHandler {
  final Player _player;

  PreferenceHandler(this._player);

  Future<void> applyLanguagePreference(String prefLang) async {
    if (prefLang.isEmpty) return;

    final tracks = _player.state.tracks.audio;
    AudioTrack? bestMatch;

    for (var track in tracks) {
      final title = track.title?.toLowerCase() ?? '';
      final lang = track.language?.toLowerCase() ?? '';
      final term = prefLang.toLowerCase();

      if (title.contains(term) || lang.contains(term)) {
        bestMatch = track;
        break;
      }
    }
    
    if (bestMatch != null) {
      print('PreferenceHandler: Auto-enabling audio track: ${bestMatch.title ?? bestMatch.language ?? bestMatch.id}');
      await _player.setAudioTrack(bestMatch);
    }
  }

  Future<void> applySubtitlePreference(String prefLang) async {
    if (prefLang.isEmpty) return;

    final tracks = _player.state.tracks.subtitle;
    SubtitleTrack? bestMatch;

    for (var track in tracks) {
      final title = track.title?.toLowerCase() ?? '';
      final lang = track.language?.toLowerCase() ?? '';
      final term = prefLang.toLowerCase();

      if (title.contains(term) || lang.contains(term)) {
        bestMatch = track;
        break;
      }
    }
    
    if (bestMatch != null) {
      print('PreferenceHandler: Auto-enabling subtitle track: ${bestMatch.title ?? bestMatch.language ?? bestMatch.id}');
      await _player.setSubtitleTrack(bestMatch);
    }
  }
}
