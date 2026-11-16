import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/live_tv_source.dart';
import 'package:cinemuse_app/features/live_tv/domain/epg_program.dart';
import 'package:cinemuse_app/features/live_tv/domain/stream_link.dart';
import 'package:cinemuse_app/features/live_tv/domain/live_tv_guide.dart';
import 'package:cinemuse_app/features/live_tv/domain/live_tv_playlist.dart';
import 'package:cinemuse_app/features/live_tv/data/local_playlist_storage.dart';
import 'package:cinemuse_app/features/live_tv/data/m3u_parser.dart';
import 'package:cinemuse_app/features/live_tv/data/playlist_copy_storage.dart';
import 'package:cinemuse_app/features/live_tv/data/epg_parser.dart';
import 'package:cinemuse_app/features/live_tv/data/epg_storage_service.dart';

/// One guide's programmes, and why it failed if it did.
typedef _GuideResult = ({
  Map<String, List<EpgProgram>> programs,
  LiveTvSourceFailure? failure,
});

class LiveTvRepository {
  static const _tag = 'LiveTvRepository';

  final Dio _dio;
  final EpgStorageService _epgStorage;
  final PlaylistCopyStorage _playlistCopies;

  LiveTvRepository(
    this._dio, {
    EpgStorageService? epgStorage,
    PlaylistCopyStorage? playlistCopies,
  }) : _epgStorage = epgStorage ?? EpgStorageService(),
       _playlistCopies = playlistCopies ?? PlaylistCopyStorage();

  /// The playable channels of [playlists], and the playlists that failed:
  /// a download error, or no channel in it. A downloaded playlist that fails
  /// shows the channels of its saved copy.
  Future<LiveTvLoad<List<Channel>>> fetchChannels({
    List<LiveTvPlaylist>? playlists,
  }) async {
    if (playlists == null || playlists.isEmpty) {
      return const LiveTvLoad([]);
    }

    final Map<String, Channel> channelsByKey = {};
    final List<String> channelOrder = [];
    final failures = <String, LiveTvSourceFailure>{};
    int syntheticLcn = 2000;

    // Downloaded at the same time, so one slow server doesn't hold up the
    // others (REV-117); parsed and merged in order below.
    final downloads = await Future.wait(playlists.map(_tryLoadContent));

    for (var i = 0; i < playlists.length; i++) {
      final playlist = playlists[i];
      final (:text, :failure) = downloads[i];
      var playlistChannels = text == null
          ? const <Channel>[]
          : await _tryParsePlaylist(playlist, text, syntheticLcn);
      if (playlistChannels.isEmpty) {
        playlistChannels = await _savedCopyChannels(playlist, syntheticLcn);
        failures[playlist.id] = LiveTvSourceFailure(
          failure ?? const ValidationFailure('The playlist has no channels'),
          usesSavedCopy: playlistChannels.isNotEmpty,
        );
        if (playlistChannels.isEmpty) continue;
      } else if (!playlist.isLocal) {
        await _playlistCopies.save(playlist.id, playlist.urlOrPath, text!);
      }

      // The next playlist's numbers carry on after this one's, so two
      // playlists never share numbers (REV-113).
      for (final ch in playlistChannels) {
        if (ch.lcn >= syntheticLcn) syntheticLcn = ch.lcn + 1;
      }

      for (final ch in playlistChannels) {
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
    }

    final channels = channelOrder.map((k) => channelsByKey[k]!).toList();
    _sortChannels(channels);
    return LiveTvLoad(channels, failures: failures);
  }

  /// The playlist's text, or the failure that stopped the download. Caught
  /// here, so one broken playlist doesn't hide the channels of the others.
  Future<({String? text, AppFailure? failure})> _tryLoadContent(
    LiveTvPlaylist playlist,
  ) async {
    try {
      return (text: await _loadPlaylistContent(playlist), failure: null);
    } catch (e, s) {
      _logSkipped(playlist, e, s);
      return (text: null, failure: _downloadFailure(e, s));
    }
  }

  /// The playlist's channels; none when [text] isn't a playlist.
  static Future<List<Channel>> _tryParsePlaylist(
    LiveTvPlaylist playlist,
    String text,
    int startLcn,
  ) async {
    try {
      return await _parsePlaylistChannels(
        playlist.type,
        playlist.name,
        text,
        startLcn,
      );
    } catch (e, s) {
      _logSkipped(playlist, e, s);
      return const [];
    }
  }

  /// The channels of the last good download; none for a local file, which
  /// is already on the device.
  Future<List<Channel>> _savedCopyChannels(
    LiveTvPlaylist playlist,
    int startLcn,
  ) async {
    if (playlist.isLocal) return const [];
    final copy = await _playlistCopies.load(
      playlist.id,
      url: playlist.urlOrPath,
    );
    if (copy == null) return const [];
    return _tryParsePlaylist(playlist, copy, startLcn);
  }

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
      // Looked up here, so a folder that can't be found fails this playlist
      // alone.
      final path = await LocalPlaylistStorage.resolveToAbsolutePath(
        playlist.urlOrPath,
      );
      return _decodeText(await File(path).readAsBytes());
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

  /// The programmes of all [guides], each from its cache unless
  /// [forceRefresh] is true, and the guides that failed. When two guides
  /// know the same channel, the one first in the list wins.
  Future<LiveTvLoad<Map<String, List<EpgProgram>>>> fetchEpg({
    required List<LiveTvGuide> guides,
    bool forceRefresh = false,
  }) async {
    // Downloaded at the same time, so one slow server doesn't hold up the
    // others; merged in order below.
    final all = await Future.wait(
      guides.map((g) => _fetchGuide(g, forceRefresh: forceRefresh)),
    );
    final merged = <String, List<EpgProgram>>{};
    for (final (:programs, failure: _) in all) {
      for (final entry in programs.entries) {
        merged.putIfAbsent(entry.key, () => entry.value);
      }
    }
    return LiveTvLoad(
      merged,
      failures: {
        for (var i = 0; i < guides.length; i++) guides[i].id: ?all[i].failure,
      },
    );
  }

  Future<_GuideResult> _fetchGuide(
    LiveTvGuide guide, {
    required bool forceRefresh,
  }) async {
    if (!forceRefresh) {
      final cached = await _epgStorage.loadCachedEpg(
        guide.id,
        expectedUrl: guide.urlOrPath,
      );
      if (cached != null && cached.isNotEmpty) {
        return (programs: cached, failure: null);
      }
    }

    final List<int>? bytes;
    try {
      bytes = await _loadGuideBytes(guide);
    } catch (e, s) {
      // The URL is not logged: a guide's URL can contain credentials.
      AppLogger.warn(
        _tag,
        'Could not load the EPG, using the old cache if there is one',
        error: _describeError(e),
        stackTrace: s,
      );
      return _savedCopyAfter(guide, _downloadFailure(e, s));
    }

    final epgData = await _tryParseEpg(bytes);
    if (epgData.isEmpty) {
      // E.g. an HTML error page: keep showing the old guide (REV-124).
      AppLogger.warn(_tag, 'The EPG download has no programs');
      return _savedCopyAfter(
        guide,
        const ValidationFailure('The guide has no programmes'),
      );
    }
    await _epgStorage.saveCachedEpg(guide.id, guide.urlOrPath, epgData);
    return (programs: epgData, failure: null);
  }

  /// After [failure], the guide's saved copy if there is one.
  Future<_GuideResult> _savedCopyAfter(
    LiveTvGuide guide,
    AppFailure failure,
  ) async {
    final old = await _loadOldEpg(guide) ?? const <String, List<EpgProgram>>{};
    return (
      programs: old,
      failure: LiveTvSourceFailure(failure, usesSavedCopy: old.isNotEmpty),
    );
  }

  /// The guide's programmes; none when [bytes] isn't a guide.
  static Future<Map<String, List<EpgProgram>>> _tryParseEpg(
    List<int>? bytes,
  ) async {
    if (bytes == null || bytes.isEmpty) return const {};
    try {
      return await _parseEpg(bytes);
    } catch (e, s) {
      AppLogger.warn(
        _tag,
        'Could not read the EPG',
        error: _describeError(e),
        stackTrace: s,
      );
      return const {};
    }
  }

  Future<List<int>?> _loadGuideBytes(LiveTvGuide guide) async {
    if (guide.isLocal) {
      final path = await LocalPlaylistStorage.resolveToAbsolutePath(
        guide.urlOrPath,
      );
      return File(path).readAsBytes();
    }
    final response = await _dio.get<List<int>>(
      guide.urlOrPath,
      options: Options(
        responseType: ResponseType.bytes,
        headers: {'Accept': 'application/json, application/xml, text/xml, */*'},
      ),
    );
    return response.data;
  }

  /// The cached guide even if expired, up to a week old.
  Future<Map<String, List<EpgProgram>>?> _loadOldEpg(LiveTvGuide guide) {
    return _epgStorage.loadCachedEpg(
      guide.id,
      expectedUrl: guide.urlOrPath,
      ttl: const Duration(days: 7),
    );
  }

  /// A guide can be 100 MB, so it is parsed on a background isolate to keep
  /// the UI responsive (PERF-01).
  static Future<Map<String, List<EpgProgram>>> _parseEpg(List<int> bytes) {
    final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    return Isolate.run(() => EpgParser.parseBytes(data));
  }

  /// A failed download as an [AppFailure]. The library error is not kept as
  /// its cause: it holds the URL, which can contain credentials.
  static AppFailure _downloadFailure(Object e, StackTrace s) {
    final message = 'Download failed: ${_describeError(e)}';
    return switch (e) {
      DioException(type: DioExceptionType.badResponse, :final response) =>
        ServerFailure(message, statusCode: response?.statusCode, stackTrace: s),
      DioException() => NetworkFailure(message, stackTrace: s),
      FileSystemException() => NotFoundFailure(message, stackTrace: s),
      _ => UnknownFailure(message, stackTrace: s),
    };
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
