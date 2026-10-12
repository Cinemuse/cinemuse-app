import 'package:media_kit/media_kit.dart';

/// Utility class for language code resolution, display formatting, and audio/subtitle track matching.
class LanguageMapper {
  static const Map<String, List<String>> _languageAliases = {
    'it': ['ita', 'it', 'italiano', 'italian'],
    'ita': ['ita', 'it', 'italiano', 'italian'],
    'italiano': ['ita', 'it', 'italiano', 'italian'],
    'italian': ['ita', 'it', 'italiano', 'italian'],
    'en': ['eng', 'en', 'english'],
    'eng': ['eng', 'en', 'english'],
    'english': ['eng', 'en', 'english'],
    'ja': ['jpn', 'ja', 'japanese'],
    'jpn': ['jpn', 'ja', 'japanese'],
    'japanese': ['jpn', 'ja', 'japanese'],
    'fr': ['fra', 'fr', 'français', 'fre', 'french'],
    'fra': ['fra', 'fr', 'français', 'fre', 'french'],
    'fre': ['fra', 'fr', 'français', 'fre', 'french'],
    'french': ['fra', 'fr', 'français', 'fre', 'french'],
    'français': ['fra', 'fr', 'français', 'fre', 'french'],
    'de': ['deu', 'de', 'deutsch', 'ger', 'german'],
    'deu': ['deu', 'de', 'deutsch', 'ger', 'german'],
    'ger': ['deu', 'de', 'deutsch', 'ger', 'german'],
    'german': ['deu', 'de', 'deutsch', 'ger', 'german'],
    'deutsch': ['deu', 'de', 'deutsch', 'ger', 'german'],
    'es': ['spa', 'es', 'español', 'spanish'],
    'spa': ['spa', 'es', 'español', 'spanish'],
    'spanish': ['spa', 'es', 'español', 'spanish'],
    'español': ['spa', 'es', 'español', 'spanish'],
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
    final codes = {normalizedPref, ...getCodes(normalizedPref)};
    // "en-US" counts as "en".
    final baseLanguage = language.split(RegExp('[-_]')).first;
    if (codes.contains(language) || codes.contains(baseLanguage)) return true;

    // Whole words only: a substring match took "es" from "Japanese" and
    // "en" from "French" (REV-143).
    return codes.any((code) => _wholeWord(code).hasMatch(title));
  }

  static RegExp _wholeWord(String code) =>
      RegExp('(?<!\\p{L})${RegExp.escape(code)}(?!\\p{L})', unicode: true);

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
