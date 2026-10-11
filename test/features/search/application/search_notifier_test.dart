import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cinemuse_app/features/search/application/search_provider.dart';
import 'package:cinemuse_app/features/media/data/tmdb_service.dart';
import 'package:mocktail/mocktail.dart';

class MockTmdbService extends Mock implements TmdbService {}

typedef _Page = ({List<Map<String, dynamic>> results, int totalPages});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late MockTmdbService mockTmdbService;

  group('SearchNotifier History Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'global_search_history': ['initial 1', 'initial 2'],
      });

      mockTmdbService = MockTmdbService();

      container = ProviderContainer(
        overrides: [tmdbServiceProvider.overrideWithValue(mockTmdbService)],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('Loads initial search history from SharedPreferences', () async {
      container.read(searchProvider.notifier);
      // Wait for async load to finish
      await Future.delayed(Duration.zero);

      final state = container.read(searchProvider);
      expect(state.searchHistory, equals(['initial 1', 'initial 2']));
    });

    test('addToHistory adds item to the top of history and saves', () async {
      final notifier = container.read(searchProvider.notifier);
      await Future.delayed(Duration.zero);

      await notifier.addToHistory('new search');

      final state = container.read(searchProvider);
      expect(
        state.searchHistory,
        equals(['new search', 'initial 1', 'initial 2']),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList('global_search_history'),
        equals(['new search', 'initial 1', 'initial 2']),
      );
    });

    test('addToHistory removes duplicates and moves them to top', () async {
      final notifier = container.read(searchProvider.notifier);
      await Future.delayed(Duration.zero);

      await notifier.addToHistory('initial 2');

      final state = container.read(searchProvider);
      expect(state.searchHistory, equals(['initial 2', 'initial 1']));

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList('global_search_history'),
        equals(['initial 2', 'initial 1']),
      );
    });

    test('addToHistory limits search history length to 20', () async {
      final notifier = container.read(searchProvider.notifier);
      await Future.delayed(Duration.zero);

      for (int i = 0; i < 25; i++) {
        await notifier.addToHistory('search $i');
      }

      final state = container.read(searchProvider);
      expect(state.searchHistory.length, equals(20));
      expect(state.searchHistory.first, equals('search 24'));
      expect(state.searchHistory.last, equals('search 5'));
    });

    test('removeFromHistory removes a single query from history', () async {
      final notifier = container.read(searchProvider.notifier);
      await Future.delayed(Duration.zero);

      await notifier.removeFromHistory('initial 1');

      final state = container.read(searchProvider);
      expect(state.searchHistory, equals(['initial 2']));

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList('global_search_history'),
        equals(['initial 2']),
      );
    });

    test('clearHistory removes all queries from history', () async {
      final notifier = container.read(searchProvider.notifier);
      await Future.delayed(Duration.zero);

      await notifier.clearHistory();

      final state = container.read(searchProvider);
      expect(state.searchHistory, isEmpty);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('global_search_history'), isNull);
    });
  });

  group('SearchNotifier stale answers (REV-53)', () {
    _Page page(String name, int count, {int totalPages = 1}) => (
      results: [
        for (var i = 0; i < count; i++)
          {'id': i, 'media_type': 'movie', 'title': '$name $i'},
      ],
      totalPages: totalPages,
    );

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockTmdbService = MockTmdbService();
      container = ProviderContainer(
        overrides: [tmdbServiceProvider.overrideWithValue(mockTmdbService)],
      );
    });

    tearDown(() => container.dispose());

    test('an old answer arriving last does not replace the new one', () async {
      final bat = Completer<_Page>();
      final batman = Completer<_Page>();
      when(
        () => mockTmdbService.searchMulti('bat', page: 1),
      ).thenAnswer((_) => bat.future);
      when(
        () => mockTmdbService.searchMulti('batman', page: 1),
      ).thenAnswer((_) => batman.future);
      final notifier = container.read(searchProvider.notifier);

      final first = notifier.search('bat');
      final second = notifier.search('batman');
      batman.complete(page('batman', 1));
      await second;
      bat.complete(page('bat', 3));
      await first;

      final state = container.read(searchProvider);
      expect(state.query, 'batman');
      expect(state.results.single['title'], 'batman 0');
    });

    test('page 2 of an old query is not added to the new results', () async {
      final oldPage2 = Completer<_Page>();
      when(
        () => mockTmdbService.searchMulti('bat', page: 1),
      ).thenAnswer((_) async => page('bat', 20, totalPages: 2));
      when(
        () => mockTmdbService.searchMulti('bat', page: 2),
      ).thenAnswer((_) => oldPage2.future);
      when(
        () => mockTmdbService.searchMulti('batman', page: 1),
      ).thenAnswer((_) async => page('batman', 1));
      final notifier = container.read(searchProvider.notifier);

      await notifier.search('bat');
      final more = notifier.loadMore();
      await notifier.search('batman');
      oldPage2.complete(page('bat page 2', 5));
      await more;

      final state = container.read(searchProvider);
      expect(state.results.map((r) => r['title']), ['batman 0']);
    });

    test('Enter after typing searches only once', () async {
      when(
        () => mockTmdbService.searchMulti('dune', page: 1),
      ).thenAnswer((_) async => page('dune', 1));
      final notifier = container.read(searchProvider.notifier);

      notifier.onQueryChanged('dune');
      await notifier.search('dune');
      await Future<void>.delayed(const Duration(milliseconds: 600));

      verify(() => mockTmdbService.searchMulti('dune', page: 1)).called(1);
    });

    test(
      'a show and a movie with the same id are both kept (REV-62)',
      () async {
        when(() => mockTmdbService.searchMulti('x', page: 1)).thenAnswer(
          (_) async => (
            results: [
              {'id': 7, 'media_type': 'movie'},
            ],
            totalPages: 2,
          ),
        );
        when(() => mockTmdbService.searchMulti('x', page: 2)).thenAnswer(
          (_) async => (
            results: [
              {'id': 7, 'media_type': 'tv'},
              {'id': 7, 'media_type': 'movie'},
            ],
            totalPages: 2,
          ),
        );
        final notifier = container.read(searchProvider.notifier);

        await notifier.search('x');
        await notifier.loadMore();

        final state = container.read(searchProvider);
        expect(state.results.map((r) => r['media_type']), ['movie', 'tv']);
        expect(state.hasMore, isFalse);
      },
    );

    test(
      'hasMore follows TMDB total_pages, not the page size (REV-62)',
      () async {
        when(
          () => mockTmdbService.searchMulti('one', page: 1),
        ).thenAnswer((_) async => page('one', 20));
        final notifier = container.read(searchProvider.notifier);

        await notifier.search('one');

        expect(container.read(searchProvider).hasMore, isFalse);
      },
    );
  });
}
