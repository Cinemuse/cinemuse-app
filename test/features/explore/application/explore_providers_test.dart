import 'dart:async';

import 'package:cinemuse_app/core/application/l10n_provider.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/error/error_service.dart';
import 'package:cinemuse_app/features/explore/application/explore_providers.dart';
import 'package:cinemuse_app/features/explore/domain/explore_filters.dart';
import 'package:cinemuse_app/features/explore/domain/explore_type.dart';
import 'package:cinemuse_app/features/media/data/tmdb_service.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/person.dart';
import 'package:cinemuse_app/features/media/domain/search_result.dart';
import 'package:cinemuse_app/features/media/domain/watch_provider.dart';
import 'package:cinemuse_app/features/settings/application/watch_region_providers.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/core/application/provider_retry.dart';

/// Page 1 works, later pages fail until [isOnline] is set back to true.
/// While [nextPageGate] is set, later pages wait for it.
class _FlakyTmdbService extends TmdbService {
  _FlakyTmdbService() : super(Dio(), 'en-US', () async => 'test-key');

  bool isOnline = true;
  Completer<void>? nextPageGate;

  @override
  Future<TmdbPage<MediaItem>> discover({
    required String type,
    required int page,
    String? sortBy,
    List<int>? genres,
    List<String>? languages,
    double? minRating,
    double? maxRating,
    int? minYear,
    int? maxYear,
    int? minVotes,
    int? maxVotes,
    int? minRuntime,
    int? maxRuntime,
    List<int>? watchProviders,
    String? watchRegion,
  }) async {
    if (page > 1) await nextPageGate?.future;
    if (page > 1 && !isOnline) {
      throw const NetworkFailure('offline');
    }
    // The title names the genres asked for, so a test can tell pages apart.
    return (
      results: [
        MediaItem.fromTmdbMap({
          'id': page,
          'media_type': type,
          'title': 'Genres $genres',
        }),
      ],
      totalPages: 5,
    );
  }

  @override
  Future<TmdbPage<PersonSummary>> getPopularPersons(int page) async => (
    results: [
      PersonSummary.fromTmdbMap({
        'id': 287,
        'name': 'Brad Pitt',
        'profile_path': '/brad.jpg',
      }),
    ],
    totalPages: 1,
  );
}

/// Remembers the country each call was made for.
class _RegionTmdbService extends TmdbService {
  _RegionTmdbService() : super(Dio(), 'en-US', () async => 'test-key');

  String? discoverRegion;
  String? providersRegion;

  @override
  Future<TmdbPage<MediaItem>> discover({
    required String type,
    required int page,
    String? sortBy,
    List<int>? genres,
    List<String>? languages,
    double? minRating,
    double? maxRating,
    int? minYear,
    int? maxYear,
    int? minVotes,
    int? maxVotes,
    int? minRuntime,
    int? maxRuntime,
    List<int>? watchProviders,
    String? watchRegion,
  }) async {
    discoverRegion = watchRegion;
    return (results: <MediaItem>[], totalPages: 1);
  }

  @override
  Future<List<WatchProvider>> getWatchProviders(
    String type,
    String region,
  ) async {
    providersRegion = region;
    return [];
  }
}

List<int> _ids(ProviderContainer container) => container
    .read(exploreResultsProvider)
    .value!
    .items
    .map((r) => (r as TitleResult).title.tmdbId)
    .toList();

void main() {
  late _FlakyTmdbService tmdb;
  late ProviderContainer container;

  setUp(() {
    tmdb = _FlakyTmdbService();
    container = ProviderContainer(
      retry: noProviderRetry,
      overrides: [
        tmdbServiceProvider.overrideWithValue(tmdb),
        localizationsProvider.overrideWithValue(AppLocalizationsEn()),
        watchRegionProvider.overrideWithValue('IT'),
      ],
    );
  });

  tearDown(() => container.dispose());

  test('a failed next page keeps the results, tells the user, and retries '
      'the same page on the next scroll', () async {
    final notifier = container.read(exploreResultsProvider.notifier);
    await container.read(exploreResultsProvider.future);

    tmdb.isOnline = false;
    await notifier.fetchNextPage();

    expect(_ids(container), [1]);
    expect(container.read(errorServiceProvider), isNotNull);

    tmdb.isOnline = true;
    await notifier.fetchNextPage();

    expect(_ids(container), [1, 2]);
  });

  test('a next page that was loading for old filters is dropped', () async {
    final notifier = container.read(exploreResultsProvider.notifier);
    await container.read(exploreResultsProvider.future);

    tmdb.nextPageGate = Completer<void>();
    final pending = notifier.fetchNextPage();
    expect(container.read(exploreResultsProvider).value!.isLoadingMore, isTrue);

    container
        .read(exploreFiltersProvider.notifier)
        .set(ExploreFilters(genres: const [35]));
    final fresh = await container.read(exploreResultsProvider.future);
    tmdb.nextPageGate!.complete();
    await pending;

    final results = container.read(exploreResultsProvider).value!;
    expect(identical(results, fresh), isTrue);
    expect(results.items.map((r) => (r as TitleResult).title.titleEn), [
      'Genres [35]',
    ]);
  });

  test('the people tab lists people, not titles', () async {
    container
        .read(exploreMediaTypeProvider.notifier)
        .select(ExploreType.person);

    final results = await container.read(exploreResultsProvider.future);

    final person = (results.items.single as PersonResult).person;
    expect(person.id, 287);
    expect(person.name, 'Brad Pitt');
    expect(results.hasMore, isFalse);
  });

  // REV-77: the country was fixed to Italy.
  test('the services and the provider filter use the streaming country '
      'setting', () async {
    final regionTmdb = _RegionTmdbService();
    final usContainer = ProviderContainer(
      retry: noProviderRetry,
      overrides: [
        tmdbServiceProvider.overrideWithValue(regionTmdb),
        watchRegionProvider.overrideWithValue('US'),
      ],
    );
    addTearDown(usContainer.dispose);

    usContainer.read(exploreFiltersProvider.notifier).toggleWatchProvider(8);
    await usContainer.read(exploreResultsProvider.future);
    await usContainer.read(watchProvidersListProvider.future);

    expect(regionTmdb.discoverRegion, 'US');
    expect(regionTmdb.providersRegion, 'US');
  });

  group('mainWatchProviders', () {
    /// TMDB's service [name], read for Italy.
    WatchProvider provider(
      String name, {
      int? global,
      Map<String, int>? byRegion,
    }) => WatchProvider.fromTmdbMap({
      'provider_name': name,
      'display_priority': ?global,
      'display_priorities': ?byRegion,
    }, 'IT');

    test('keeps the services ranked first in the region', () {
      final result = mainWatchProviders([
        provider('Now Playing TV', global: 1, byRegion: {'IT': 50}),
        provider('Netflix', global: 2, byRegion: {'IT': 1}),
        provider('NOW', global: 9, byRegion: {'IT': 2}),
        provider('Other', global: 3),
      ], count: 3);

      expect(result.map((p) => p.name), ['Netflix', 'NOW', 'Other']);
    });

    test('providers without a priority go last', () {
      final result = mainWatchProviders([
        provider('Unranked'),
        provider('Ranked', global: 5),
      ]);

      expect(result.map((p) => p.name), ['Ranked', 'Unranked']);
    });
  });
}
