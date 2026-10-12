import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/epg_program.dart';

/// Intelligent matcher between TV channels and EPG program guides.
class EpgChannelMatcher {
  /// Known LCN to canonical EPG ID mappings for Italian television channels.
  static const Map<int, String> lcnToCanonicalId = {
    1: 'rai1',
    2: 'rai2',
    3: 'rai3',
    4: 'r4',
    5: 'c5',
    6: 'i1',
    7: 'la7',
    8: 'tv8',
    9: 'deejay',
    20: '20',
    21: 'rai4',
    22: 'iris',
    23: 'rai5',
    24: 'raimovie',
    25: 'raipremium',
    26: 'cielo',
    27: 'twentyseven',
    28: 'tv2000',
    34: 'cine34',
    35: 'focus',
    39: 'topcrime',
    49: 'italia2',
    50: 'sky_tg24',
    51: 'tgcom24',
    54: 'raistoria',
    55: 'med_extra',
    57: 'raisport',
    58: 'raiscuola',
    60: 'sportitalia',
    61: 'solocalcio',
    64: 'supertennis',
    108: 'skyuno',
    112: 'skyserie',
    200: 'dlhd_869', // Sky Sport 24
    201: 'skysportuno', // Sky Sport Uno
    202: 'dlhd_870', // Sky Sport Calcio
    203: 'dlhd_871', // Sky Sport Tennis
    204: 'dlhd_872', // Sky Sport Arena
    205: 'dlhd_873', // Sky Sport Max
    206: 'dlhd_874', // Sky Sport Golf
    207: 'dlhd_875', // Sky Sport F1
    208: 'dlhd_876', // Sky Sport MotoGP
    209: 'dlhd_877', // Sky Sport NBA
    210: 'dlhd_878', // Eurosport 1
    211: 'dlhd_879', // Eurosport 2
    213: 'dlhd_881', // Sky Sport 4K
    214: 'dlhd_882', // Zona DAZN
    215: 'dlhd_883', // DAZN 2
    216: 'dlhd_884', // DAZN 3 / Sky Sport
    217: 'dlhd_885', // DAZN 4 / Sky Sport
    218: 'dlhd_886', // DAZN 5 / Sky Sport
    251: 'dlhd_883', // Sky Sport 251
    252: 'dlhd_884', // Sky Sport 252
    253: 'dlhd_885', // Sky Sport 253
    254: 'dlhd_886', // Sky Sport 254
    255: 'dlhd_887', // Sky Sport 255
    256: 'dlhd_888', // Sky Sport 256
    257: 'dlhd_889', // Sky Sport 257
    258: 'dlhd_890', // Sky Sport 258
    259: 'dlhd_891', // Sky Sport 259
    260: 'dlhd_892', // Sky Sport 260
    301: 'skycineuno', // Sky Cinema Uno
    302: 'skycinedue', // Sky Cinema Due
    303: 'skycinecol', // Sky Cinema Collection
    304: 'skycinefam', // Sky Cinema Family
    305: 'skycineact', // Sky Cinema Action
    306: 'skycinesusp', // Sky Cinema Suspense
    307: 'skycinerom', // Sky Cinema Romance
    308: 'skycinedra', // Sky Cinema Drama
    309: 'skycinecom', // Sky Cinema Comedy
  };

  /// Finds all EPG programs for the specified channel using multi-tier matching.
  static List<EpgProgram> findPrograms(
    Channel channel,
    Map<String, List<EpgProgram>> epgData,
  ) {
    if (epgData.isEmpty) return const [];

    // 1. Direct epgId match
    final epgId = channel.epgId?.trim();
    if (epgId != null && epgId.isNotEmpty) {
      if (epgData.containsKey(epgId)) return epgData[epgId]!;

      final lower = epgId.toLowerCase();
      if (epgData.containsKey(lower)) return epgData[lower]!;

      final stripped = _stripDomain(lower);
      if (stripped.isNotEmpty && epgData.containsKey(stripped)) {
        return epgData[stripped]!;
      }
    }

    // 2. Normalized Name match
    final normName = _normalizeName(channel.name);
    if (normName.isNotEmpty && epgData.containsKey(normName)) {
      return epgData[normName]!;
    }

    // 3. LCN fallback match
    if (channel.lcn > 0) {
      final canonicalFromLcn = lcnToCanonicalId[channel.lcn];
      if (canonicalFromLcn != null && epgData.containsKey(canonicalFromLcn)) {
        return epgData[canonicalFromLcn]!;
      }

      final lcnKey = 'lcn:${channel.lcn}';
      if (epgData.containsKey(lcnKey)) return epgData[lcnKey]!;
    }

    return const [];
  }

  /// Calculates the currently airing program and upcoming program.
  static ({EpgProgram? current, EpgProgram? next}) getNowAndNext(
    Channel channel,
    Map<String, List<EpgProgram>> epgData,
  ) {
    final programs = findPrograms(channel, epgData);
    if (programs.isEmpty) return (current: null, next: null);

    final now = DateTime.now();
    for (int i = 0; i < programs.length; i++) {
      final p = programs[i];
      if (now.isAfter(p.startTime) && now.isBefore(p.endTime)) {
        final next = (i + 1 < programs.length) ? programs[i + 1] : null;
        return (current: p, next: next);
      }
    }

    // If no program is strictly live, return first upcoming program
    for (final p in programs) {
      if (p.startTime.isAfter(now)) {
        return (current: null, next: p);
      }
    }

    return (current: null, next: null);
  }

  static String _stripDomain(String key) {
    return key
        .replaceAll(RegExp(r'\.it$|\.ch$|\.com$|\.eu$'), '')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static String _normalizeName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'\b(fhd|uhd|hd|sd|4k|1080p|720p)\b'), '')
        .replaceAll(RegExp(r'\b(italia|italy)\b'), '')
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .trim();
  }
}
