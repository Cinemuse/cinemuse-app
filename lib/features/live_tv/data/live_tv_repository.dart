import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/epg_program.dart';
import 'package:cinemuse_app/features/live_tv/domain/stream_link.dart';

class LiveTvRepository {
  final Dio _dio;

  static const _channelsUrl =
      'https://raw.githubusercontent.com/ZapprTV/channels/refs/heads/main/it/dtt/national.json';
  static const _epgUrl =
      'https://epg.zappr.stream/it/dtt/national.json';

  // Premium scraped list from user's Gist
  static const _premiumChannelsUrl = 'https://gist.githubusercontent.com/quelmitch/ab33cc9daf45b96fe226ae57d86db98d/raw/channels.json';

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

      if (region != null && region.isNotEmpty) {
        final regionalUrl = 'https://raw.githubusercontent.com/ZapprTV/channels/refs/heads/main/it/dtt/regional/$region.json';
        try {
          final regionalResponse = await _dio.get(regionalUrl);
          final regionalData = _parseResponse(regionalResponse.data) as Map<String, dynamic>;
          allChannelsJson.addAll(regionalData['channels'] as List<dynamic>);
        } catch (_) {
          // Regional fail is non-critical
        }
      }

      // ── Build channel map ──
      // Keys are LCNs. Stable DTT channels get priority seat on the LCN bus.
      final Map<int, Channel> channelMap = {};
      final Map<String, Channel> nameLookup = {}; // For merging scraped links later

      for (final json in allChannelsJson) {
        try {
          final channel = Channel.fromJson(json as Map<String, dynamic>);
          if (channel.isPlayable) {
            final existing = channelMap[channel.lcn];
            if (existing == null || !_isMpvIncompatible(channel.url)) {
              // Assign "Generale" as default category for national channels
              final withGroup = Channel(
                lcn: channel.lcn,
                name: channel.name,
                logo: channel.logo,
                hd: channel.hd,
                uhd: channel.uhd,
                type: channel.type,
                urlOverride: channel.urlOverride,
                links: channel.links,
                group: 'Generale',
                subtitle: channel.subtitle,
                epgSource: channel.epgSource,
                epgId: channel.epgId,
                isGeoblocked: channel.isGeoblocked,
                isDisabled: channel.isDisabled,
                isFeed: channel.isFeed,
                isRadio: channel.isRadio,
                isAdult: channel.isAdult,
              );
              channelMap[channel.lcn] = withGroup;
              nameLookup[_normalize(channel.name)] = withGroup;
            }
          }
        } catch (_) {}
      }

      // ── Load & Merge Premium Scraped Channels ──
      try {
        // For development, we might load from local file system or a provided URL
        // In this specific task, we'll try to reach the local artifact we just generated
        // Note: In real production, this would be a URL.
        final premiumJson = await _loadPremiumData();
        if (premiumJson != null) {
          _mergePremiumChannels(channelMap, nameLookup, premiumJson);
        }
      } catch (e) {
        // Log but don't crash, we still have the stable DTT links
        print('Error merging premium channels: $e');
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
            urlOverride: donor.url,  // borrow the working URL
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
      
      // Sort: LCN 1-999 first, then alphabetically for channels without LCN
      channels.sort((a, b) {
        if (a.lcn > 0 && b.lcn > 0) return a.lcn.compareTo(b.lcn);
        if (a.lcn > 0) return -1;
        if (b.lcn > 0) return 1;
        return a.name.compareTo(b.name);
      });

      return channels;
    } catch (e) {
      rethrow;
    }
  }

  /// Helper to normalize names for matching
  static String _normalize(String name) {
    return name.toUpperCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(' +', '+')
        .trim();
  }

  /// Loads premium data from the Gist URL
  Future<Map<String, dynamic>?> _loadPremiumData() async {
    try {
      final response = await _dio.get(_premiumChannelsUrl);
      return _parseResponse(response.data) as Map<String, dynamic>;
    } catch (e) {
      print('LiveTvRepository: Failed to load premium data: $e');
      return null;
    }
  }

  /// Merges scraped premium channels into the existing DTT map
  void _mergePremiumChannels(
    Map<int, Channel> channelMap, 
    Map<String, Channel> nameLookup,
    Map<String, dynamic> premiumJson,
  ) {
    int syntheticLcn = 1000; // Start high for channels without LCN
    print('LiveTvRepository: Merging premium data into ${channelMap.length} existing channels...');
    
    premiumJson.forEach((groupName, channelsMap) {
      if (channelsMap is! Map<String, dynamic>) {
        print('LiveTvRepository: Invalid group data for $groupName: ${channelsMap.runtimeType}');
        return;
      }
      
      final titleCaseGroup = groupName[0].toUpperCase() + groupName.substring(1).toLowerCase();
      print('LiveTvRepository: Processing group $groupName ($titleCaseGroup) with ${channelsMap.length} channels');
      
      channelsMap.forEach((channelName, linksDataList) {
        if (linksDataList is! List) return;
        
        // final normalizedName = _normalize(channelName); // No longer needed
        // final existing = nameLookup[normalizedName]; // No longer needed

        final List<StreamLink> newLinks = linksDataList
            .map((l) => StreamLink.fromJson(l as Map<String, dynamic>))
            .toList();

        // Always add as a new channel to keep DTT and Premium separate as requested
        final channel = Channel(
          lcn: syntheticLcn, 
          name: channelName,
          logo: (linksDataList.first as Map<String, dynamic>)['logo'] as String? ?? '',
          links: newLinks,
          group: titleCaseGroup,
        );
        
        channelMap[syntheticLcn++] = channel;
      });
    });
    
    print('LiveTvRepository: Merge complete. Total channels: ${channelMap.length}');
  }

  List<StreamLink> _mergeLinks(List<StreamLink> existing, List<StreamLink> newcomers) {
    return [
      ...existing,
      ...newcomers,
    ];
  }

  /// CDN hosts that require specific HTTP headers. 
  /// Previously we blocked these, but now we handle them in LiveTvSourceHandler.
  static bool _isMpvIncompatible(String url) => false;

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
