import 'dart:async';
import 'dart:convert';

import 'package:cinemuse_app/core/data/database.dart';
import 'package:cinemuse_app/core/network/network_providers.dart';
import 'package:cinemuse_app/core/services/system/supabase_service.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:cinemuse_app/features/streaming/anime/models/anime_match.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final animeMappingServiceProvider = Provider((ref) {
  final client = ref.read(supabaseClientProvider);
  return AnimeMappingService(
    ref.read(dioProvider),
    ref.read(appDatabaseProvider),
    url: '${SupabaseConfig.url}/functions/v1/anime-mapping',
    apiKey: SupabaseConfig.publishableKey,
    accessToken: () => client.auth.currentSession?.accessToken,
  );
});

/// Finds which anime a TMDB title or episode is. The `anime-mapping` server
/// function answers; when it can't be reached, the app's copy of the list
/// answers with the server's rule (`supabase/functions/anime-mapping/
/// lookup.ts`), and `known_cases.json` keeps the two the same.
class AnimeMappingService {
  static const String _logTag = 'AnimeMappingService';

  final Dio _dio;
  final AppDatabase _db;
  final String _url;
  final String _apiKey;
  final String? Function() _accessToken;

  /// Past this the copy answers instead: playing waits on it.
  final Duration _serverTimeout;

  AnimeMappingService(
    this._dio,
    this._db, {
    required String url,
    required String apiKey,
    required String? Function() accessToken,
    Duration serverTimeout = const Duration(seconds: 4),
  }) : _url = url,
       _apiKey = apiKey,
       _accessToken = accessToken,
       _serverTimeout = serverTimeout;

  Future<AnimeLookup> lookUp({
    required int tmdbId,
    required String type,
    int? season,
    int? episode,
  }) async {
    try {
      return await _askServer(tmdbId, type, season, episode);
    } catch (e) {
      AppLogger.warn(
        _logTag,
        'Server not reached for $type $tmdbId, the copy answers',
        error: e,
      );
    }
    return _pickFromCopy(tmdbId, type, season, episode);
  }

  Future<AnimeLookup> _askServer(
    int tmdbId,
    String type,
    int? season,
    int? episode,
  ) async {
    // Only signed-in users may ask.
    final token = _accessToken();
    if (token == null) throw StateError('Not signed in');

    final response = await _dio
        .get<Map<String, dynamic>>(
          _url,
          queryParameters: {
            'tmdb_id': tmdbId,
            'type': type,
            'season': ?season,
            'episode': ?episode,
          },
          options: Options(
            headers: {'apikey': _apiKey, 'Authorization': 'Bearer $token'},
          ),
        )
        .timeout(_serverTimeout);
    final body = response.data;
    if (response.statusCode != 200 || body == null) {
      throw StateError('Status ${response.statusCode}');
    }

    final match = body['match'];
    final lookup = AnimeLookup(
      isAnime: body['is_anime'] as bool,
      match: match is Map<String, dynamic> ? AnimeMatch.fromJson(match) : null,
    );
    _logAnswer('server', tmdbId, season, episode, lookup);
    return lookup;
  }

  /// The server's rule: the first line, by AniList id, whose TMDB episodes
  /// cover the episode. Nothing is worked out: when no line covers it there
  /// is no match, as a wrong episode is worse than none (REV-233, REV-294);
  /// the sources then search by IMDb id.
  Future<AnimeLookup> _pickFromCopy(
    int tmdbId,
    String type,
    int? season,
    int? episode,
  ) async {
    final lines = type == 'movie'
        ? await _db.getAnimeMappingsByTmdbMovie(tmdbId)
        : await _db.getAnimeMappingsByTmdbShow(tmdbId);
    if (lines.isEmpty) return AnimeLookup.notAnime;

    final lookup = AnimeLookup(
      isAnime: true,
      match: _pickMatch(lines, type, season, episode),
    );
    _logAnswer('copy', tmdbId, season, episode, lookup);
    return lookup;
  }

  AnimeMatch? _pickMatch(
    List<AnimeExternalMapping> lines,
    String type,
    int? season,
    int? episode,
  ) {
    // A film (or a show with no episode picked) has no episode to get wrong.
    if (type == 'movie' || season == null || episode == null) {
      return _match(lines.first);
    }

    for (final line in lines) {
      final pieces = line.tmdbEpisodes == null
          ? const []
          : jsonDecode(line.tmdbEpisodes!) as List;
      for (final piece in pieces.cast<Map<String, dynamic>>()) {
        final first = piece['first'] as int;
        final last = piece['last'] as int?;
        if (piece['season'] == season &&
            episode >= first &&
            (last == null || episode <= last)) {
          return _match(
            line,
            episode: episode - first + (piece['anime_first'] as int),
          );
        }
      }
    }
    return null;
  }

  AnimeMatch _match(AnimeExternalMapping line, {int? episode}) => AnimeMatch(
    anilistId: line.anilistId,
    anidbId: line.anidbId,
    kitsuId: line.kitsuId?.toString(),
    absoluteEpisode: episode,
  );

  void _logAnswer(
    String from,
    int tmdbId,
    int? season,
    int? episode,
    AnimeLookup lookup,
  ) {
    final match = lookup.match;
    AppLogger.debug(
      _logTag,
      'TMDB $tmdbId S${season ?? '-'} E${episode ?? '-'} ($from): '
      '${match == null ? 'no match, anime: ${lookup.isAnime}' : 'AniList ${match.anilistId} ep ${match.absoluteEpisode ?? '-'}'}',
    );
  }
}
