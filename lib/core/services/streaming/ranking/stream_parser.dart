import 'package:cinemuse_app/core/services/streaming/models/stream_metadata.dart';

/// A utility class responsible for extracting technical metadata from stream titles.
/// 
/// It uses a declarative pattern-matching registry to standardize various 
/// naming conventions into a structured [StreamMetadata] object.
class StreamParser {
  // --- Video Patterns ---
  static final Map<VideoResolution, RegExp> _resolutions = {
    VideoResolution.r2160p: RegExp(r'2160p|4k|uhd', caseSensitive: false),
    VideoResolution.r1440p: RegExp(r'1440p|2k', caseSensitive: false),
    VideoResolution.r1080p: RegExp(r'1080p', caseSensitive: false),
    VideoResolution.r720p: RegExp(r'720p', caseSensitive: false),
    VideoResolution.r480p: RegExp(r'480p', caseSensitive: false),
  };

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
    ReleaseQuality.telesync: RegExp(r'telesync|\bts\b|hd-?ts', caseSensitive: false),
    ReleaseQuality.cam: RegExp(r'camrip|\bcam\b|hd-?cam', caseSensitive: false),
  };

  static final Map<ReleaseFlag, RegExp> _flags = {
    ReleaseFlag.proper: RegExp(r'\bproper\b', caseSensitive: false),
    ReleaseFlag.repack: RegExp(r'\brepack\b', caseSensitive: false),
    ReleaseFlag.extended: RegExp(r"extended(\.cut)?|director's\.cut", caseSensitive: false),
    ReleaseFlag.multi: RegExp(r'multi', caseSensitive: false),
    ReleaseFlag.dual: RegExp(r'dual', caseSensitive: false),
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
        isHDR: title.toLowerCase().contains('hdr'),
        isDV: title.toLowerCase().contains(' dv ') || title.toLowerCase().contains('dovi'),
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

  static List<String> _parseLanguages(String title) {
    final List<String> langs = [];
    
    final itaMatch = RegExp(r'\b(ita|italian)\b|🇮🇹', caseSensitive: false).hasMatch(title);
    final engMatch = RegExp(r'\b(eng|english)\b|🇬🇧', caseSensitive: false).hasMatch(title);

    if (itaMatch) langs.add('ITA');
    if (engMatch) langs.add('ENG');
    
    return langs;
  }

  static String? _parseSize(String title) {
    final match = RegExp(r'(\d+(?:\.\d+)?)\s*(GB|MB|GiB|MiB|KB|B)(?!bit)', caseSensitive: false).firstMatch(title);
    if (match != null) {
      return "${match.group(1)} ${match.group(2)}".toUpperCase();
    }
    return null;
  }
}
