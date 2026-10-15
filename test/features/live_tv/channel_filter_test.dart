import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';

const _filterKey = 'live_tv_selected_categories';

ProviderContainer _createContainer() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  container.listen(channelFilterProvider, (previous, next) {});
  container.listen(favoriteChannelIdsProvider, (previous, next) {});
  container.listen(recentChannelIdsProvider, (previous, next) {});
  return container;
}

Future<void> _settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChannelFilter', () {
    test('initial state has no active filter', () {
      const filter = ChannelFilter();
      expect(filter.isActive, isFalse);
      expect(filter.selectedCategories, isEmpty);
    });

    test('isActive is true when categories are present', () {
      const filter = ChannelFilter(selectedCategories: {'Cinema', 'Sport'});
      expect(filter.isActive, isTrue);
      expect(filter.selectedCategories, contains('Cinema'));
      expect(filter.selectedCategories, contains('Sport'));
    });
  });

  group('ChannelFilterNotifier with local cache', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'toggleCategory adds and removes categories and updates cache',
      () async {
        final container = _createContainer();
        final notifier = container.read(channelFilterProvider.notifier);
        ChannelFilter state() => container.read(channelFilterProvider);

        // Initially empty
        expect(state().isActive, isFalse);

        // Toggle 'Cinema' on
        await notifier.toggleCategory('Cinema');
        expect(state().isActive, isTrue);
        expect(state().selectedCategories, {'Cinema'});

        // Check SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getStringList(_filterKey), ['Cinema']);

        // Toggle 'Sport' on (multiselect)
        await notifier.toggleCategory('Sport');
        expect(state().selectedCategories, {'Cinema', 'Sport'});
        expect(
          prefs.getStringList(_filterKey),
          unorderedEquals(['Cinema', 'Sport']),
        );

        // Toggle 'Cinema' off
        await notifier.toggleCategory('Cinema');
        expect(state().selectedCategories, {'Sport'});
        expect(prefs.getStringList(_filterKey), ['Sport']);

        // Toggle 'Sport' off
        await notifier.toggleCategory('Sport');
        expect(state().isActive, isFalse);
        expect(prefs.getStringList(_filterKey), isNull);
      },
    );

    test('selectAll / clear resets filter and clears cache', () async {
      SharedPreferences.setMockInitialValues({
        _filterKey: ['Cinema', 'DTT'],
      });

      final container = _createContainer();
      await _settle();

      final filter = container.read(channelFilterProvider);
      expect(filter.selectedCategories, {'Cinema', 'DTT'});

      // Clear
      await container.read(channelFilterProvider.notifier).clear();
      expect(container.read(channelFilterProvider).isActive, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(_filterKey), isNull);
    });

    test('a change made while loading is not lost (REV-122)', () async {
      SharedPreferences.setMockInitialValues({
        _filterKey: ['Cinema'],
      });
      final container = _createContainer();

      // Before the load has finished.
      await container
          .read(channelFilterProvider.notifier)
          .toggleCategory('Sport');

      expect(container.read(channelFilterProvider).selectedCategories, {
        'Cinema',
        'Sport',
      });
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList(_filterKey),
        unorderedEquals(['Cinema', 'Sport']),
      );
    });
  });

  group('Favorites and recents (REV-122)', () {
    test('a favorite toggled while loading keeps the saved ones', () async {
      SharedPreferences.setMockInitialValues({
        'live_tv_favorites': ['a'],
      });
      final container = _createContainer();

      await container.read(favoriteChannelIdsProvider.notifier).toggle('b');

      expect(container.read(favoriteChannelIdsProvider), {'a', 'b'});
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList('live_tv_favorites'),
        unorderedEquals(['a', 'b']),
      );
    });

    test('push moves a channel to the front, without duplicates', () async {
      SharedPreferences.setMockInitialValues({
        'live_tv_recents': ['a', 'b', 'c'],
      });
      final container = _createContainer();

      await container.read(recentChannelIdsProvider.notifier).push('b');

      expect(container.read(recentChannelIdsProvider), ['b', 'a', 'c']);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('live_tv_recents'), ['b', 'a', 'c']);
    });

    test('the choices survive a restart', () async {
      SharedPreferences.setMockInitialValues({});
      final before = ProviderContainer();
      before.listen(channelFilterProvider, (previous, next) {});
      final filter = before.read(channelFilterProvider.notifier);
      final favorites = before.read(favoriteChannelIdsProvider.notifier);
      final recents = before.read(recentChannelIdsProvider.notifier);
      await filter.toggleCategory('DTT');
      await filter.toggleCategory('Sport');
      await favorites.toggle('kept');
      await favorites.toggle('removed');
      await favorites.toggle('removed');
      await recents.push('old');
      await recents.push('new');
      before.dispose();

      // Fresh providers on the same storage, like after a restart.
      final after = _createContainer();
      await _settle();
      expect(after.read(channelFilterProvider).selectedCategories, {
        'DTT',
        'Sport',
      });
      expect(after.read(favoriteChannelIdsProvider), {'kept'});
      expect(after.read(recentChannelIdsProvider), ['new', 'old']);

      // "All channels" = no chip, also after the next restart.
      await after.read(channelFilterProvider.notifier).selectAll();
      final again = _createContainer();
      await _settle();
      expect(again.read(channelFilterProvider).isActive, isFalse);
    });

    test('recents keep at most 15 channels', () async {
      SharedPreferences.setMockInitialValues({
        'live_tv_recents': [for (var i = 0; i < 15; i++) '$i'],
      });
      final container = _createContainer();

      await container.read(recentChannelIdsProvider.notifier).push('new');

      final recents = container.read(recentChannelIdsProvider);
      expect(recents, hasLength(15));
      expect(recents.first, 'new');
      expect(recents, isNot(contains('14')));
    });
  });

  group('Channel filtering with multiselect', () {
    final channels = [
      Channel(lcn: 1, name: 'Rai 1', logo: 'logo1.png', group: 'DTT'),
      Channel(lcn: 2, name: 'Sky Cinema', logo: 'logo2.png', group: 'Cinema'),
      Channel(lcn: 3, name: 'Sky Sport', logo: 'logo3.png', group: 'Sport'),
      Channel(lcn: 4, name: 'Tg24', logo: 'logo4.png', group: 'News'),
    ];

    test('filters channels matching any selected category', () {
      const filter = ChannelFilter(selectedCategories: {'Cinema', 'Sport'});
      final filtered = channels.where((ch) {
        if (ch.group == null) return false;
        return filter.selectedCategories.contains(ch.group);
      }).toList();

      expect(filtered.length, 2);
      expect(
        filtered.map((c) => c.name),
        containsAll(['Sky Cinema', 'Sky Sport']),
      );
      expect(filtered.map((c) => c.name), isNot(contains('Rai 1')));
    });

    test('shows all channels when filter is inactive', () {
      const filter = ChannelFilter();
      final filtered = !filter.isActive
          ? channels
          : channels
                .where((ch) => filter.selectedCategories.contains(ch.group))
                .toList();

      expect(filtered.length, 4);
    });

    test('selected chips keep channel-number order (REV-279)', () async {
      SharedPreferences.setMockInitialValues({
        _filterKey: ['Sport', 'DTT'],
      });
      final container = ProviderContainer(
        overrides: [
          channelsProvider.overrideWith(
            (ref) async => [
              ...channels,
              Channel(lcn: 5, name: 'Canale 5', logo: '', group: 'DTT'),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(filteredChannelsProvider, (previous, next) {});
      await _settle();

      final lcns = container
          .read(filteredChannelsProvider)
          .requireValue
          .map((c) => c.lcn);
      expect(lcns, [1, 3, 5]);
    });
  });
}
