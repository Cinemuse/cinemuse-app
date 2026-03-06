import 'package:cinemuse_app/core/services/streaming/models/stream_candidate.dart';

class StreamRanker {
  static List<StreamCandidate> rank(List<StreamCandidate> candidates) {
    return candidates.map((c) {
      final s = score(c);
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

  static int score(StreamCandidate candidate) {
    int s = 0;
    final t = candidate.title.toLowerCase();

    // Language detection
    final isItalian = t.contains('ita') || t.contains('italian') || t.contains('italy') || t.contains(RegExp(r'\bit\b')) || t.contains('🇮🇹');
    final isEnglish = t.contains('eng') || t.contains('english') || t.contains(RegExp(r'\ben\b')) || t.contains('🇬🇧') || t.contains('🇺🇸');
    final isMulti = t.contains('multi') || (isItalian && isEnglish);

    // Language prioritization
    if (isItalian) s += 100;
    if (isEnglish) s += 20;
    if (isMulti) s += 150; // Massively boost ITA+ENG / Multi

    // Negative scoring for non-preferred languages
    if (t.contains(' rus') || t.contains('.ru.') || t.contains('russian') || t.contains('lostfilm') || t.contains('hdrezka') || t.contains('syncmer')) s -= 500;
    if (t.contains(' ukr') || t.contains('ukrainian')) s -= 500;
    if (t.contains(' fra') || t.contains('french')) s -= 200;
    if (t.contains(' ger') || t.contains('german')) s -= 200;
    if (t.contains(' spa') || t.contains('spanish')) s -= 200;

    // Specifically penalize common Russian release groups if Italian is not present
    if (!isItalian && (t.contains('lostfilm') || t.contains('hdrezka') || t.contains('syncmer') || t.contains('newcomers'))) s -= 800;

    // Video quality & 10-bit
    if (t.contains('10bit') || t.contains('hevc') || t.contains('x265') || t.contains('h265')) s += 30;
    if (t.contains('hdr') || t.contains(' dv ') || t.contains('dovi')) s += 25;

    // Resolution & Penalization
    if (t.contains('2160p') || t.contains('4k')) s += 50;
    else if (t.contains('1080p')) s += 30;
    else if (t.contains('720p')) s += 10;
    else if (t.contains('480p')) s -= 50; // Penalize SD
    else s -= 30; // Unknown or other resolution penalty

    // Penalize "Other" types (DVDRip, HDRip, etc.)
    if (t.contains('dvdrip') || t.contains('hdrip') || t.contains('bdrip') || t.contains('dvdscr')) s -= 40;

    // Seeders impact (logarithmic-ish)
    final seeds = candidate.seeds;
    if (seeds > 100) s += 20;
    else if (seeds > 50) s += 15;
    else if (seeds > 10) s += 10;
    else if (seeds > 0) s += 5;

    // Penalize older codecs for 4K if not HEVC (rare but possible)
    if (t.contains('2160p') && !t.contains('hevc') && !t.contains('x265')) s -= 20;

    return s;
  }

  static Map<String, dynamic> parseMetadata(String title) {
    final t = title.toLowerCase();

    // 1. Resolution
    String? resolution;
    if (t.contains('2160p') || t.contains('4k')) resolution = '4K';
    else if (t.contains('1080p')) resolution = '1080p';
    else if (t.contains('720p')) resolution = '720p';
    else if (t.contains('480p')) resolution = '480p';

    // 2. Quality/Source
    final List<String> qualityIndicators = [];
    if (t.contains('bluray') || t.contains('bdrip')) qualityIndicators.add('BluRay');
    else if (t.contains('web-dl') || t.contains('webrip') || t.contains(' amzn ') || t.contains(' nf ')) qualityIndicators.add('WEB-DL');
    else if (t.contains('hdtv')) qualityIndicators.add('HDTV');

    if (t.contains('remux')) qualityIndicators.add('REMUX');
    if (t.contains('10bit')) qualityIndicators.add('10bit');
    if (t.contains('hdr') || t.contains(' dv ') || t.contains('dovi')) qualityIndicators.add('HDR');

    // 3. Codecs
    String? codec;
    if (t.contains('hevc') || t.contains('x265') || t.contains('h265')) codec = 'HEVC';
    else if (t.contains('x264') || t.contains('h264') || t.contains('avc')) codec = 'x264';

    // 4. Audio
    final List<String> audioFeatures = [];
    if (t.contains('atmos')) audioFeatures.add('Atmos');
    else if (t.contains('dts')) audioFeatures.add('DTS');
    else if (t.contains('aac')) audioFeatures.add('AAC');
    else if (t.contains('ac3') || t.contains('dd5.1') || t.contains('ddp')) audioFeatures.add('DD');

    // 5. Languages
    final List<String> languages = [];
    final isItalian = t.contains('ita') || t.contains('italian') || t.contains('italy') || t.contains(RegExp(r'\bit\b')) || t.contains('🇮🇹');
    final isEnglish = t.contains('eng') || t.contains('english') || t.contains(RegExp(r'\ben\b')) || t.contains('🇬🇧') || t.contains('🇺🇸');

    if (isItalian) languages.add('ITA');
    if (isEnglish) languages.add('ENG');
    if (t.contains('multi') && languages.isEmpty) languages.add('MULTI');

    // 6. File Size
    String? size;
    final sizeMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(GB|MB|GiB|MiB|KB|B)(?!bit)', caseSensitive: false).firstMatch(title);
    if (sizeMatch != null) {
      size = "${sizeMatch.group(1)} ${sizeMatch.group(2)}".toUpperCase();
    }

    return {
      'resolution': resolution,
      'quality': qualityIndicators,
      'codec': codec,
      'audio': audioFeatures,
      'languages': languages,
      'size': size,
    };
  }
}
