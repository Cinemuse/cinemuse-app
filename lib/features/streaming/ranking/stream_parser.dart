import 'package:cinemuse_app/features/streaming/models/stream_metadata.dart';
import 'package:cinemuse_app/features/streaming/ranking/language_codes.dart';

/// A utility class responsible for extracting technical metadata from stream titles.
///
/// It uses a declarative pattern-matching registry to standardize various
/// naming conventions into a structured [StreamMetadata] object.
/// Short tags are matched as whole words (`\b`), so `2k`, `hdr` or `multi`
/// inside other words don't count (STR-02).
class StreamParser {
  // --- Video Patterns ---
  static final Map<VideoResolution, RegExp> _resolutions = {
    VideoResolution.r2160p: RegExp(r'\b(2160p|4k|uhd)\b', caseSensitive: false),
    VideoResolution.r1440p: RegExp(r'\b(1440p|2k)\b', caseSensitive: false),
    VideoResolution.r1080p: RegExp(r'\b1080p\b', caseSensitive: false),
    VideoResolution.r720p: RegExp(r'\b720p\b', caseSensitive: false),
    VideoResolution.r480p: RegExp(r'\b480p\b', caseSensitive: false),
  };

  static final _hdr = RegExp(r'\bhdr(10)?\b', caseSensitive: false);
  static final _dolbyVision = RegExp(r'\b(dv|dovi)\b', caseSensitive: false);

  static final Map<VideoCodec, RegExp> _codecs = {
    VideoCodec.hevc: RegExp(r'hevc|x265|h265', caseSensitive: false),
    VideoCodec.h264: RegExp(r'x264|h264|avc', caseSensitive: false),
    VideoCodec.av1: RegExp(r'av1', caseSensitive: false),
  };

  // --- Quality & Flags Patterns ---
  static final Map<ReleaseQuality, RegExp> _qualities = {
    ReleaseQuality.bluray: RegExp(r'bluray|bdr-?ip', caseSensitive: false),
    ReleaseQuality.webdl: RegExp(r'web-?dl|web-?rip', caseSensitive: false),
    ReleaseQuality.dvdrip: RegExp(r'dvdrip|dvdr', caseSensitive: false),
    ReleaseQuality.telesync: RegExp(
      r'telesync|\bts\b|hd-?ts',
      caseSensitive: false,
    ),
    ReleaseQuality.cam: RegExp(r'camrip|\bcam\b|hd-?cam', caseSensitive: false),
  };

  static final Map<ReleaseFlag, RegExp> _flags = {
    ReleaseFlag.proper: RegExp(r'\bproper\b', caseSensitive: false),
    ReleaseFlag.repack: RegExp(r'\brepack\b', caseSensitive: false),
    ReleaseFlag.extended: RegExp(
      r"extended(\.cut)?|director's\.cut",
      caseSensitive: false,
    ),
    ReleaseFlag.multi: RegExp(r'\bmulti\b', caseSensitive: false),
    ReleaseFlag.dual: RegExp(r'\bdual\b', caseSensitive: false),
  };

  // --- Audio Patterns ---
  static final Map<AudioFormat, RegExp> _audioFormats = {
    AudioFormat.atmos: RegExp(r'atmos', caseSensitive: false),
    AudioFormat.dts: RegExp(r'dts(-hd|x)?', caseSensitive: false),
    AudioFormat.ddPlus: RegExp(r'ddp|e-?ac3|dd\+', caseSensitive: false),
    AudioFormat.dd: RegExp(r'ac3|dd5\.1', caseSensitive: false),
    AudioFormat.aac: RegExp(r'aac', caseSensitive: false),
  };

  /// Parses a raw stream title string into a structured [StreamMetadata] object.
  static StreamMetadata parse(String title) {
    return StreamMetadata(
      video: VideoMetadata(
        resolution: _findEnum(title, _resolutions, VideoResolution.unknown),
        codec: _findEnum(title, _codecs, VideoCodec.unknown),
        isHDR: _hdr.hasMatch(title),
        isDV: _dolbyVision.hasMatch(title),
        is10Bit: title.toLowerCase().contains('10bit'),
      ),
      audio: AudioMetadata(
        formats: _findAllEnums(title, _audioFormats),
        channels: _parseChannels(title),
      ),
      quality: _findEnum(title, _qualities, ReleaseQuality.unknown),
      flags: _findAllEnums(title, _flags),
      languages: _parseLanguages(title),
      size: _parseSize(title),
    );
  }

  // --- Helper Methods ---

  static T _findEnum<T>(String title, Map<T, RegExp> patterns, T defaultValue) {
    for (final entry in patterns.entries) {
      if (entry.value.hasMatch(title)) return entry.key;
    }
    return defaultValue;
  }

  static List<T> _findAllEnums<T>(String title, Map<T, RegExp> patterns) {
    final List<T> results = [];
    for (final entry in patterns.entries) {
      if (entry.value.hasMatch(title)) results.add(entry.key);
    }
    return results;
  }

  static int? _parseChannels(String title) {
    final t = title.toLowerCase();
    if (t.contains('7.1')) return 8;
    if (t.contains('5.1')) return 6;
    if (t.contains('2.0') || t.contains('stereo')) return 2;
    return null;
  }

  static final Map<String, RegExp> _languages = {
    LanguageCodes.italian: RegExp(
      r'\b(ita|italian)\b|🇮🇹',
      caseSensitive: false,
    ),
    LanguageCodes.english: RegExp(
      r'\b(eng|english)\b|🇬🇧',
      caseSensitive: false,
    ),
    LanguageCodes.japanese: RegExp(
      r'\b(jpn|jap|japanese)\b|🇯🇵',
      caseSensitive: false,
    ),
    LanguageCodes.multi: RegExp(r'\bmulti\b', caseSensitive: false),
  };

  static List<String> _parseLanguages(String title) =>
      _findAllEnums(title, _languages);

  static String? _parseSize(String title) {
    final match = RegExp(
      r'(\d+(?:\.\d+)?)\s*(GB|MB|GiB|MiB|KB|B)(?!bit)',
      caseSensitive: false,
    ).firstMatch(title);
    if (match != null) {
      return "${match.group(1)} ${match.group(2)}".toUpperCase();
    }
    return null;
  }
}
