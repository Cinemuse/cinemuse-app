/// Turns the many spellings of a language into the one code that stream
/// metadata uses (`ITA`, `ENG`, `JPN`, `MULTI`), so sources, parser and
/// ranker compare the same strings (REV-25).
class LanguageCodes {
  static const italian = 'ITA';
  static const english = 'ENG';
  static const japanese = 'JPN';
  static const multi = 'MULTI';

  static const Map<String, String> _aliases = {
    'it': italian,
    'ita': italian,
    'italian': italian,
    'italiano': italian,
    'en': english,
    'eng': english,
    'english': english,
    'ja': japanese,
    'jp': japanese,
    'jap': japanese,
    'jpn': japanese,
    'japanese': japanese,
    'multi': multi,
  };

  /// The stream code for [language], such as `ITA` for `it` or `Italian`.
  /// A region suffix is ignored (`it-IT` is `ITA`). An unknown language
  /// comes back upper-cased.
  static String normalize(String language) {
    final key = language.trim().toLowerCase().split(RegExp('[-_]')).first;
    return _aliases[key] ?? key.toUpperCase();
  }
}
