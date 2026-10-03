import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/epg_program.dart';
import 'package:cinemuse_app/features/live_tv/domain/stream_link.dart';
import 'package:cinemuse_app/features/live_tv/domain/live_tv_playlist.dart';
import 'package:cinemuse_app/features/live_tv/data/m3u_parser.dart';
import 'package:cinemuse_app/features/live_tv/data/epg_parser.dart';
import 'package:cinemuse_app/features/live_tv/data/epg_channel_matcher.dart';
import 'package:cinemuse_app/features/live_tv/data/epg_storage_service.dart';

class LiveTvRepository {
  static const String defaultEpgUrl =
      'https://enfaqgwmuytoxkxgqqvp.supabase.co/functions/v1/live-tv-resolver/epg.json';

  final Dio _dio;
  final EpgStorageService _epgStorage;

  LiveTvRepository(this._dio, {EpgStorageService? epgStorage})
      : _epgStorage = epgStorage ?? EpgStorageService();

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
              final preferredLcn = (existing.lcn > 0 && existing.lcn < 2000)
                  ? existing.lcn
                  : (ch.lcn > 0 && ch.lcn < 2000 ? ch.lcn : existing.lcn);
              channelsByKey[key] = existing.copyWith(
                lcn: preferredLcn,
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

  /// Fetches EPG program guide data from the specified URL or default endpoint.
  /// Automatically checks local cache first unless [forceRefresh] is true.
  Future<Map<String, List<EpgProgram>>> fetchEpg({
    String? url,
    bool forceRefresh = false,
  }) async {
    final effectiveUrl = (url != null && url.trim().isNotEmpty)
        ? url.trim()
        : defaultEpgUrl;

    if (!forceRefresh) {
      final cached = await _epgStorage.loadCachedEpg(expectedUrl: effectiveUrl);
      if (cached != null && cached.isNotEmpty) {
        return cached;
      }
    }

    try {
      final response = await _dio.get<List<int>>(
        effectiveUrl,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            'Accept': 'application/json, application/xml, text/xml, */*',
          },
        ),
      );

      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        return await _epgStorage.loadCachedEpg(
              expectedUrl: effectiveUrl,
              ttl: const Duration(days: 7),
            ) ??
            {};
      }

      final epgData = EpgParser.parseBytes(Uint8List.fromList(bytes));
      if (epgData.isNotEmpty) {
        await _epgStorage.saveCachedEpg(effectiveUrl, epgData);
      }
      return epgData;
    } catch (e) {
      debugPrint('LiveTvRepository: Error fetching EPG from $effectiveUrl: $e');
      // Fallback to expired cache if available
      final fallback = await _epgStorage.loadCachedEpg(
        expectedUrl: effectiveUrl,
        ttl: const Duration(days: 7),
      );
      if (fallback != null) return fallback;
      return {};
    }
  }

  /// Looks up the current and next programs for a given channel using smart matching.
  ({EpgProgram? current, EpgProgram? next}) getProgramsForChannel(
    Channel channel,
    Map<String, List<EpgProgram>> epgData,
  ) {
    return EpgChannelMatcher.getNowAndNext(channel, epgData);
  }

  /// Returns full program schedule for a given channel.
  List<EpgProgram> getChannelSchedule(
    Channel channel,
    Map<String, List<EpgProgram>> epgData,
  ) {
    return EpgChannelMatcher.findPrograms(channel, epgData);
  }
}
