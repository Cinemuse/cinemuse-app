import 'package:cinemuse_app/core/application/l10n_provider.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/services/system/connectivity_service.dart';
import 'package:cinemuse_app/features/explore/presentation/pages/explore_screen.dart';
import 'package:cinemuse_app/features/explore/presentation/widgets/explore_result_card.dart';
import 'package:cinemuse_app/features/media/application/watch_history_store.dart';
import 'package:cinemuse_app/features/media/data/tmdb_service.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:cinemuse_app/shared/widgets/error_card.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/focus_helpers.dart';

/// Answers every discover page with 20 titles (no posters) out of 10 pages,
/// and remembers which pages were asked for.
class _PagedTmdbService extends TmdbService {
  _PagedTmdbService() : super(Dio(), 'en-US');

  final requestedPages = <int>[];

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
    requestedPages.add(page);
    return {
      'results': [
        for (var i = 0; i < 20; i++)
          {'id': page * 100 + i, 'title': 'Movie $page-$i'},
      ],
      'total_pages': 10,
    };
  }
}

/// Fails every discover call while [isOnline] is false.
class _OfflineTmdbService extends _PagedTmdbService {
  bool isOnline = false;

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
    if (!isOnline) throw const NetworkFailure('offline');
    return super.discover(type: type, page: page);
  }
}

Future<void> _pumpExplore(WidgetTester tester, TmdbService tmdb) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tmdbServiceProvider.overrideWithValue(tmdb),
        localizationsProvider.overrideWithValue(AppLocalizationsEn()),
        connectivityProvider.overrideWith(
          (ref) => Stream.value(ConnectivityResult.wifi),
        ),
        watchHistoryStoreProvider.overrideWith((ref) => Stream.value({})),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ExploreScreen(),
      ),
    ),
  );
  for (var i = 0; i < 20; i++) {
    await tester.pump();
  }
}

void main() {
  testWidgets('on a big window, pages load by themselves until the grid '
      'scrolls', (tester) async {
    tester.view.physicalSize = const Size(2560, 1440);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final tmdb = _PagedTmdbService();
    await _pumpExplore(tester, tmdb);

    // The first page alone is one row: it fits without a scrollbar.
    expect(tmdb.requestedPages.length, greaterThan(1));
    expect(tmdb.requestedPages, [
      for (var p = 1; p <= tmdb.requestedPages.length; p++) p,
    ]);
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    expect(position.maxScrollExtent, greaterThan(0));
    // It stops once the grid scrolls: not every page.
    expect(tmdb.requestedPages.length, lessThan(10));
    expect(find.byType(ExploreResultCard), findsWidgets);
  });

  testWidgets('a failed load shows the error card with Retry focused, and '
      'Retry loads the grid', (tester) async {
    final tmdb = _OfflineTmdbService();
    await _pumpExplore(tester, tmdb);

    expect(find.byType(ErrorCard), findsOneWidget);
    expect(find.byType(ExploreResultCard), findsNothing);
    expect(isFocused(find.text('Retry')), isTrue);

    tmdb.isOnline = true;
    await tester.tap(find.text('Retry'));
    for (var i = 0; i < 20; i++) {
      await tester.pump();
    }

    expect(find.byType(ErrorCard), findsNothing);
    expect(find.byType(ExploreResultCard), findsWidgets);
  });
}
