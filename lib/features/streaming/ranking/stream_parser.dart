import 'package:cinemuse_app/features/streaming/models/stream_metadata.dart';
import 'package:cinemuse_app/features/streaming/ranking/language_codes.dart';

/// Reads a stream's name into a [StreamMetadata]: everything the app knows
/// about a stream comes from here, and the filter and the ranker only use it.
///
/// The film's own title comes first in a name and can hold any word ("The
/// Italian Job", "Cam", "Step Up 3D"), so labels are read only from the year,
/// the episode number or the picture size onward, plus what is in brackets
/// (the source's name, or a label written `[ITA]`). A name with none of those
/// is read whole. Tags count only as whole words.
class StreamParser {
  // --- Where the labels start ---
  static final _leadingBrackets = RegExp(r'^(?:\s*\[[^\]]*\])+');
  static final _anyBrackets = RegExp(r'\[[^\]]*\]');
  static final _yearOrEpisode = RegExp(
    r'(?<!\d)(?:19|20)\d\d(?!\d)'
    r'|\bS\d{1,2}(?:[ .-]?E\d{1,4})?\b'
    r'|\b\d{1,2}x\d{1,4}\b'
    r'|\b(?:E|Ep|Episode|Episodio|Season|Stagione)[ .]?\d{1,4}\b'
    r'|\s-\s\d{1,4}\b',
    caseSensitive: false,
  );
  static final _anyPictureSize = RegExp(
    r'\b\d{3,4}[pi](?:\d\d)?\b|\b\d{3,4}\s?x\s?\d{3,4}\b|\b(?:4k|uhd|2k|fhd|2160)\b',
    caseSensitive: false,
  );
  static final _labelsBeforeSize = RegExp(
    '(?:\\b(?:$_languageWord|dual|scr|screener|ts|tc|cam|hdcam|3d)[\\s.\\-]+)+\$',
    caseSensitive: false,
  );

  // Torrentio's line after the name: seeders, size, site and language flags.
  static const _statsStart = '👤';

  // A file's extension, not a telesync tag; ".TS" in capitals is the tag.
  static final _tsExtension = RegExp(r'\.ts(?=\s|$)');

  // --- Video ---
  /// A real size wins over a word, so these are tried first.
  static final Map<VideoResolution, RegExp> _measuredSizes = {
    VideoResolution.r2160p: RegExp(
      r'(?<!👤\s)\b2160[pi]?(?:\d\d)?\b|\b3840\s?x\s?\d{3,4}\b|\b\d{3,4}\s?x\s?2160\b',
      caseSensitive: false,
    ),
    VideoResolution.r1440p: RegExp(
      r'\b1440[pi](?:\d\d)?\b|\b2560\s?x\s?\d{3,4}\b|\b\d{3,4}\s?x\s?1440\b',
      caseSensitive: false,
    ),
    VideoResolution.r1080p: RegExp(
      r'\b1080[pi](?:\d\d)?\b|\b1920\s?x\s?\d{3,4}\b|\b\d{3,4}\s?x\s?1080\b',
      caseSensitive: false,
    ),
    VideoResolution.r720p: RegExp(
      r'\b720[pi](?:\d\d)?\b|\b1280\s?x\s?\d{3,4}\b|\b\d{3,4}\s?x\s?720\b',
      caseSensitive: false,
    ),
    VideoResolution.r480p: RegExp(
      r'\b(?:480|576|360)[pi]\b',
      caseSensitive: false,
    ),
  };

  static final Map<VideoResolution, RegExp> _sizeWords = {
    VideoResolution.r2160p: RegExp(r'\b(?:4k|uhd)\b', caseSensitive: false),
    VideoResolution.r1440p: RegExp(r'\b2k\b', caseSensitive: false),
    VideoResolution.r1080p: RegExp(r'\bfhd\b', caseSensitive: false),
  };

  static final _hdr = RegExp(
    r'(?<![a-z0-9])hdr(?:10)?(?:\+|plus)?(?:dv)?(?![a-z0-9])',
    caseSensitive: false,
  );
  static final _dolbyVision = RegExp(
    r'\b(?:dv|dovi|hdrdv|dolby[ .-]?vision)\b',
    caseSensitive: false,
  );
  static final _tenBit = RegExp(
    r'(?<!\d)10[ .-]?bit\b|\bhi10p?\b',
    caseSensitive: false,
  );

  static final Map<VideoCodec, RegExp> _codecs = {
    VideoCodec.hevc: RegExp(r'\bhevc|\b[xh][. ]?265\b', caseSensitive: false),
    VideoCodec.h264: RegExp(r'\b[xh][. ]?264\b|\bavc\b', caseSensitive: false),
    VideoCodec.av1: RegExp(r'\bav1\b', caseSensitive: false),
  };

  // --- Release ---
  /// Low-quality words come first: a CAM stays a CAM whatever else its name
  /// says ("[TeleSync] Movie HDRip").
  static final Map<ReleaseQuality, RegExp> _qualities = {
    ReleaseQuality.cam: RegExp(r'camrip|\bcam\b|hd-?cam', caseSensitive: false),
    ReleaseQuality.telesync: RegExp(
      r'telesync|\bts\b|\bhd-?ts\b',
      caseSensitive: false,
    ),
    ReleaseQuality.bluray: RegExp(
      r'blu-?ray|\bbd-?(?:rip|remux)\b|\bbr-?rip\b|\bremux\b',
      caseSensitive: false,
    ),
    ReleaseQuality.webdl: RegExp(
      r'\bweb[-. ]?(?:dl|rip)|\bweb\b',
      caseSensitive: false,
    ),
    ReleaseQuality.hdtv: RegExp(r'\bhdtv(?:rip)?\b', caseSensitive: false),
    ReleaseQuality.hdrip: RegExp(r'\bhd-?rip\b', caseSensitive: false),
    ReleaseQuality.dvdrip: RegExp(
      r'\bdvd(?:-?r(?:ip)?|\d)?\b',
      caseSensitive: false,
    ),
  };

  static final Map<ReleaseFlag, RegExp> _flags = {
    ReleaseFlag.proper: RegExp(r'\bproper\b', caseSensitive: false),
    ReleaseFlag.repack: RegExp(r'\brepack\b', caseSensitive: false),
    ReleaseFlag.extended: RegExp(
      r"\bextended\b|\bdirector['’]?s[ .]cut\b",
      caseSensitive: false,
    ),
    ReleaseFlag.multi: RegExp(r'\bmulti\b', caseSensitive: false),
    ReleaseFlag.dual: RegExp(r'\bdual(?:[ .-]?audio)?\b', caseSensitive: false),
    ReleaseFlag.screener: RegExp(
      r'\b(?:dvd|bd|br|web|hd|ts)?(?:scr|screener)\b|\b(?:hd-?)?tc\b',
      caseSensitive: false,
    ),
    ReleaseFlag.threeD: RegExp(r'\b(?:3d|bd3d|h?sbs)\b', caseSensitive: false),
  };

  // --- Audio ---
  static final Map<AudioFormat, RegExp> _audioFormats = {
    AudioFormat.atmos: RegExp(r'\batmos\b', caseSensitive: false),
    AudioFormat.dts: RegExp(r'(?<![a-z0-9])dts', caseSensitive: false),
    AudioFormat.trueHd: RegExp(r'\btrue-?hd', caseSensitive: false),
    AudioFormat.ddPlus: RegExp(
      r'\bddp|\be-?ac-?3|\bdd\+',
      caseSensitive: false,
    ),
    AudioFormat.dd: RegExp(
      r'(?<!e-?)ac-?3\b|\bdd[ .]?\d[. ]\d',
      caseSensitive: false,
    ),
    AudioFormat.flac: RegExp(r'\bflac', caseSensitive: false),
    AudioFormat.opus: RegExp(r'\bopus', caseSensitive: false),
    AudioFormat.aac: RegExp(r'\baac', caseSensitive: false),
  };

  // A channel count, not a file size ("7.1 GB") or a longer number.
  static RegExp _channelCount(String count) => RegExp(
    '(?<![\\dv.])${RegExp.escape(count)}(?!\\d)(?!\\s*[gmtk]i?b\\b)',
    caseSensitive: false,
  );
  static final _sevenOne = _channelCount('7.1');
  static final _fiveOne = _channelCount('5.1');
  static final _twoZero = _channelCount('2.0');
  static final _stereo = RegExp(r'\bstereo\b', caseSensitive: false);

  // --- Languages ---
  static final Map<String, RegExp> _languageWords = {
    LanguageCodes.italian: RegExp(
      r'\b(?:ita|italian|italiano)\b',
      caseSensitive: false,
    ),
    LanguageCodes.english: RegExp(r'\b(?:eng|english)\b', caseSensitive: false),
    LanguageCodes.japanese: RegExp(
      r'\b(?:jpn|jap|japanese)\b',
      caseSensitive: false,
    ),
    LanguageCodes.multi: RegExp(r'\bmulti\b', caseSensitive: false),
  };

  static const Map<String, String> _languageFlags = {
    LanguageCodes.italian: '🇮🇹',
    LanguageCodes.english: '🇬🇧',
    LanguageCodes.japanese: '🇯🇵',
  };

  static const _subtitleWord =
      r'(?:sub|subs|subbed|subtitle|subtitles|sottotitoli|napisy)';
  static const _languageWord =
      r'(?:ita|italian|italiano|eng|english|jpn|jap|japanese|multi|rus|russian'
      r'|ukr|ukrainian|fra|fre|french|ger|german|spa|spanish)';

  /// "Sub ITA ENG", "SUB-ITA", "Sub (Rus Eng)": languages after the word.
  static final _subtitlesAfter = RegExp(
    '\\b$_subtitleWord\\b[\\s.\\-:(\\[]*'
    '(?:$_languageWord\\b[\\s.\\-+,/&\\\\)\\]]*)+',
    caseSensitive: false,
  );

  /// "Multi-Subs". A language before the word stays sound, as real names mean
  /// it: "AC3.ITA.ENG.SUBS", "Eng Ita Multi-Subs", "JAP+Sub".
  static final _multiSubtitles = RegExp(
    '\\bmulti[\\s.\\-/]*$_subtitleWord\\b',
    caseSensitive: false,
  );

  static final Map<ForeignLanguage, RegExp> _foreignLanguages = {
    ForeignLanguage.russian: RegExp(
      r'\b(?:rus|russian|ru)\b|lostfilm|hdrezka|syncmer',
      caseSensitive: false,
    ),
    ForeignLanguage.ukrainian: RegExp(
      r'\b(?:ukr|ukrainian)\b',
      caseSensitive: false,
    ),
    ForeignLanguage.french: RegExp(
      r'\b(?:fra|french|truefrench)\b',
      caseSensitive: false,
    ),
    ForeignLanguage.german: RegExp(r'\b(?:ger|german)\b', caseSensitive: false),
    ForeignLanguage.spanish: RegExp(
      r'\b(?:spa|spanish)\b',
      caseSensitive: false,
    ),
    ForeignLanguage.russianDubTeam: RegExp(
      r'lostfilm|hdrezka|syncmer|\bnewcomers\b',
      caseSensitive: false,
    ),
  };

  // --- Size ---
  static const _sizePattern =
      r'(\d+(?:[.,]\d+)?)\s*(TB|GB|MB|KB|TiB|GiB|MiB)\b';
  static final _statsSize = RegExp('💾\\s*$_sizePattern', caseSensitive: false);
  static final _anySize = RegExp(
    '(?<![\\d.,])$_sizePattern',
    caseSensitive: false,
  );

  /// Parses a raw stream title string into a structured [StreamMetadata] object.
  static StreamMetadata parse(String rawTitle) {
    // An underscore counts as part of a word, so "_1080p_" would not be
    // read as a whole word.
    final name = rawTitle.replaceAll('_', ' ').replaceAll(_tsExtension, ' ');
    final labels = _labelText(name);

    final subtitles = [
      ..._subtitlesAfter.allMatches(labels),
      ..._multiSubtitles.allMatches(labels),
    ].map((m) => m.group(0)).join(' ');
    final sound = labels
        .replaceAll(_subtitlesAfter, ' ')
        .replaceAll(_multiSubtitles, ' ');
    final flags = _findAll(sound, _flags);
    final languages = _parseLanguages(sound, subtitles, flags);

    return StreamMetadata(
      video: VideoMetadata(
        resolution:
            _findFirst(labels, _measuredSizes) ??
            _findFirst(labels, _sizeWords) ??
            VideoResolution.unknown,
        codec: _findFirst(labels, _codecs) ?? VideoCodec.unknown,
        isHDR: _hdr.hasMatch(labels),
        isDV: _dolbyVision.hasMatch(labels),
        is10Bit: _tenBit.hasMatch(labels),
      ),
      audio: AudioMetadata(
        formats: _findAll(labels, _audioFormats),
        channels: _parseChannels(labels),
      ),
      quality: _findFirst(labels, _qualities) ?? ReleaseQuality.unknown,
      flags: flags,
      languages: languages,
      // A Russian release often names only its subtitles ("MVO + Sub rus eng"),
      // so they count, unless the name has Italian sound ("ITA ENG sub rus").
      foreignLanguages: _findAll(
        languages.contains(LanguageCodes.italian) ? sound : labels,
        _foreignLanguages,
      ),
      size: _parseSize(name),
    );
  }

  /// The part of [name] the labels are read from: see the class comment.
  static String _labelText(String name) {
    final leading = _leadingBrackets.stringMatch(name) ?? '';
    final rest = name.substring(leading.length);
    final statsAt = rest.indexOf(_statsStart);
    final head = statsAt < 0 ? rest : rest.substring(0, statsAt);

    final yearOrEpisode = _yearOrEpisode.firstMatch(head);
    final size = _anyPictureSize.firstMatch(head);
    if (yearOrEpisode == null && size == null) return name;

    int start;
    if (size == null ||
        (yearOrEpisode != null && yearOrEpisode.start < size.start)) {
      start = yearOrEpisode!.start;
    } else {
      // Labels can sit right before a size ("Film SCR 1080p", "Movie AC3
      // ITA.ENG 1080p H265 (1997)"), though not before a year ("Cam 2018").
      final before = head.substring(0, size.start);
      start = _labelsBeforeSize.firstMatch(before)?.start ?? size.start;
    }

    final brackets = _anyBrackets
        .allMatches(rest.substring(0, start))
        .map((m) => m.group(0))
        .join(' ');
    return '$leading $brackets ${rest.substring(start)}';
  }

  static T? _findFirst<T>(String text, Map<T, RegExp> patterns) {
    for (final entry in patterns.entries) {
      if (entry.value.hasMatch(text)) return entry.key;
    }
    return null;
  }

  static List<T> _findAll<T>(String text, Map<T, RegExp> patterns) => [
    for (final entry in patterns.entries)
      if (entry.value.hasMatch(text)) entry.key,
  ];

  static int? _parseChannels(String labels) {
    if (_sevenOne.hasMatch(labels)) return 8;
    if (_fiveOne.hasMatch(labels)) return 6;
    if (_twoZero.hasMatch(labels) || _stereo.hasMatch(labels)) return 2;
    return null;
  }

  /// A language flag can come from subtitles too, so it doesn't count when
  /// the name names that language only as a subtitle.
  static List<String> _parseLanguages(
    String sound,
    String subtitles,
    List<ReleaseFlag> flags,
  ) {
    final languages = [
      for (final entry in _languageWords.entries)
        if (entry.value.hasMatch(sound) ||
            (_languageFlags[entry.key] != null &&
                sound.contains(_languageFlags[entry.key]!) &&
                !entry.value.hasMatch(subtitles)))
          entry.key,
    ];
    if (flags.contains(ReleaseFlag.dual) &&
        !languages.contains(LanguageCodes.multi)) {
      languages.add(LanguageCodes.dual);
    }
    return languages;
  }

  /// Torrentio's own size is the file's; one inside the name can be the whole
  /// season's.
  static String? _parseSize(String name) {
    final match = _statsSize.firstMatch(name) ?? _anySize.firstMatch(name);
    if (match == null) return null;
    final number = match.group(1)!.replaceAll(',', '.');
    return '$number ${match.group(2)}'.toUpperCase();
  }
}
