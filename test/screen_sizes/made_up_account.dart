import 'package:cinemuse_app/core/data/api_keys_repository.dart';
import 'package:cinemuse_app/core/data/server_addresses_model.dart';
import 'package:cinemuse_app/core/data/server_addresses_repository.dart';
import 'package:cinemuse_app/core/network/network_providers.dart';
import 'package:cinemuse_app/core/services/system/connectivity_service.dart';
import 'package:cinemuse_app/features/home/application/home_providers.dart';
import 'package:cinemuse_app/features/home/domain/sport_tv_event.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/data/live_tv_repository.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/epg_program.dart';
import 'package:cinemuse_app/features/live_tv/domain/live_tv_guide.dart';
import 'package:cinemuse_app/features/live_tv/domain/live_tv_playlist.dart';
import 'package:cinemuse_app/features/live_tv/domain/live_tv_source.dart';
import 'package:cinemuse_app/features/live_tv/domain/stream_link.dart';
import 'package:cinemuse_app/features/media/application/watch_history_store.dart';
import 'package:cinemuse_app/features/media/data/media_repository.dart';
import 'package:cinemuse_app/features/media/data/own_reviews_repository.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/media/data/watch_logs_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/profile/application/agenda_providers.dart';
import 'package:cinemuse_app/features/profile/application/profile_providers.dart';
import 'package:cinemuse_app/features/profile/domain/agenda_event.dart';
import 'package:cinemuse_app/features/profile/domain/profile_stats.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/settings/domain/user_settings.dart';
import 'package:cinemuse_app/features/streaming/anime/anime_mapping_sync_service.dart';
import 'package:cinemuse_app/features/streaming/unified_stream_resolver.dart';
import 'package:cinemuse_app/features/streaming/unified_stream_resolver_provider.dart';
import 'package:cinemuse_app/features/updates/application/update_service.dart';
import 'package:cinemuse_app/features/updates/domain/update_state.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/offline_lists.dart';
import '../helpers/override_helpers.dart';
import 'made_up_player.dart';
import 'made_up_tmdb.dart';

/// A signed-in account with made-up titles, history, channels and guide, so
/// every screen has content to show. Nothing reaches the internet.
List<Override> madeUpAccountOverrides() => withOwnOverrides(
  offlineListsOverrides(),
  [
    connectivityProvider.overrideWith(
      (ref) => Stream.value(ConnectivityResult.wifi),
    ),
    dioProvider.overrideWithValue(
      Dio()..httpClientAdapter = MadeUpTmdbAdapter(),
    ),
    tmdbApiKeyProvider.overrideWith((ref) async => 'made-up'),
    settingsProvider.overrideWith(_DefaultSettings.new),
    updateProvider.overrideWith(_NoUpdateCheck.new),
    animeMappingSyncServiceProvider.overrideWithValue(_NoAnimeSync()),
    serverAddressesProvider.overrideWith((ref) async => ServerAddresses.empty),
    sportScheduleProvider.overrideWith((ref) async => _sportEvents()),
    watchHistoryStoreProvider.overrideWith(
      (ref) => Stream.value({for (final h in _history()) h.titleKey: h}),
    ),
    watchHistoryStreamProvider.overrideWith((ref) => Stream.value(_history())),
    watchLogsProvider.overrideWith((ref) async => _history()),
    profileStatsProvider.overrideWith((ref) => Stream.value(_stats())),
    agendaProvider.overrideWith((ref) async => _agenda()),
    cinemusePlaylistUrlProvider.overrideWithValue(
      'https://made-up.invalid/playlist.m3u',
    ),
    cinemuseGuideUrlProvider.overrideWithValue(
      'https://made-up.invalid/epg.json',
    ),
    liveTvRepositoryProvider.overrideWithValue(_MadeUpLiveTv()),
    mediaRepositoryProvider.overrideWithValue(_titleCache()),
    watchHistoryRepositoryProvider.overrideWithValue(_historyRepository()),
    watchLogsRepositoryProvider.overrideWithValue(_watchLogs()),
    ownReviewsRepositoryProvider.overrideWithValue(_ownReviews()),
    unifiedStreamResolverProvider.overrideWithValue(_streamResolver()),
    madeUpPlayerOverride(),
  ],
);

class _MockMediaRepository extends Mock implements MediaRepository {}

class _MockWatchLogsRepository extends Mock implements WatchLogsRepository {}

class _MockWatchHistoryRepository extends Mock
    implements WatchHistoryRepository {}

class _MockOwnReviewsRepository extends Mock implements OwnReviewsRepository {}

class _MockStreamResolver extends Mock implements UnifiedStreamResolver {}

/// The device's copy of titles: empty, and saving to it works.
MediaRepository _titleCache() {
  registerFallbackValue(_item(0, MediaKind.movie));
  final cache = _MockMediaRepository();
  when(() => cache.getMediaItem(any(), any())).thenAnswer((_) async => null);
  when(() => cache.saveMediaItem(any())).thenAnswer((_) async {});
  return cache;
}

/// [_history], and a series' own history: up to its 7th episode of season 2.
WatchHistoryRepository _historyRepository() {
  final history = _MockWatchHistoryRepository();
  when(() => history.getDroppedItems(any())).thenAnswer((_) async => []);
  when(
    () => history.watchHistory(any()),
  ).thenAnswer((_) => Stream.value(_history()));
  when(() => history.watchSeriesHistory(any(), any())).thenAnswer(
    (invocation) => Stream.value([
      for (final h in _history())
        if (h.tmdbId == invocation.positionalArguments[1]) h,
    ]),
  );
  return history;
}

/// Each finished film watched twice; the history's titles.
WatchLogsRepository _watchLogs() {
  final logs = _MockWatchLogsRepository();
  when(() => logs.watchTitleLogs(any(), any(), any())).thenAnswer(
    (_) => Stream.value([
      for (var i = 1; i <= 2; i++)
        {'logged_at': _now.subtract(Duration(days: 30 * i)).toIso8601String()},
    ]),
  );
  when(() => logs.getAllWatchLogs(any())).thenAnswer((_) async => _history());
  when(
    () => logs.getHighestLoggedEpisode(any(), any()),
  ).thenAnswer((_) async => (season: 2, episode: 6));
  return logs;
}

/// No ratings of the user's own.
OwnReviewsRepository _ownReviews() {
  final reviews = _MockOwnReviewsRepository();
  registerFallbackValue((tmdbId: 0, mediaType: MediaKind.movie));
  when(() => reviews.getAll(any())).thenAnswer((_) async => []);
  when(() => reviews.get(any(), any())).thenAnswer((_) async => null);
  return reviews;
}

/// No stream found ahead of time: the Play buttons show as before a search.
UnifiedStreamResolver _streamResolver() {
  final resolver = _MockStreamResolver();
  when(
    () => resolver.hasCachedStream(
      any(),
      any(),
      season: any(named: 'season'),
      episode: any(named: 'episode'),
    ),
  ).thenReturn(false);
  return resolver;
}

class _DefaultSettings extends SettingsNotifier {
  @override
  UserSettings build() => const UserSettings();
}

class _NoUpdateCheck extends UpdateNotifier {
  @override
  UpdateState build() => UpdateState(status: UpdateStatus.upToDate);

  @override
  Future<void> checkForUpdates() async {}
}

class _NoAnimeSync implements AnimeMappingSyncService {
  @override
  Future<void> checkAndSync() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _now = DateTime.now();

List<SportTvEvent> _sportEvents() => [
  for (final (sport, what) in [
    ('Calcio', 'Serie A: Internazionale Milano - Associazione Sportiva Roma'),
    ('Tennis', 'ATP Finals Torino: semifinale di singolare maschile'),
    ('Formula 1', 'Gran Premio di San Paolo del Brasile: qualifiche'),
    ('Pallavolo', 'SuperLega Credem Banca: Itas Trentino - Sir Perugia'),
  ])
    SportTvEvent(
      dateTime: _now.add(const Duration(hours: 2)),
      sportName: sport,
      description: what,
      channels: ['Sky Sport Uno', 'Sky Sport 251', 'NOW', 'DAZN'],
    ),
];

MediaItem _item(int id, MediaKind kind) => MediaItem.fromTmdbMap({
  'id': id,
  'media_type': kind == MediaKind.movie ? 'movie' : 'tv',
  if (kind == MediaKind.movie) 'title': filmTitle else 'name': seriesTitle,
  'poster_path': '/poster$id.jpg',
  'backdrop_path': '/backdrop$id.jpg',
  'release_date': '2024-03-15',
  'vote_average': 7.8,
});

/// Half-watched films and series (Continue Watching) and finished ones.
List<WatchHistory> _history() => [
  for (var i = 0; i < 6; i++) ...[
    WatchHistory(
      userId: 'user-a',
      tmdbId: filmId + i,
      mediaType: MediaKind.movie,
      status: i < 3 ? WatchStatus.watching : WatchStatus.completed,
      progressSeconds: 3000,
      totalDuration: 8520,
      watchCount: i < 3 ? 0 : 2,
      lastWatchedAt: _now.subtract(Duration(hours: i * 5)),
      media: _item(filmId + i, MediaKind.movie),
    ),
    WatchHistory(
      userId: 'user-a',
      tmdbId: seriesId + i,
      mediaType: MediaKind.tv,
      status: WatchStatus.watching,
      progressSeconds: 1200,
      totalDuration: 3120,
      lastWatchedAt: _now.subtract(Duration(hours: i * 5 + 2)),
      season: 2,
      episode: 7,
      media: _item(seriesId + i, MediaKind.tv),
    ),
  ],
];

/// The size of the busiest real account (about 260 days watched).
ProfileStats _stats() {
  PeriodStats period(int scale) => PeriodStats(
    totalMinutes: 1234 * scale,
    movieCount: 4 * scale,
    episodeCount: 30 * scale,
  );
  return ProfileStats(
    totalMinutesWatched: 380000,
    totalEpisodes: 7200,
    totalMovies: 400,
    totalSeries: 310,
    totalSeasons: 820,
    last7Days: period(1),
    last30Days: period(4),
    last365Days: period(40),
    movieMinutes: 100000,
    seriesMinutes: 280000,
  );
}

GroupedAgenda _agenda() {
  AgendaEvent event(int i, DateTime when) => AgendaEvent(
    id: 'tv_${seriesId + i}_$i',
    tmdbId: seriesId + i,
    title: seriesTitle,
    episodeName: episodeTitle,
    releaseDate: when,
    type: MediaKind.tv,
    seasonNumber: 3,
    episodeNumber: 11 + i,
    posterPath: '/poster$i.jpg',
  );
  return {
    AgendaGroup.recentlyReleased: [
      for (var i = 0; i < 3; i++) event(i, _now.subtract(Duration(days: i))),
    ],
    AgendaGroup.today: [event(3, _now)],
    AgendaGroup.tomorrow: [event(4, _now.add(const Duration(days: 1)))],
    AgendaGroup.later: [
      for (var i = 5; i < 9; i++) event(i, _now.add(Duration(days: i * 9))),
    ],
  };
}

const _channelNames = [
  'Rai 1',
  'Rai 2',
  'Rai 3 TGR Friuli Venezia Giulia',
  'Rete 4',
  'Canale 5',
  'Italia 1',
  'La7',
  'TV8',
  'Nove',
  'Rai 4K Ultra HD',
  'Rai Movie',
  'Rai Premium',
  'Mediaset Extra',
  'Real Time',
  'DMAX',
  'Rai News 24',
  'Sky TG24',
  'Radio Italia Solo Musica Italiana',
];

List<Channel> _channels() => [
  for (final (i, name) in _channelNames.indexed)
    Channel(
      lcn: i + 1,
      name: name,
      logo: '',
      group: i < 9 ? 'Generalisti' : 'Approfondimento e intrattenimento',
      epgId: 'ch$i',
      links: [
        StreamLink(
          url: 'https://made-up.invalid/$i.m3u8',
          quality: StreamQuality.values.last,
        ),
      ],
    ),
];

/// Two days of long programmes for every channel, from yesterday.
Map<String, List<EpgProgram>> _guide() {
  final start = DateTime(_now.year, _now.month, _now.day - 1);
  return {
    for (var c = 0; c < _channelNames.length; c++)
      'ch$c': [
        for (var h = 0; h < 48; h++)
          EpgProgram(
            name: h.isEven
                ? 'Il commissario Montalbano: la voce del violino'
                : 'Telegiornale della sera con approfondimenti',
            subtitle: 'Stagione 4 Episodio 2',
            description:
                'Il commissario indaga su un delitto misterioso in una villa '
                'appena restaurata, mentre la sua vita privata si complica.',
            startTime: start.add(Duration(hours: h)),
            endTime: start.add(Duration(hours: h + 1)),
          ),
      ],
  };
}

class _MadeUpLiveTv extends LiveTvRepository {
  _MadeUpLiveTv() : super(Dio());

  @override
  Future<LiveTvLoad<List<Channel>>> fetchChannels({
    List<LiveTvPlaylist>? playlists,
  }) async => LiveTvLoad(_channels());

  @override
  Future<LiveTvLoad<Map<String, List<EpgProgram>>>> fetchEpg({
    required List<LiveTvGuide> guides,
    bool forceRefresh = false,
  }) async => LiveTvLoad(_guide());
}
