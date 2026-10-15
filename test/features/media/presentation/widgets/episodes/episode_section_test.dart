import 'dart:async';

import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/services/system/supabase_service.dart';
import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/episodes/episode_carousel_card.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/episodes/episode_list_card.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/episodes/episode_section.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/episodes/season_selector.dart';
import 'package:cinemuse_app/features/streaming/unified_stream_resolver.dart';
import 'package:cinemuse_app/features/streaming/unified_stream_resolver_provider.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockResolver extends Mock implements UnifiedStreamResolver {}

class _MockWatchHistoryRepository extends Mock
    implements WatchHistoryRepository {}

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

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

  /// Signed in, the ticks saved through [repository] (else no ticks).
  List<Override> tracking(_MockWatchHistoryRepository repository) {
    final user = User(
      id: 'user-a',
      appMetadata: {},
      userMetadata: {},
      aud: '',
      createdAt: '',
    );
    final auth = _MockGoTrueClient();
    when(() => auth.currentUser).thenReturn(user);
    when(() => auth.currentSession).thenReturn(
      Session(accessToken: 'token', tokenType: 'bearer', user: user),
    );
    when(() => auth.onAuthStateChange).thenAnswer((_) => const Stream.empty());
    final client = _MockSupabaseClient();
    when(() => client.auth).thenReturn(auth);
    when(
      () => repository.watchTitleLogs(any(), any(), any()),
    ).thenAnswer((_) => Stream.value(const []));
    return [
      supabaseClientProvider.overrideWithValue(client),
      watchHistoryRepositoryProvider.overrideWithValue(repository),
      mediaDetailsProvider.overrideWith((ref, args) async => details),
    ];
  }

  Widget app({
    List<Override> signedIn = const [],
    Stream<Map<String, WatchHistory>>? progress,
  }) => ProviderScope(
    overrides: [
      ...signedIn,
      unifiedStreamResolverProvider.overrideWithValue(resolver),
      seasonDetailsProvider.overrideWith((ref, args) async {
        if (failing.contains(args.seasonNumber)) {
          throw const NetworkFailure('offline');
        }
        final completer = pending[args.seasonNumber];
        if (completer != null) return completer.future;
        return season(args.seasonNumber);
      }),
      if (signedIn.isEmpty)
        watchedEpisodesMapProvider.overrideWith((ref, id) => const {}),
      episodeProgressMapProvider.overrideWith(
        (ref, id) => progress ?? Stream.value(const {}),
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

  // REV-20: below 600 px the episodes are a list, from 600 px a carousel.
  for (final (width, isPhone) in const [(599.0, true), (600.0, false)]) {
    testWidgets('${width}px: episodes as a ${isPhone ? 'list' : 'carousel'}', (
      tester,
    ) async {
      await setWindow(tester, Size(width, 900));
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(
        find.byType(EpisodeListCard),
        isPhone ? findsNWidgets(2) : findsNothing,
      );
      expect(
        find.byType(EpisodeCarouselCard),
        isPhone ? findsNothing : findsNWidgets(2),
      );
    });
  }

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

  // REV-196, REV-298: a failed tick undid every pending episode of the show,
  // and no message said it failed.
  testWidgets('offline tick: an error, only that episode un-ticks', (
    tester,
  ) async {
    final l10n = AppLocalizationsEn();
    final markWatched = find.byTooltip(l10n.detailsTooltipMarkWatched);
    final watched = find.byTooltip(l10n.detailsTooltipWatched);
    final repository = _MockWatchHistoryRepository();
    final firstSave = Completer<void>();
    when(
      () => repository.logMultipleEpisodes(
        userId: any(named: 'userId'),
        tmdbId: any(named: 'tmdbId'),
        episodes: any(named: 'episodes'),
        seriesDetails: any(named: 'seriesDetails'),
        loggedAt: any(named: 'loggedAt'),
      ),
    ).thenAnswer((call) {
      final episodes =
          call.namedArguments[#episodes] as List<({int season, int episode})>;
      return episodes.single.episode == 1
          ? firstSave.future
          : Future.error(const NetworkFailure('offline'));
    });
    await setWindow(tester, const Size(400, 900));
    await tester.pumpWidget(app(signedIn: tracking(repository)));
    await tester.pumpAndSettle();
    expect(markWatched, findsNWidgets(2));

    // Episode 1 still saving when episode 2 fails.
    await tester.tap(markWatched.first);
    await tester.pump();
    await tester.tap(markWatched.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text(l10n.failureNetwork), findsOneWidget);
    expect(watched, findsOneWidget);
    expect(markWatched, findsOneWidget);
  });

  // REV-208: the "cached" dot was worked out once per card, so it was missing
  // after playing and stayed on the old episode when the card was reused.
  for (final size in const [Size(1280, 800), Size(400, 900)]) {
    testWidgets('${size.width}px: the cached dot shows at once, only on its '
        'episode, and the menu removes it', (tester) async {
      final l10n = AppLocalizationsEn();
      final cached = <(int?, int?)>{};
      (int?, int?) episodeOf(Invocation call) => (
        call.namedArguments[#season] as int?,
        call.namedArguments[#episode] as int?,
      );
      when(
        () => resolver.hasCachedStream(
          any(),
          any(),
          season: any(named: 'season'),
          episode: any(named: 'episode'),
        ),
      ).thenAnswer((call) => cached.contains(episodeOf(call)));
      when(
        () => resolver.clearCachedStream(
          any(),
          any(),
          season: any(named: 'season'),
          episode: any(named: 'episode'),
        ),
      ).thenAnswer((call) => cached.remove(episodeOf(call)));
      final progress = StreamController<Map<String, WatchHistory>>.broadcast();
      addTearDown(progress.close);
      final dot = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration ==
                const BoxDecoration(
                  color: AppTheme.accent,
                  shape: BoxShape.circle,
                ) &&
            w.constraints == const BoxConstraints.tightFor(width: 8, height: 8),
      );
      Finder dotOn(String episode) => find.descendant(
        of: find.ancestor(
          of: find.textContaining(episode),
          matching: find.byType(
            size.width < 600 ? EpisodeListCard : EpisodeCarouselCard,
          ),
        ),
        matching: dot,
      );
      Future<void> pickSeason(int n) async {
        await tester.tap(find.byType(SeasonSelector));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Season $n').last);
        await tester.pumpAndSettle();
      }

      await setWindow(tester, size);
      await tester.pumpWidget(app(progress: progress.stream));
      await tester.pumpAndSettle();
      expect(dot, findsNothing);

      // S1 E2 played: its stream is cached and the progress saved.
      cached.add((1, 2));
      progress.add(const {});
      await tester.pumpAndSettle();
      expect(dotOn('S1 episode 2'), findsOneWidget);
      expect(dot, findsOneWidget);

      await pickSeason(2);
      expect(dot, findsNothing);
      await pickSeason(1);
      expect(dotOn('S1 episode 2'), findsOneWidget);
      expect(dot, findsOneWidget);

      await tester.longPress(find.textContaining('S1 episode 2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.menuRemoveCachedProvider));
      await tester.pumpAndSettle();
      expect(cached, isEmpty);
      expect(dot, findsNothing);
    });
  }
}
