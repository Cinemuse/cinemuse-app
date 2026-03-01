class LanguageMapper {
  static bool isMatch(dynamic track, String preferredLang) {
    if (preferredLang.isEmpty) return false;
    
    final title = (track.title ?? '').toLowerCase();
    final language = (track.language ?? '').toLowerCase();
    final codes = getCodes(preferredLang);
    
    // Check direct preference string (e.g. "english")
    if (title.contains(preferredLang.toLowerCase()) || 
        language.contains(preferredLang.toLowerCase())) {
      return true;
    }
    
    // Check associated codes (e.g. "eng", "en")
    for (var code in codes) {
      if (title.contains(code) || language == code) {
        return true;
      }
    }
    
    return false;
  }

  static List<String> getCodes(String lang) {
    final l = lang.toLowerCase();
    if (l.contains('ita')) return ['ita', 'it', 'italiano'];
    if (l.contains('eng')) return ['eng', 'en', 'english'];
    if (l.contains('jpn')) return ['jpn', 'ja', 'japanese'];
    if (l.contains('fra')) return ['fra', 'fr', 'français', 'fre'];
    if (l.contains('deu')) return ['deu', 'de', 'deutsch', 'ger'];
    if (l.contains('spa')) return ['spa', 'es', 'español'];
    return [l];
  }

  static String getDisplayLanguage(String langCode) {
    final l = langCode.toLowerCase();
    const map = {
      'it': 'Italiano', 'ita': 'Italiano', 'italian': 'Italiano',
      'en': 'English', 'eng': 'English', 'english': 'English',
      'fr': 'Français', 'fra': 'Français', 'fre': 'Français', 'french': 'Français',
      'de': 'Deutsch', 'deu': 'Deutsch', 'ger': 'Deutsch', 'german': 'Deutsch',
      'es': 'Español', 'spa': 'Español', 'spanish': 'Español',
      'ru': 'Русский', 'rus': 'Русский', 'russian': 'Русский',
      'ja': '日本語', 'jpn': '日本語', 'japanese': '日本語',
      'ko': '한국어', 'kor': '한국어', 'korean': '한국어',
      'zh': '中文', 'chi': '中文', 'zho': '中文', 'chinese': '中文',
      'sdh': 'SDH (Hard of Hearing)',
    };
    
    final mapped = map[l];
    if (mapped != null) return mapped;
    
    // Fallback for track numbers or unknown
    if (RegExp(r'^\d+$').hasMatch(langCode)) return 'Track $langCode';
    return langCode;
  }
}
