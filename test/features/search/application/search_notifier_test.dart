import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cinemuse_app/features/search/application/search_provider.dart';
import 'package:cinemuse_app/core/services/media/tmdb_service.dart';
import 'package:mocktail/mocktail.dart';

class MockTmdbService extends Mock implements TmdbService {}

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
        overrides: [
          tmdbServiceProvider.overrideWithValue(mockTmdbService),
        ],
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
      expect(state.searchHistory, equals(['new search', 'initial 1', 'initial 2']));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('global_search_history'), equals(['new search', 'initial 1', 'initial 2']));
    });

    test('addToHistory removes duplicates and moves them to top', () async {
      final notifier = container.read(searchProvider.notifier);
      await Future.delayed(Duration.zero);

      await notifier.addToHistory('initial 2');

      final state = container.read(searchProvider);
      expect(state.searchHistory, equals(['initial 2', 'initial 1']));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('global_search_history'), equals(['initial 2', 'initial 1']));
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
      expect(prefs.getStringList('global_search_history'), equals(['initial 2']));
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
}
