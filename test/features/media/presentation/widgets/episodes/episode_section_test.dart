import 'dart:async';

import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/episodes/episode_carousel_card.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/episodes/episode_list_card.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/episodes/episode_section.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/episodes/season_selector.dart';
import 'package:cinemuse_app/features/streaming/unified_stream_resolver.dart';
import 'package:cinemuse_app/features/streaming/unified_stream_resolver_provider.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockResolver extends Mock implements UnifiedStreamResolver {}

// REV-204, REV-207: picking a season moved the selector to another parent
// (focus lost) and a missing season dropped the whole box with its selector.
void main() {
  const details = {
    'seasons': [
      {'season_number': 1, 'episode_count': 2},
      {'season_number': 2, 'episode_count': 2},
    ],
  };

  Map<String, dynamic> season(int n) => {
    'episodes': [
      for (var e = 1; e <= 2; e++)
        {'episode_number': e, 'name': 'S$n episode $e'},
    ],
  };

  late Map<int, Completer<Map<String, dynamic>?>> pending;
  late Set<int> failing;
  late _MockResolver resolver;

  setUp(() {
    pending = {};
    failing = {};
    resolver = _MockResolver();
    when(
      () => resolver.hasCachedStream(
        any(),
        any(),
        season: any(named: 'season'),
        episode: any(named: 'episode'),
      ),
    ).thenReturn(false);
  });

  Widget app() => ProviderScope(
    overrides: [
      unifiedStreamResolverProvider.overrideWithValue(resolver),
      seasonDetailsProvider.overrideWith((ref, args) async {
        if (failing.contains(args.seasonNumber)) {
          throw const NetworkFailure('offline');
        }
        final completer = pending[args.seasonNumber];
        if (completer != null) return completer.future;
        return season(args.seasonNumber);
      }),
      watchedEpisodesMapProvider.overrideWith((ref, id) => const {}),
      episodeProgressMapProvider.overrideWith(
        (ref, id) => Stream.value(const {}),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(
        body: SingleChildScrollView(
          child: EpisodeSection(mediaId: '1429', details: details),
        ),
      ),
    ),
  );

  Future<void> setWindow(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  bool focusIn<T extends Widget>() {
    final focused = FocusManager.instance.primaryFocus?.context;
    return focused != null &&
        focused.findAncestorWidgetOfExactType<T>() != null;
  }

  Future<void> focusSelector(WidgetTester tester) async {
    for (var i = 0; i < 10 && !focusIn<SeasonSelector>(); i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(focusIn<SeasonSelector>(), isTrue);
  }

  Future<void> pickSeason2WithKeys(WidgetTester tester) async {
    await focusSelector(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Season 2'), findsOneWidget);
    // The first ↓ focuses "Season 1", the second "Season 2".
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    // Not pumpAndSettle: the season's spinner never settles.
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('wide: a season picked with the keys loads in the same box', (
    tester,
  ) async {
    await setWindow(tester, const Size(1280, 800));
    pending[2] = Completer();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.textContaining('S1 episode 1'), findsOneWidget);

    await pickSeason2WithKeys(tester);

    // Loading: spinner inside the box, the selector kept with the focus.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.widgetWithText(SeasonSelector, 'Season 2'), findsOneWidget);
    expect(focusIn<SeasonSelector>(), isTrue);

    pending[2]!.complete(season(2));
    await tester.pumpAndSettle();
    expect(find.textContaining('S2 episode 1'), findsOneWidget);
    expect(focusIn<SeasonSelector>(), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(focusIn<EpisodeCarouselCard>(), isTrue);
  });

  testWidgets('narrow: a season picked by tapping loads in the same box', (
    tester,
  ) async {
    await setWindow(tester, const Size(400, 900));
    pending[2] = Completer();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byType(EpisodeListCard), findsNWidgets(2));

    await tester.tap(find.byType(SeasonSelector));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Season 2').last);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.widgetWithText(SeasonSelector, 'Season 2'), findsOneWidget);

    pending[2]!.complete(season(2));
    await tester.pumpAndSettle();
    expect(find.textContaining('S2 episode 1'), findsOneWidget);
    expect(find.widgetWithText(SeasonSelector, 'Season 2'), findsOneWidget);
  });

  for (final size in const [Size(1280, 800), Size(400, 900)]) {
    testWidgets('${size.width}px: a season that fails keeps the selector', (
      tester,
    ) async {
      await setWindow(tester, size);
      failing.add(2);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(SeasonSelector));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Season 2').last);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(SeasonSelector, 'Season 2'), findsOneWidget);
      expect(find.textContaining('offline'), findsOneWidget);
      expect(find.textContaining('S1 episode 1'), findsNothing);

      await tester.tap(find.byType(SeasonSelector));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Season 1').last);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(SeasonSelector, 'Season 1'), findsOneWidget);
      expect(find.textContaining('S1 episode 1'), findsOneWidget);
    });
  }
}
