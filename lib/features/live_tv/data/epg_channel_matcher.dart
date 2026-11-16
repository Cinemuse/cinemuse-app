import 'package:cinemuse_app/features/live_tv/data/epg_parser.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_name.dart';
import 'package:cinemuse_app/features/live_tv/domain/epg_program.dart';

/// Intelligent matcher between TV channels and EPG program guides.
class EpgChannelMatcher {
  /// Finds all EPG programs for the specified channel using multi-tier matching.
  static List<EpgProgram> findPrograms(
    Channel channel,
    Map<String, List<EpgProgram>> epgData,
  ) {
    if (epgData.isEmpty) return const [];
    final hours = ChannelName.hoursLater(channel.name);

    // 1. The tvg-id. A "+1" channel pointing to the normal channel's guide
    // shows its programmes an hour later.
    final epgId = channel.epgId?.trim();
    if (epgId != null && epgId.isNotEmpty) {
      final byId = _byKeys([
        epgId,
        epgId.toLowerCase(),
        ChannelName.guideKey(epgId),
      ], epgData);
      if (byId != null) {
        return hours > 0 && !ChannelName.idIsHoursLater(epgId)
            ? _later(byId, hours)
            : byId;
      }
    }

    // 2. The name, then for a "+1" channel the normal channel's name.
    final byName = _byKeys(ChannelName.guideKeysForName(channel.name), epgData);
    if (byName != null) return byName;
    if (hours > 0) {
      final base = _byKeys(
        ChannelName.guideKeysForName(
          ChannelName.withoutHoursLater(channel.name),
        ),
        epgData,
      );
      if (base != null) return _later(base, hours);
    }

    // 3. The number, only when the guide itself says which channel has it
    // (the Cinemuse guide does): any other guide matches by id or name.
    if (channel.lcn > 0) {
      final byNumber = epgData[EpgParser.numberKey(channel.lcn)];
      if (byNumber != null) return byNumber;
    }

    return const [];
  }

  static List<EpgProgram>? _byKeys(
    List<String> keys,
    Map<String, List<EpgProgram>> epgData,
  ) {
    for (final key in keys) {
      final programs = key.isEmpty ? null : epgData[key];
      if (programs != null) return programs;
    }
    return null;
  }

  // Cached per guide list, so the guide and the channel list get the same
  // list back each time and don't redraw for nothing.
  static final _laterByHours = <int, Expando<List<EpgProgram>>>{};

  static List<EpgProgram> _later(List<EpgProgram> programs, int hours) {
    final cache = _laterByHours[hours] ??= Expando<List<EpgProgram>>();
    final shift = Duration(hours: hours);
    return cache[programs] ??= List.unmodifiable([
      for (final p in programs)
        EpgProgram(
          name: p.name,
          startTime: p.startTime.add(shift),
          endTime: p.endTime.add(shift),
          subtitle: p.subtitle,
          description: p.description,
          imageUrl: p.imageUrl,
        ),
    ]);
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
}
