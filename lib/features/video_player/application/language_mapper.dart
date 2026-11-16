import 'package:cinemuse_app/core/constants/tmdb_constants.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:media_kit/media_kit.dart';

/// What a subtitle track holds besides its language.
enum SubtitleKind {
  /// Every line.
  full,

  /// Only what a viewer of that sound couldn't follow (another language
  /// spoken, a sign or a letter on screen): meant to show with subtitles off.
  forced,

  /// Every line plus the sounds, for viewers who can't hear (also called
  /// SDH or hearing impaired).
  cc,
}

/// One language: its two-letter code, the file codes that mean it, its
/// English name and its own name.
class _Language {
  final String code;
  final List<String> fileCodes;
  final String english;
  final String native;

  const _Language(this.code, this.fileCodes, this.english, this.native);

  Iterable<String> get keys => [
    code,
    ...fileCodes,
    english.toLowerCase(),
    native.toLowerCase(),
  ];
}

/// Utility class for language code resolution, display formatting, and audio/subtitle track matching.
class LanguageMapper {
  /// The languages tracks come in. Each name in the app's language is
  /// `languageName(code)`, so every code here has one there too.
  static const List<_Language> _languages = [
    _Language('en', ['eng'], 'English', 'English'),
    _Language('it', ['ita'], 'Italian', 'Italiano'),
    _Language('ja', ['jpn'], 'Japanese', '日本語'),
    _Language('es', ['spa'], 'Spanish', 'Español'),
    _Language('fr', ['fra', 'fre'], 'French', 'Français'),
    _Language('de', ['deu', 'ger'], 'German', 'Deutsch'),
    _Language('pt', ['por'], 'Portuguese', 'Português'),
    _Language('ru', ['rus'], 'Russian', 'Русский'),
    _Language('ko', ['kor'], 'Korean', '한국어'),
    _Language('zh', ['zho', 'chi'], 'Chinese', '中文'),
    _Language('hi', ['hin'], 'Hindi', 'हिन्दी'),
    _Language('nl', ['nld', 'dut'], 'Dutch', 'Nederlands'),
    _Language('sv', ['swe'], 'Swedish', 'Svenska'),
    _Language('da', ['dan'], 'Danish', 'Dansk'),
    _Language('pl', ['pol'], 'Polish', 'Polski'),
    _Language('tr', ['tur'], 'Turkish', 'Türkçe'),
    _Language('th', ['tha'], 'Thai', 'ไทย'),
    _Language('id', ['ind'], 'Indonesian', 'Bahasa Indonesia'),
    _Language('ar', ['ara'], 'Arabic', 'العربية'),
    _Language('cs', ['ces', 'cze'], 'Czech', 'Čeština'),
    _Language('el', ['ell', 'gre'], 'Greek', 'Ελληνικά'),
    _Language('fi', ['fin'], 'Finnish', 'Suomi'),
    _Language('he', ['heb'], 'Hebrew', 'עברית'),
    _Language('hu', ['hun'], 'Hungarian', 'Magyar'),
    _Language('no', ['nor', 'nob', 'nno', 'nb', 'nn'], 'Norwegian', 'Norsk'),
    _Language('ro', ['ron', 'rum'], 'Romanian', 'Română'),
    _Language('uk', ['ukr'], 'Ukrainian', 'Українська'),
    _Language('vi', ['vie'], 'Vietnamese', 'Tiếng Việt'),
    _Language('bg', ['bul'], 'Bulgarian', 'Български'),
    _Language('hr', ['hrv'], 'Croatian', 'Hrvatski'),
    _Language('sr', ['srp'], 'Serbian', 'Српски'),
    _Language('sk', ['slk', 'slo'], 'Slovak', 'Slovenčina'),
    _Language('sl', ['slv'], 'Slovenian', 'Slovenščina'),
    _Language('et', ['est'], 'Estonian', 'Eesti'),
    _Language('lv', ['lav'], 'Latvian', 'Latviešu'),
    _Language('lt', ['lit'], 'Lithuanian', 'Lietuvių'),
    _Language('is', ['isl', 'ice'], 'Icelandic', 'Íslenska'),
    _Language('ca', ['cat'], 'Catalan', 'Català'),
    _Language('eu', ['eus', 'baq'], 'Basque', 'Euskara'),
    _Language('gl', ['glg'], 'Galician', 'Galego'),
    _Language('ms', ['msa', 'may'], 'Malay', 'Bahasa Melayu'),
    _Language('fa', ['fas', 'per'], 'Persian', 'فارسی'),
    _Language('ta', ['tam'], 'Tamil', 'தமிழ்'),
    _Language('te', ['tel'], 'Telugu', 'తెలుగు'),
    _Language('tl', ['tgl', 'fil'], 'Filipino', 'Filipino'),
    _Language('bn', ['ben'], 'Bengali', 'বাংলা'),
  ];

  /// Every code and name, lower case, to its language.
  static final Map<String, _Language> _byKey = {
    for (final language in _languages)
      for (final key in language.keys) key: language,
  };

  /// File codes that say "no language": undetermined, several, none.
  static const _noLanguage = {'und', 'mul', 'zxx', 'mis'};

  /// The language [raw] names (a code such as `ita` or `pt-BR`, or a name
  /// such as `Italian`), or null.
  static _Language? _find(String raw) {
    final normalized = raw.trim().toLowerCase();
    return _byKey[normalized] ?? _byKey[normalized.split(RegExp('[-_]')).first];
  }

  /// The one code a language goes by (`it` for `ita`, `Italian`, `it-IT`);
  /// an unknown code comes back lower case, a missing or "undetermined" one
  /// (or one that only says "sdh" or "forced") as null.
  static String? languageKey(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    if (_noLanguage.contains(normalized) ||
        _titleRest(normalized, null).isEmpty) {
      return null;
    }
    return _find(normalized)?.code ?? normalized.split(RegExp('[-_]')).first;
  }

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
    final language = _find(normalized);
    return language == null ? [normalized] : language.keys.toSet().toList();
  }

  /// A language's name: its own name, then the app language's when they
  /// differ ("Deutsch – Tedesco", "Italiano"). An unknown code stays as it
  /// is; a bare number is a track number.
  static String getDisplayLanguage(String langCode, AppLocalizations l10n) {
    final language = _find(langCode);
    if (language != null) {
      final local = l10n.languageName(language.code);
      return local.toLowerCase() == language.native.toLowerCase()
          ? language.native
          : '${language.native} – $local';
    }
    final normalized = langCode.trim();
    if (_numericTrackRegex.hasMatch(normalized)) {
      return l10n.playerTrackNumber(normalized);
    }
    return normalized;
  }

  // ---------------------------------------------------------------------------
  // Forced and CC subtitles
  // ---------------------------------------------------------------------------

  /// "Forced", "Forzati", and anime "Signs & Songs" tracks.
  static final _forcedWords = RegExp(
    r'(?<!\p{L})(?:forced|forzat[io]|forcés?|signs?)(?!\p{L})',
    caseSensitive: false,
    unicode: true,
  );

  static final _ccWords = RegExp(
    r'(?<!\p{L})(?:sdh|cc|hearing[\s-]*impaired|hard[\s-]+of[\s-]+hearing|'
    r'non[\s-]*udenti|closed[\s-]*captions?)(?!\p{L})',
    caseSensitive: false,
    unicode: true,
  );

  /// What [track] holds: [flagged] is what the file itself says (read from
  /// the engine), else the title's words decide.
  static SubtitleKind subtitleKind(dynamic track, {SubtitleKind? flagged}) {
    if (flagged != null && flagged != SubtitleKind.full) return flagged;
    if (track is! SubtitleTrack) return SubtitleKind.full;
    final words = '${track.title ?? ''} ${track.language ?? ''}';
    if (_forcedWords.hasMatch(words)) return SubtitleKind.forced;
    if (_ccWords.hasMatch(words)) return SubtitleKind.cc;
    return SubtitleKind.full;
  }

  static final _punctuation = RegExp(r'[\s\p{P}\p{S}\d]+', unicode: true);

  /// [title] without the kind words, [language]'s codes and names, and
  /// punctuation: what is left is what the title adds.
  static String _titleRest(String title, _Language? language) {
    var rest = title.replaceAll(_forcedWords, ' ').replaceAll(_ccWords, ' ');
    if (language != null) {
      for (final key in language.keys) {
        rest = rest.replaceAll(
          RegExp(
            '(?<!\\p{L})${RegExp.escape(key)}(?!\\p{L})',
            caseSensitive: false,
            unicode: true,
          ),
          ' ',
        );
      }
    }
    return rest.replaceAll(_punctuation, ' ').trim();
  }

  /// The language a track is in, from its language, else its title
  /// ("English (Forced)"): the key of [languageKey], or null.
  static String? trackLanguage(dynamic track) {
    final key = languageKey(track.language as String?);
    if (key != null) return key;
    final title = (track.title as String? ?? '').trim();
    if (title.isEmpty) return null;
    return _find(_titleRest(title, null))?.code;
  }

  /// The label of an audio / subtitle row: the language first, then what the
  /// subtitle is ([kind]: Forced, CC), then the title when it says more,
  /// then (audio only) the channels and codec, e.g. "English – Inglese · CC"
  /// or "Italiano · 5.1 · EAC3". Titles are the uploader's free text, so
  /// alone they mislabel or repeat tracks (REV-281).
  static String trackLabel(
    dynamic track,
    AppLocalizations l10n, {
    SubtitleKind kind = SubtitleKind.full,
  }) {
    final language = (track.language as String? ?? '').trim();
    final title = (track.title as String? ?? '').trim();
    final parts = <String>[];
    final kindLabel = switch (kind) {
      SubtitleKind.full => null,
      SubtitleKind.forced => l10n.playerTrackForced,
      SubtitleKind.cc => l10n.playerTrackCc,
    };

    if (languageKey(language) != null) {
      parts.add(getDisplayLanguage(language, l10n));
      if (kindLabel != null) parts.add(kindLabel);
      if (_titleRest(title, _find(language)).isNotEmpty) parts.add(title);
    } else {
      final fromTitle = _find(_titleRest(title, null));
      if (fromTitle != null) {
        // "English (Forced)" with no language: the title is the language.
        parts.add(getDisplayLanguage(fromTitle.code, l10n));
        if (kindLabel != null) parts.add(kindLabel);
      } else if (_titleRest(title, null).isNotEmpty) {
        parts.add(title);
        // Unless the title says it already ("Forced Signs").
        if (kindLabel != null && subtitleKind(track) != kind) {
          parts.add(kindLabel);
        }
      } else {
        parts.add(getDisplayLanguage(track.id as String, l10n));
        if (kindLabel != null) parts.add(kindLabel);
      }
    }

    if (track is AudioTrack) {
      final channels = _channelsLabel(track.channelscount);
      if (channels != null) parts.add(channels);
      final codec = track.codec?.trim();
      if (codec != null && codec.isNotEmpty) parts.add(codec.toUpperCase());
    }
    return parts.join(' · ');
  }

  /// [tracks] grouped by language, English then Italian first, the others
  /// by their own name, tracks with no language last; in a language the
  /// full subtitles, then the forced ones, then the CC ones. Otherwise the
  /// file's order.
  static List<T> sortedByLanguage<T>(
    List<T> tracks,
    SubtitleKind Function(T) kindOf,
  ) {
    int groupRank(String? key) => switch (key) {
      'en' => 0,
      'it' => 1,
      null => 3,
      _ => 2,
    };
    String groupName(String? key) =>
        (key == null ? null : _byKey[key]?.native.toLowerCase()) ?? key ?? '';

    final indexed = tracks.indexed.toList();
    final languages = {
      for (final (index, track) in indexed)
        index: trackLanguage(track as dynamic),
    };
    indexed.sort((a, b) {
      final la = languages[a.$1], lb = languages[b.$1];
      final byRank = groupRank(la).compareTo(groupRank(lb));
      if (byRank != 0) return byRank;
      final byName = groupName(la).compareTo(groupName(lb));
      if (byName != 0) return byName;
      final byKind = kindOf(a.$2).index.compareTo(kindOf(b.$2).index);
      if (byKind != 0) return byKind;
      return a.$1.compareTo(b.$1);
    });
    return [for (final (_, track) in indexed) track];
  }

  static String? _channelsLabel(int? count) => switch (count) {
    null || <= 0 => null,
    1 => 'Mono',
    2 => 'Stereo',
    6 => '5.1',
    8 => '7.1',
    _ => '${count}ch',
  };
}
