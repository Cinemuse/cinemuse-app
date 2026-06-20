import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/epg_program.dart';
import 'package:cinemuse_app/features/live_tv/domain/stream_link.dart';
import 'package:cinemuse_app/features/live_tv/domain/live_tv_playlist.dart';
import 'package:cinemuse_app/features/live_tv/data/m3u_parser.dart';

class LiveTvRepository {
  final Dio _dio;

  LiveTvRepository(this._dio);

  /// Fetches the channel list, filtering to only playable channels.
  Future<List<Channel>> fetchChannels({
    List<LiveTvPlaylist>? customPlaylists,
  }) async {
    try {
      final Map<int, Channel> channelMap = {};

      // ── Load & Merge Custom Playlists ──
      try {
        if (customPlaylists != null) {
          int syntheticLcn = 2000;
          for (final playlist in customPlaylists) {
            String content = '';
            try {
              if (playlist.isLocal) {
                content = await File(playlist.urlOrPath).readAsString();
              } else {
                final response = await _dio.get(playlist.urlOrPath);
                content = response.data is String
                    ? response.data as String
                    : json.encode(response.data);
              }

              if (playlist.type == PlaylistType.m3u) {
                final m3uChannels = M3uParser.parse(
                  content,
                  startLcn: syntheticLcn,
                );
                for (final ch in m3uChannels) {
                  // Ensure we don't overwrite existing LCNs
                  while (channelMap.containsKey(syntheticLcn)) {
                    syntheticLcn++;
                  }
                  channelMap[syntheticLcn] = Channel(
                    lcn: syntheticLcn,
                    name: ch.name,
                    logo: ch.logo,
                    group: ch.group ?? playlist.name,
                    epgId: ch.epgId,
                    links: ch.links,
                  );
                  syntheticLcn++;
                }
              } else if (playlist.type == PlaylistType.json) {
                final dynamic jsonData = json.decode(content);
                List<dynamic> channelsList = [];

                // Handle both array format and standard object format
                if (jsonData is List) {
                  channelsList = jsonData;
                } else if (jsonData is Map &&
                    jsonData.containsKey('channels')) {
                  channelsList = jsonData['channels'] as List<dynamic>;
                }

                for (final entry in channelsList) {
                  if (entry is! Map<String, dynamic>) continue;

                  final links = entry['links'] as List<dynamic>?;
                  if (links == null || links.isEmpty) continue;

                  final streamLinks = links
                      .map(
                        (l) => StreamLink.fromJson(l as Map<String, dynamic>),
                      )
                      .toList();

                  while (channelMap.containsKey(syntheticLcn)) {
                    syntheticLcn++;
                  }

                  channelMap[syntheticLcn] = Channel(
                    lcn: syntheticLcn,
                    name: (entry['name'] as String?) ?? 'Unknown',
                    logo: (entry['logo'] as String?) ?? '',
                    links: streamLinks,
                    group:
                        (entry['group'] ?? entry['category']) as String? ??
                        playlist.name,
                    provider: entry['provider'] as String?,
                    subProvider: entry['sub_provider'] as String?,
                    epgId: entry['epg_id'] as String?,
                  );
                  syntheticLcn++;
                }
              }
            } catch (e) {
              // Skip failed playlists
            }
          }
        }
      } catch (e) {
        // Log but don't crash
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

  /// Fetches the EPG data.
  ///
  /// Returns a map: `{ "source": { "channelId": [EpgProgram, ...] } }`
  Future<Map<String, Map<String, List<EpgProgram>>>> fetchEpg() async {
    return {};
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
    if (programs == null || programs.isEmpty) {
      return (current: null, next: null);
    }

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
