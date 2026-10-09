import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChannelFilter', () {
    test('initial state has no active filter', () {
      const filter = ChannelFilter();
      expect(filter.isActive, isFalse);
      expect(filter.selectedCategories, isEmpty);
      expect(filter.effectiveCategories, isEmpty);
      expect(filter.selectedGroup, isNull);
    });

    test('isActive is true when categories are present', () {
      const filter = ChannelFilter(selectedCategories: {'Cinema', 'Sport'});
      expect(filter.isActive, isTrue);
      expect(filter.effectiveCategories, contains('Cinema'));
      expect(filter.effectiveCategories, contains('Sport'));
    });

    test('backwards compatibility: selectedGroup fallback works', () {
      const filter = ChannelFilter(selectedGroup: 'Entertainment');
      expect(filter.isActive, isTrue);
      expect(filter.selectedGroup, 'Entertainment');
      expect(filter.effectiveCategories, contains('Entertainment'));
    });
  });

  group('ChannelFilterNotifier with local cache', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'toggleCategory adds and removes categories and updates cache',
      () async {
        final notifier = ChannelFilterNotifier();

        // Initially empty
        expect(notifier.state.isActive, isFalse);

        // Toggle 'Cinema' on
        await notifier.toggleCategory('Cinema');
        expect(notifier.state.isActive, isTrue);
        expect(notifier.state.effectiveCategories, {'Cinema'});

        // Check SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getStringList('live_tv_selected_categories'), ['Cinema']);

        // Toggle 'Sport' on (multiselect)
        await notifier.toggleCategory('Sport');
        expect(notifier.state.effectiveCategories, {'Cinema', 'Sport'});
        expect(
          prefs.getStringList('live_tv_selected_categories'),
          unorderedEquals(['Cinema', 'Sport']),
        );

        // Toggle 'Cinema' off
        await notifier.toggleCategory('Cinema');
        expect(notifier.state.effectiveCategories, {'Sport'});
        expect(prefs.getStringList('live_tv_selected_categories'), ['Sport']);

        // Toggle 'Sport' off
        await notifier.toggleCategory('Sport');
        expect(notifier.state.isActive, isFalse);
        expect(prefs.getStringList('live_tv_selected_categories'), isNull);
      },
    );

    test('selectAll / clear resets filter and clears cache', () async {
      SharedPreferences.setMockInitialValues({
        'live_tv_selected_categories': ['Cinema', 'DTT'],
      });

      final notifier = ChannelFilterNotifier();
      // Allow async _load to complete
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(notifier.state.isActive, isTrue);
      expect(notifier.state.effectiveCategories, contains('Cinema'));
      expect(notifier.state.effectiveCategories, contains('DTT'));

      // Clear
      await notifier.clear();
      expect(notifier.state.isActive, isFalse);
      expect(notifier.state.effectiveCategories, isEmpty);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('live_tv_selected_categories'), isNull);
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
        return filter.effectiveCategories.contains(ch.group);
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
                .where((ch) => filter.effectiveCategories.contains(ch.group))
                .toList();

      expect(filtered.length, 4);
    });

    test(
      'category sections remain grouped and titled when filter is active',
      () {
        const filter = ChannelFilter(selectedCategories: {'Cinema'});
        final filtered = channels
            .where((ch) => filter.effectiveCategories.contains(ch.group))
            .toList();

        final grouped = <String, List<Channel>>{};
        for (final ch in filtered) {
          final key = ch.group?.isNotEmpty == true ? ch.group! : 'Other';
          (grouped[key] ??= []).add(ch);
        }
        final sections = grouped.keys
            .map((k) => ChannelSection(title: k, channels: grouped[k]!))
            .toList();

        expect(sections.length, 1);
        expect(sections.first.title, 'Cinema');
        expect(sections.first.title.isNotEmpty, isTrue);
      },
    );

    test(
      'inactive category filter produces a flat single section with empty title',
      () {
        const filter = ChannelFilter();
        final isFlat = !filter.isActive;
        expect(isFlat, isTrue);

        final sections = isFlat
            ? [ChannelSection(title: '', channels: channels)]
            : <ChannelSection>[];

        expect(sections.length, 1);
        expect(sections.first.title, isEmpty);
        expect(sections.first.channels.map((c) => c.lcn).toList(), [
          1,
          2,
          3,
          4,
        ]);
      },
    );
  });
}
