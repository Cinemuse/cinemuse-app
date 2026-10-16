import 'dart:async';

import 'package:cinemuse_app/core/application/l10n_provider.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/error/error_service.dart';
import 'package:cinemuse_app/features/explore/application/explore_providers.dart';
import 'package:cinemuse_app/features/explore/domain/explore_filters.dart';
import 'package:cinemuse_app/features/media/data/tmdb_service.dart';
import 'package:cinemuse_app/features/settings/application/watch_region_providers.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Page 1 works, later pages fail until [isOnline] is set back to true.
/// While [nextPageGate] is set, later pages wait for it.
class _FlakyTmdbService extends TmdbService {
  _FlakyTmdbService() : super(Dio(), 'en-US');

  bool isOnline = true;
  Completer<void>? nextPageGate;

  @override
  Future<Map<String, dynamic>> discover({
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
    return {
      'results': [
        {'id': page, 'genres': genres},
      ],
      'total_pages': 5,
    };
  }
}

/// Remembers the country each call was made for.
class _RegionTmdbService extends TmdbService {
  _RegionTmdbService() : super(Dio(), 'en-US');

  String? discoverRegion;
  String? providersRegion;

  @override
  Future<Map<String, dynamic>> discover({
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
    return {'results': [], 'total_pages': 1};
  }

  @override
  Future<List<Map<String, dynamic>>> getWatchProviders(
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
    .map((m) => m['id'] as int)
    .toList();

void main() {
  late _FlakyTmdbService tmdb;
  late ProviderContainer container;

  setUp(() {
    tmdb = _FlakyTmdbService();
    container = ProviderContainer(
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
    expect(results.items, [
      {
        'id': 1,
        'genres': [35],
      },
    ]);
  });

  // REV-77: the country was fixed to Italy.
  test('the services and the provider filter use the streaming country '
      'setting', () async {
    final regionTmdb = _RegionTmdbService();
    final usContainer = ProviderContainer(
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
    Map<String, dynamic> provider(
      String name, {
      int? global,
      Map<String, int>? byRegion,
    }) => {
      'provider_name': name,
      'display_priority': ?global,
      'display_priorities': ?byRegion,
    };

    test('keeps the services ranked first in the region', () {
      final result = mainWatchProviders(
        [
          provider('Now Playing TV', global: 1, byRegion: {'IT': 50}),
          provider('Netflix', global: 2, byRegion: {'IT': 1}),
          provider('NOW', global: 9, byRegion: {'IT': 2}),
          provider('Other', global: 3),
        ],
        'IT',
        count: 3,
      );

      expect(result.map((p) => p['provider_name']), [
        'Netflix',
        'NOW',
        'Other',
      ]);
    });

    test('providers without a priority go last', () {
      final result = mainWatchProviders([
        provider('Unranked'),
        provider('Ranked', global: 5),
      ], 'IT');

      expect(result.map((p) => p['provider_name']), ['Ranked', 'Unranked']);
    });
  });
}
