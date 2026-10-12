import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/epg_program.dart';
import 'package:cinemuse_app/features/live_tv/domain/stream_link.dart';
import 'package:cinemuse_app/features/live_tv/domain/live_tv_playlist.dart';
import 'package:cinemuse_app/features/live_tv/data/m3u_parser.dart';
import 'package:cinemuse_app/features/live_tv/data/epg_parser.dart';
import 'package:cinemuse_app/features/live_tv/data/epg_storage_service.dart';

class LiveTvRepository {
  static const _tag = 'LiveTvRepository';

  final Dio _dio;
  final EpgStorageService _epgStorage;

  /// The Cinemuse guide, used when the user has no EPG URL of their own.
  final String defaultEpgUrl;

  /// On Windows libmpv's DASH demuxer crashes the app (0xc0000005) on or
  /// after a `.mpd` stream, so those links are dropped there (REV-118,
  /// rechecked 2026-10-12). Remove once this is fixed:
  /// https://github.com/media-kit/media-kit/issues/973
  final bool _isDashSkipped;

  LiveTvRepository(
    this._dio, {
    required this.defaultEpgUrl,
    EpgStorageService? epgStorage,
    bool? isDashSkipped,
  }) : _epgStorage = epgStorage ?? EpgStorageService(),
       _isDashSkipped = isDashSkipped ?? Platform.isWindows;

  /// Fetches the channel list, filtering to only playable channels.
  Future<List<Channel>> fetchChannels({
    List<LiveTvPlaylist>? customPlaylists,
  }) async {
    if (customPlaylists == null || customPlaylists.isEmpty) {
      return [];
    }

    final Map<String, Channel> channelsByKey = {};
    final List<String> channelOrder = [];
    int syntheticLcn = 2000;

    // Downloaded at the same time, so one slow server doesn't hold up the
    // others (REV-117); parsed and merged in order below.
    final contents = await Future.wait(customPlaylists.map(_tryLoadContent));

    for (var i = 0; i < customPlaylists.length; i++) {
      final playlist = customPlaylists[i];
      final content = contents[i];
      if (content == null || content.isEmpty) continue;
      try {
        final playlistChannels = await _parsePlaylistChannels(
          playlist.type,
          playlist.name,
          content,
          syntheticLcn,
        );

        // The next playlist's numbers carry on after this one's, so two
        // playlists never share numbers (REV-113).
        for (final ch in playlistChannels) {
          if (ch.lcn >= syntheticLcn) syntheticLcn = ch.lcn + 1;
        }

        for (final parsed in playlistChannels) {
          final ch = _withoutDashLinks(parsed);
          if (ch.links.isEmpty) continue;
          final key = ch.uniqueId;
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
            );
          } else {
            final lcn = ch.lcn > 0 ? ch.lcn : syntheticLcn++;
            channelsByKey[key] = ch.copyWith(lcn: lcn);
            channelOrder.add(key);
          }
        }
      } catch (e, s) {
        _logSkipped(playlist, e, s);
      }
    }

    final channels = channelOrder.map((k) => channelsByKey[k]!).toList();
    _sortChannels(channels);
    return channels;
  }

  Channel _withoutDashLinks(Channel channel) {
    if (!_isDashSkipped) return channel;
    final links = channel.links.where((l) => !_isDash(l.url)).toList();
    if (links.length == channel.links.length) return channel;
    return channel.copyWith(links: links);
  }

  static bool _isDash(String url) =>
      Uri.tryParse(url)?.path.toLowerCase().endsWith('.mpd') ?? false;

  /// The playlist's text, or `null` when it can't be loaded.
  Future<String?> _tryLoadContent(LiveTvPlaylist playlist) async {
    try {
      return await _loadPlaylistContent(playlist);
    } catch (e, s) {
      _logSkipped(playlist, e, s);
      return null;
    }
  }

  // One broken playlist must not hide the channels of the others.
  static void _logSkipped(LiveTvPlaylist playlist, Object e, StackTrace s) {
    AppLogger.warn(
      _tag,
      'Skipping playlist "${playlist.name}": it could not be loaded',
      error: _describeError(e),
      stackTrace: s,
    );
  }

  Future<String> _loadPlaylistContent(LiveTvPlaylist playlist) async {
    if (playlist.isLocal) {
      return _decodeText(await File(playlist.urlOrPath).readAsBytes());
    }
    final response = await _dio.get(playlist.urlOrPath);
    return response.data is String
        ? response.data as String
        : json.encode(response.data);
  }

  /// UTF-8, or Latin-1 for older files that aren't valid UTF-8; without the
  /// byte-order mark some editors add, which breaks JSON (REV-124).
  static String _decodeText(List<int> bytes) {
    String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      text = latin1.decode(bytes);
    }
    return text.startsWith('\uFEFF') ? text.substring(1) : text;
  }

  /// Parsing a big playlist takes seconds, so it runs on a background
  /// isolate to keep the UI responsive (PERF-01).
  static Future<List<Channel>> _parsePlaylistChannels(
    PlaylistType type,
    String fallbackGroup,
    String content,
    int startLcn,
  ) {
    return Isolate.run(() {
      if (type == PlaylistType.m3u) {
        return M3uParser.parse(content, startLcn: startLcn);
      }
      return _parseJsonChannels(content, fallbackGroup, startLcn);
    });
  }

  static List<Channel> _parseJsonChannels(
    String content,
    String fallbackGroup,
    int startLcn,
  ) {
    final dynamic jsonData = json.decode(content);
    List<dynamic> channelsList = [];

    if (jsonData is List) {
      channelsList = jsonData;
    } else if (jsonData is Map && jsonData['channels'] is List) {
      channelsList = jsonData['channels'] as List<dynamic>;
    }

    int currentLcn = startLcn;
    final List<Channel> result = [];

    // A bad value skips only that link or channel, not the whole playlist
    // (REV-124).
    for (final entry in channelsList) {
      if (entry is! Map<String, dynamic>) continue;
      final links = entry['links'];
      if (links is! List) continue;

      final streamLinks = <StreamLink>[];
      for (final l in links) {
        try {
          streamLinks.add(StreamLink.fromJson(l as Map<String, dynamic>));
        } catch (_) {
          // No URL or a field of the wrong type: skip this link.
        }
      }
      if (streamLinks.isEmpty) continue;

      result.add(
        Channel(
          lcn: _jsonInt(entry['lcn']) ?? currentLcn++,
          name: _jsonText(entry['name']) ?? 'Unknown',
          logo: _jsonText(entry['logo']) ?? '',
          links: streamLinks,
          group:
              _jsonText(entry['group']) ??
              _jsonText(entry['category']) ??
              fallbackGroup,
          provider: _jsonText(entry['provider']),
          epgId: _jsonText(entry['epg_id']),
        ),
      );
    }
    return result;
  }

  /// `5`, `5.0` or `"5"`.
  static int? _jsonInt(Object? value) => switch (value) {
    num() => value.toInt(),
    String() => int.tryParse(value.trim()),
    _ => null,
  };

  static String? _jsonText(Object? value) => switch (value) {
    String() => value,
    num() => value.toString(),
    _ => null,
  };

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
      final epgData = (bytes == null || bytes.isEmpty)
          ? const <String, List<EpgProgram>>{}
          : await _parseEpg(bytes);
      if (epgData.isEmpty) {
        // E.g. an HTML error page: keep showing the old guide (REV-124).
        AppLogger.warn(_tag, 'The EPG download has no programs');
        return await _loadOldEpg(effectiveUrl) ?? {};
      }
      await _epgStorage.saveCachedEpg(effectiveUrl, epgData);
      return epgData;
    } catch (e, s) {
      // The URL is not logged: a custom EPG URL can contain credentials.
      AppLogger.warn(
        _tag,
        'Could not load the EPG, using the old cache if there is one',
        error: _describeError(e),
        stackTrace: s,
      );
      return await _loadOldEpg(effectiveUrl) ?? {};
    }
  }

  /// The cached guide even if expired, up to a week old.
  Future<Map<String, List<EpgProgram>>?> _loadOldEpg(String url) {
    return _epgStorage.loadCachedEpg(
      expectedUrl: url,
      ttl: const Duration(days: 7),
    );
  }

  /// A guide can be 100 MB, so it is parsed on a background isolate to keep
  /// the UI responsive (PERF-01).
  static Future<Map<String, List<EpgProgram>>> _parseEpg(List<int> bytes) {
    final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    return Isolate.run(() => EpgParser.parseBytes(data));
  }

  /// Error text without the request URL, which can contain credentials.
  static String _describeError(Object e) {
    if (e is DioException) {
      final status = e.response?.statusCode;
      return 'DioException ${e.type.name}${status != null ? ' $status' : ''}';
    }
    return e.runtimeType.toString();
  }
}
