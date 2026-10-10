import 'package:cinemuse_app/core/application/l10n_provider.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/error/error_service.dart';
import 'package:cinemuse_app/features/explore/application/explore_providers.dart';
import 'package:cinemuse_app/features/media/data/tmdb_service.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Page 1 works, later pages fail until [isOnline] is set back to true.
class _FlakyTmdbService extends TmdbService {
  _FlakyTmdbService() : super(Dio(), 'en-US');

  bool isOnline = true;

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
    if (page > 1 && !isOnline) {
      throw const NetworkFailure('offline');
    }
    return {
      'results': [
        {'id': page},
      ],
      'total_pages': 5,
    };
  }
}

void main() {
  late _FlakyTmdbService tmdb;
  late ProviderContainer container;

  setUp(() {
    tmdb = _FlakyTmdbService();
    container = ProviderContainer(
      overrides: [
        tmdbServiceProvider.overrideWithValue(tmdb),
        localizationsProvider.overrideWithValue(AppLocalizationsEn()),
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

    expect(container.read(exploreResultsProvider).value, [
      {'id': 1},
    ]);
    expect(container.read(errorServiceProvider), isNotNull);

    tmdb.isOnline = true;
    await notifier.fetchNextPage();

    expect(container.read(exploreResultsProvider).value, [
      {'id': 1},
      {'id': 2},
    ]);
  });
}
