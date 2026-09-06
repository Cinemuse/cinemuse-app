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
      if (customPlaylists == null || customPlaylists.isEmpty) {
        return [];
      }

      final Map<String, Channel> channelsByKey = {};
      final List<String> channelOrder = [];
      int syntheticLcn = 2000;

      for (final playlist in customPlaylists) {
        try {
          final content = await _loadPlaylistContent(playlist);
          if (content.isEmpty) continue;

          final playlistChannels = _parsePlaylistChannels(
            playlist,
            content,
            syntheticLcn,
          );

          for (final ch in playlistChannels) {
            final key = _buildChannelKey(ch.epgId, ch.name);
            if (channelsByKey.containsKey(key)) {
              final existing = channelsByKey[key]!;
              final mergedLinks = _mergeStreamLinks(existing.links, ch.links);
              channelsByKey[key] = existing.copyWith(
                links: mergedLinks,
                logo: existing.logo.isNotEmpty ? existing.logo : ch.logo,
                group: existing.group ?? ch.group,
                epgId: existing.epgId ?? ch.epgId,
                provider: existing.provider ?? ch.provider,
                subProvider: existing.subProvider ?? ch.subProvider,
              );
            } else {
              final lcn = ch.lcn > 0 ? ch.lcn : syntheticLcn++;
              channelsByKey[key] = ch.copyWith(lcn: lcn);
              channelOrder.add(key);
            }
          }
        } catch (_) {
          // Skip failed playlists gracefully
        }
      }

      final channels = channelOrder.map((k) => channelsByKey[k]!).toList();
      _sortChannels(channels);
      return channels;
    } catch (e) {
      rethrow;
    }
  }

  Future<String> _loadPlaylistContent(LiveTvPlaylist playlist) async {
    if (playlist.isLocal) {
      return File(playlist.urlOrPath).readAsString();
    }
    final response = await _dio.get(playlist.urlOrPath);
    return response.data is String
        ? response.data as String
        : json.encode(response.data);
  }

  List<Channel> _parsePlaylistChannels(
    LiveTvPlaylist playlist,
    String content,
    int startLcn,
  ) {
    if (playlist.type == PlaylistType.m3u) {
      return M3uParser.parse(content, startLcn: startLcn);
    }
    return _parseJsonChannels(content, playlist.name, startLcn);
  }

  List<Channel> _parseJsonChannels(
    String content,
    String fallbackGroup,
    int startLcn,
  ) {
    final dynamic jsonData = json.decode(content);
    List<dynamic> channelsList = [];

    if (jsonData is List) {
      channelsList = jsonData;
    } else if (jsonData is Map && jsonData.containsKey('channels')) {
      channelsList = jsonData['channels'] as List<dynamic>;
    }

    int currentLcn = startLcn;
    final List<Channel> result = [];

    for (final entry in channelsList) {
      if (entry is! Map<String, dynamic>) continue;

      final links = entry['links'] as List<dynamic>?;
      if (links == null || links.isEmpty) continue;

      final streamLinks = links
          .map((l) => StreamLink.fromJson(l as Map<String, dynamic>))
          .toList();

      result.add(
        Channel(
          lcn: (entry['lcn'] as int?) ?? currentLcn++,
          name: (entry['name'] as String?) ?? 'Unknown',
          logo: (entry['logo'] as String?) ?? '',
          links: streamLinks,
          group: (entry['group'] ?? entry['category']) as String? ?? fallbackGroup,
          provider: entry['provider'] as String?,
          subProvider: entry['sub_provider'] as String?,
          epgId: entry['epg_id'] as String?,
        ),
      );
    }
    return result;
  }

  List<StreamLink> _mergeStreamLinks(
    List<StreamLink> existing,
    List<StreamLink> incoming,
  ) {
    final combined = List<StreamLink>.from(existing);
    for (final link in incoming) {
      if (!combined.any((l) => l.url == link.url)) {
        combined.add(link);
      }
    }
    return combined;
  }

  String _buildChannelKey(String? epgId, String name) {
    if (epgId != null && epgId.trim().isNotEmpty) {
      return 'epg:${epgId.trim().toLowerCase()}';
    }
    final normalized = name
        .toLowerCase()
        .replaceAll(RegExp(r'\b(fhd|uhd|hd|sd|4k|1080p|720p)\b'), '')
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return 'name:$normalized';
  }

  void _sortChannels(List<Channel> channels) {
    channels.sort((a, b) {
      if (a.lcn > 0 && b.lcn > 0) return a.lcn.compareTo(b.lcn);
      if (a.lcn > 0) return -1;
      if (b.lcn > 0) return 1;
      return a.name.compareTo(b.name);
    });
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
