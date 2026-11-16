import 'package:cinemuse_app/features/media/domain/episode_item.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/episodes/episode_carousel_card.dart';
import 'package:cinemuse_app/features/streaming/unified_stream_resolver.dart';
import 'package:cinemuse_app/features/streaming/unified_stream_resolver_provider.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/menu_helpers.dart';
import 'package:cinemuse_app/core/application/provider_retry.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';

import '../../../../../helpers/app_font.dart';

class _MockResolver extends Mock implements UnifiedStreamResolver {}

const _short = 'Jim and Pam plan a party.';
final _long = List.filled(
  80,
  'The armies gather at Winterfell to face the dead.',
).join(' ');

/// One card as the PC shows it, in the room the episode row gives it (its
/// height, 285, less the 16 it keeps under the cards).
Future<void> _pumpCard(
  WidgetTester tester, {
  String? overview,
  void Function()? onPlay,
}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final resolver = _MockResolver();
  when(
    () => resolver.hasCachedStream(
      any(),
      any(),
      season: any(named: 'season'),
      episode: any(named: 'episode'),
    ),
  ).thenReturn(false);
  await tester.pumpWidget(
    ProviderScope(
      retry: noProviderRetry,
      overrides: [unifiedStreamResolverProvider.overrideWithValue(resolver)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Align(
            alignment: const Alignment(0.5, -0.9),
            child: SizedBox(
              width: 300,
              height: 269,
              child: Align(
                alignment: Alignment.topLeft,
                child: EpisodeCarouselCard(
                  episode: EpisodeItem(
                    episodeNumber: 4,
                    seasonNumber: 8,
                    name: 'The Long Night',
                    overview: overview,
                    runtime: 82,
                    airDate: DateTime(2019, 5, 12),
                  ),
                  seasonNumber: 8,
                  mediaId: '1399',
                  onEpisodeTap: (_, _, _, {restart = false}) => onPlay?.call(),
                  onTrackOptions: (_, _) {},
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openMenu(WidgetTester tester) =>
    rightClickAt(tester, tester.getCenter(find.byType(EpisodeCarouselCard)));

final _menuSynopsis = find.descendant(
  of: menuItems,
  matching: find.text('Synopsis'),
);

void main() {
  setUpAll(loadAppFont);

  testWidgets('right-click: the menu opens at the pointer (REV-248)', (
    tester,
  ) async {
    await _pumpCard(tester);
    final at = tester.getCenter(find.byType(EpisodeCarouselCard));
    await rightClickAt(tester, at);
    expect(menuItems, findsWidgets);
    expectMenuAt(tester, at);
  });

  testWidgets('a short synopsis shows whole, with no Read more', (
    tester,
  ) async {
    await _pumpCard(tester, overview: _short);
    expect(find.text(_short), findsOneWidget);
    expect(find.text('Read more'), findsNothing);
  });

  testWidgets('no synopsis: no lines, no Read more, no menu item', (
    tester,
  ) async {
    await _pumpCard(tester, overview: '  ');
    expect(find.text('Read more'), findsNothing);
    await _openMenu(tester);
    expect(menuItems, findsWidgets);
    expect(_menuSynopsis, findsNothing);
  });

  testWidgets('a long synopsis: two lines, and Read more opens the whole '
      'text without playing', (tester) async {
    var played = 0;
    await _pumpCard(tester, overview: _long, onPlay: () => played++);
    // Fits the row's height (an overflow would fail the test).
    final preview = tester.widget<Text>(find.text(_long));
    expect(preview.maxLines, 2);

    await tester.tap(find.text('Read more'));
    await tester.pumpAndSettle();
    expect(played, 0);
    expect(find.text('S8 E4 • The Long Night'), findsOneWidget);
    expect(find.text('May 12, 2019 · 82m'), findsOneWidget);
    final whole = find.byWidgetPredicate(
      (w) => w is Text && w.data == _long && w.maxLines == null,
    );
    expect(whole, findsOneWidget);

    // Down scrolls the long text, Esc closes the window.
    final scrollable = find.ancestor(
      of: whole,
      matching: find.byType(Scrollable),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(scrollable.first).position.pixels,
      greaterThan(0),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(whole, findsNothing);
  });

  testWidgets('the menu has Synopsis, which opens the same window', (
    tester,
  ) async {
    await _pumpCard(tester, overview: _short);
    await _openMenu(tester);
    await tester.tap(_menuSynopsis);
    await tester.pumpAndSettle();
    expect(find.text('S8 E4 • The Long Night'), findsOneWidget);
    expect(find.text(_short), findsNWidgets(2));
  });
}
