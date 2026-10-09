import 'package:media_kit/media_kit.dart';

/// Utility class for language code resolution, display formatting, and audio/subtitle track matching.
class LanguageMapper {
  static const Map<String, List<String>> _languageAliases = {
    'it': ['ita', 'it', 'italiano'],
    'ita': ['ita', 'it', 'italiano'],
    'italiano': ['ita', 'it', 'italiano'],
    'italian': ['ita', 'it', 'italiano'],
    'en': ['eng', 'en', 'english'],
    'eng': ['eng', 'en', 'english'],
    'english': ['eng', 'en', 'english'],
    'ja': ['jpn', 'ja', 'japanese'],
    'jpn': ['jpn', 'ja', 'japanese'],
    'japanese': ['jpn', 'ja', 'japanese'],
    'fr': ['fra', 'fr', 'français', 'fre'],
    'fra': ['fra', 'fr', 'français', 'fre'],
    'fre': ['fra', 'fr', 'français', 'fre'],
    'french': ['fra', 'fr', 'français', 'fre'],
    'français': ['fra', 'fr', 'français', 'fre'],
    'de': ['deu', 'de', 'deutsch', 'ger'],
    'deu': ['deu', 'de', 'deutsch', 'ger'],
    'ger': ['deu', 'de', 'deutsch', 'ger'],
    'german': ['deu', 'de', 'deutsch', 'ger'],
    'deutsch': ['deu', 'de', 'deutsch', 'ger'],
    'es': ['spa', 'es', 'español'],
    'spa': ['spa', 'es', 'español'],
    'spanish': ['spa', 'es', 'español'],
    'español': ['spa', 'es', 'español'],
  };

  static const Map<String, String> _displayLanguages = {
    'it': 'Italiano',
    'ita': 'Italiano',
    'italian': 'Italiano',
    'en': 'English',
    'eng': 'English',
    'english': 'English',
    'fr': 'Français',
    'fra': 'Français',
    'fre': 'Français',
    'french': 'Français',
    'de': 'Deutsch',
    'deu': 'Deutsch',
    'ger': 'Deutsch',
    'german': 'Deutsch',
    'es': 'Español',
    'spa': 'Español',
    'spanish': 'Español',
    'ru': 'Русский',
    'rus': 'Русский',
    'russian': 'Русский',
    'ja': '日本語',
    'jpn': '日本語',
    'japanese': '日本語',
    'ko': '한국어',
    'kor': '한국어',
    'korean': '한국어',
    'zh': '中文',
    'chi': '中文',
    'zho': '中文',
    'chinese': '中文',
    'sdh': 'SDH (Hard of Hearing)',
  };

  static final RegExp _numericTrackRegex = RegExp(r'^\d+$');

  /// Determines whether [track] matches the user's preferred language code or alias.
  static bool isMatch(dynamic track, String preferredLang) {
    if (preferredLang.isEmpty) return false;

    final (title, language) = switch (track) {
      AudioTrack t => (
        (t.title ?? '').toLowerCase(),
        (t.language ?? '').toLowerCase(),
      ),
      SubtitleTrack t => (
        (t.title ?? '').toLowerCase(),
        (t.language ?? '').toLowerCase(),
      ),
      VideoTrack t => (
        (t.title ?? '').toLowerCase(),
        (t.language ?? '').toLowerCase(),
      ),
      _ => (
        (track?.title as String? ?? '').toLowerCase(),
        (track?.language as String? ?? '').toLowerCase(),
      ),
    };

    final normalizedPref = preferredLang.trim().toLowerCase();
    final codes = getCodes(normalizedPref);

    // Check direct preference string (e.g. "english")
    if (title.contains(normalizedPref) || language.contains(normalizedPref)) {
      return true;
    }

    // Check associated codes (e.g. "eng", "en")
    for (final code in codes) {
      if (title.contains(code) || language == code) {
        return true;
      }
    }

    return false;
  }

  /// Returns known ISO/alias codes for a given language tag or name.
  static List<String> getCodes(String lang) {
    final normalized = lang.trim().toLowerCase();
    return _languageAliases[normalized] ?? [normalized];
  }

  /// Returns the human-readable display label for a language code.
  static String getDisplayLanguage(String langCode) {
    final normalized = langCode.trim().toLowerCase();
    final mapped = _displayLanguages[normalized];
    if (mapped != null) return mapped;

    // Fallback for track numbers or unknown
    if (_numericTrackRegex.hasMatch(normalized)) {
      return 'Track $normalized';
    }
    return langCode;
  }
}
