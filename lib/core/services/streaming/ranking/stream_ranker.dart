import 'package:cinemuse_app/core/services/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_metadata.dart';
import 'package:cinemuse_app/core/services/streaming/ranking/stream_parser.dart';

/// A utility class responsible for scoring and ranking [StreamCandidate]s.
///
/// It uses [StreamParser] to standardize titles and calculates a quality score 
/// based on provider-agnostic criteria (resolution, codecs, language, etc.).
class StreamRanker {
  /// Sorts a list of candidates based on cache status and calculated score.
  ///
  /// Streams cached on debrid services are prioritized first, followed by descending scores.
  static List<StreamCandidate> rank(List<StreamCandidate> candidates, {String preferredLanguage = 'en'}) {
    return candidates.map((c) {
      final s = score(c, preferredLanguage: preferredLanguage);
      return c.copyWith(
        score: s,
      );
    }).toList()
      ..sort((a, b) {
        // First by cache status
        if (a.isCached != b.isCached) {
          return a.isCached ? -1 : 1;
        }
        // Then by score
        return b.score.compareTo(a.score);
      });
  }

  /// Calculates a numerical score for a [StreamCandidate] based on its metadata.
  ///
  /// The final score is the sum of domain-specific scoring functions.
  static int score(StreamCandidate candidate, {String preferredLanguage = 'en'}) {
    final metadata = candidate.metadata ?? StreamParser.parse(candidate.title);
    
    int s = 0;
    s += _scoreLanguage(metadata, candidate.title, preferredLanguage: preferredLanguage);
    s += _scoreVideo(metadata.video, candidate.title);
    s += _scoreQuality(metadata.quality);
    s += _scoreReleaseFlags(metadata.flags);
    s += _scoreHealth(candidate.seeds);
    
    return s;
  }

  static int _scoreLanguage(StreamMetadata metadata, String title, {String preferredLanguage = 'en'}) {
    int s = 0;
    final isItalian = metadata.languages.contains('ITA');
    final isEnglish = metadata.languages.contains('ENG');
    final isMulti = title.toLowerCase().contains('multi') || (isItalian && isEnglish);

    // Direct match for preferred language
    final isOriginalJa = preferredLanguage == 'ja';
    
    if (metadata.languages.contains(preferredLanguage.toUpperCase()) || 
        (isOriginalJa && (metadata.languages.contains('JAP') || metadata.languages.contains('JAPANESE') || metadata.languages.contains('JP')))) {
      return 1000;
    }

    // MULTI often contains many languages including the preferred one
    if (metadata.languages.contains('MULTI')) {
      // For anime original, MULTI is very likely to have JA
      return isOriginalJa ? 900 : 800;
    }

    // Boost based on preferred language
    final pref = preferredLanguage.toLowerCase();
    if (pref == 'it' || pref == 'ita') {
      if (isItalian) s += 100;
      if (isEnglish) s += 20;
    } else if (pref == 'en' || pref == 'eng') {
      if (isEnglish) s += 100;
      if (isItalian) s += 20;
    } else {
      // Fallback/Other languages
      if (isEnglish) s += 50;
    }

    if (isMulti) s += 150;

    final t = title.toLowerCase();
    if (t.contains(' rus') || t.contains('.ru.') || t.contains('russian') || t.contains('lostfilm') || t.contains('hdrezka') || t.contains('syncmer')) s -= 500;
    if (t.contains(' ukr') || t.contains('ukrainian')) s -= 500;
    if (t.contains(' fra') || t.contains('french')) s -= 200;
    if (t.contains(' ger') || t.contains('german')) s -= 200;
    if (t.contains(' spa') || t.contains('spanish')) s -= 200;

    if (!isItalian && (t.contains('lostfilm') || t.contains('hdrezka') || t.contains('syncmer') || t.contains('newcomers'))) s -= 800;
    return s;
  }

  static int _scoreVideo(VideoMetadata video, String title) {
    int s = 0;
    if (video.codec == VideoCodec.hevc || video.is10Bit) s += 30;
    if (video.isHDR || video.isDV) s += 25;

    switch (video.resolution) {
      case VideoResolution.r2160p:
        s += 50;
        if (video.codec != VideoCodec.hevc) s -= 20;
        break;
      case VideoResolution.r1440p:
        s += 40;
        break;
      case VideoResolution.r1080p:
        s += 30;
        break;
      case VideoResolution.r720p:
        s += 10;
        break;
      case VideoResolution.r480p:
        s -= 50;
        break;
      case VideoResolution.unknown:
        s -= 30;
        break;
    }
    return s;
  }

  static int _scoreQuality(ReleaseQuality quality) {
    switch (quality) {
      case ReleaseQuality.bluray:
        return 40;
      case ReleaseQuality.webdl:
        return 20;
      case ReleaseQuality.dvdrip:
        return 5;
      case ReleaseQuality.telesync:
        return -1000; // Massive penalty for TS
      case ReleaseQuality.cam:
        return -2000; // Even bigger for CAM
      case ReleaseQuality.unknown:
        return 0;
    }
  }

  static int _scoreReleaseFlags(List<ReleaseFlag> flags) {
    int s = 0;
    if (flags.contains(ReleaseFlag.proper)) s += 10;
    if (flags.contains(ReleaseFlag.repack)) s += 10;
    if (flags.contains(ReleaseFlag.extended)) s += 5;
    return s;
  }

  static int _scoreHealth(int seeds) {
    if (seeds > 100) return 20;
    if (seeds > 50) return 15;
    if (seeds > 10) return 10;
    if (seeds > 0) return 5;
    return 0;
  }
}
