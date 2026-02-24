import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/epg_program.dart';

class LiveTvRepository {
  final Dio _dio;

  static const _channelsUrl =
      'https://raw.githubusercontent.com/ZapprTV/channels/refs/heads/main/it/dtt/national.json';
  static const _epgUrl =
      'https://epg-57v9m5qem-quelmitchs-projects.vercel.app/output/it/dtt/national.json';

  LiveTvRepository(this._dio);

  /// Parses response data — handles both String and pre-parsed Map/List.
  dynamic _parseResponse(dynamic data) {
    if (data is String) {
      return json.decode(data);
    }
    return data;
  }

  /// Fetches the channel list, filtering to only playable channels.
  /// If [region] is provided, it also fetches regional channels.
  Future<List<Channel>> fetchChannels({String? region}) async {
    try {
      final List<dynamic> allChannelsJson = [];

      // 1. Fetch National Channels
      final nationalResponse = await _dio.get(_channelsUrl);
      final nationalData = _parseResponse(nationalResponse.data) as Map<String, dynamic>;
      allChannelsJson.addAll(nationalData['channels'] as List<dynamic>);

      // 2. Fetch Regional Channels if selected
      if (region != null && region.isNotEmpty) {
        final regionalUrl = 'https://raw.githubusercontent.com/ZapprTV/channels/refs/heads/main/it/dtt/regional/$region.json';
        try {
          final regionalResponse = await _dio.get(regionalUrl);
          final regionalData = _parseResponse(regionalResponse.data) as Map<String, dynamic>;
          allChannelsJson.addAll(regionalData['channels'] as List<dynamic>);
        } catch (_) {
        }
      }


      // ── Build channel map ──
      // First pass: add all playable channels to the map.
      // Regional channels (appended after national) override at the same LCN,
      // but only if they have a compatible URL.
      final Map<int, Channel> channelMap = {};
      for (final json in allChannelsJson) {
        try {
          final channel = Channel.fromJson(json as Map<String, dynamic>);
          if (channel.isPlayable) {
            final existing = channelMap[channel.lcn];
            if (existing == null || !_isMpvIncompatible(channel.url)) {
              channelMap[channel.lcn] = channel;
            }
          }
        } catch (_) {
        }
      }

      // Second pass: fix channels stuck with incompatible URLs.
      // Look for a national counterpart (same base name, different LCN)
      // that has a working URL, and borrow it.
      for (final lcn in channelMap.keys.toList()) {
        final ch = channelMap[lcn]!;
        if (!_isMpvIncompatible(ch.url)) continue;

        // Find a counterpart: e.g. "Rai 3" matches "Rai 3 TGR Piemonte"
        final donor = channelMap.values.where((other) =>
          other.lcn != ch.lcn &&
          !_isMpvIncompatible(other.url) &&
          _isNameMatch(ch.name, other.name),
        ).firstOrNull;

        if (donor != null) {
          channelMap[lcn] = Channel(
            lcn: ch.lcn,
            name: ch.name,
            logo: ch.logo,
            hd: ch.hd,
            uhd: ch.uhd,
            type: ch.type,
            url: donor.url,  // borrow the working URL
            subtitle: ch.subtitle,
            epgSource: ch.epgSource,
            epgId: ch.epgId,
            isGeoblocked: ch.isGeoblocked,
            isDisabled: ch.isDisabled,
            isFeed: ch.isFeed,
            isRadio: ch.isRadio,
            isAdult: ch.isAdult,
          );

        }
      }

      final channels = channelMap.values.toList();
      
      // Sort by LCN for natural channel ordering
      channels.sort((a, b) => a.lcn.compareTo(b.lcn));

      return channels;
    } catch (e) {
      rethrow;
    }
  }

  /// CDN hosts that require HTTP headers mpv/media_kit cannot inject.
  static bool _isMpvIncompatible(String url) =>
      url.contains('akamaized.net');

  /// Checks if two channel names share a common base.
  /// e.g. "Rai 3 TGR Piemonte" and "Rai 3" → the longer starts with the shorter.
  static bool _isNameMatch(String a, String b) {
    final la = a.toLowerCase().trim();
    final lb = b.toLowerCase().trim();
    if (la == lb) return false; // skip exact duplicates at same LCN
    return la.startsWith(lb) || lb.startsWith(la);
  }

  /// Fetches the EPG data.
  ///
  /// Returns a map: `{ "source": { "channelId": [EpgProgram, ...] } }`
  Future<Map<String, Map<String, List<EpgProgram>>>> fetchEpg() async {
    try {
      final response = await _dio.get(_epgUrl);
      final data = _parseResponse(response.data) as Map<String, dynamic>;
      final result = <String, Map<String, List<EpgProgram>>>{};

      for (final sourceEntry in data.entries) {
        final sourceMap = <String, List<EpgProgram>>{};
        final sourceData = sourceEntry.value;

        if (sourceData is Map<String, dynamic>) {
          for (final channelEntry in sourceData.entries) {
            final programs = channelEntry.value;
            if (programs is List) {
              sourceMap[channelEntry.key] = programs
                  .map((p) {
                    try {
                      return EpgProgram.fromJson(p as Map<String, dynamic>);
                    } catch (_) {
                      return null;
                    }
                  })
                  .whereType<EpgProgram>()
                  .toList();
            }
          }
        }

        result[sourceEntry.key] = sourceMap;
      }


      return result;
    } catch (_) {
      // EPG is optional — return empty if unavailable
      return {};
    }
  }

  /// Looks up the current and next programs for a given channel.
  ({EpgProgram? current, EpgProgram? next}) getProgramsForChannel(
    Channel channel,
    Map<String, Map<String, List<EpgProgram>>> epgData,
  ) {
    if (channel.epgSource == null || channel.epgId == null) {
      return (current: null, next: null);
    }

    final sourcePrograms = epgData[channel.epgSource];
    if (sourcePrograms == null) return (current: null, next: null);

    final programs = sourcePrograms[channel.epgId];
    if (programs == null || programs.isEmpty) return (current: null, next: null);

    final now = DateTime.now();
    EpgProgram? current;
    EpgProgram? next;

    for (int i = 0; i < programs.length; i++) {
      final program = programs[i];
      if (now.isAfter(program.startTime) && now.isBefore(program.endTime)) {
        current = program;
        if (i + 1 < programs.length) {
          next = programs[i + 1];
        }
        break;
      }
    }

    return (current: current, next: next);
  }
}
