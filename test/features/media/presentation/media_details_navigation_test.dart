import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/settings/domain/user_settings.dart';
import 'package:cinemuse_app/features/streaming/unified_stream_resolver.dart';
import 'package:cinemuse_app/features/streaming/unified_stream_resolver_provider.dart';
import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:cinemuse_app/features/media/data/own_reviews_repository.dart';
import 'package:cinemuse_app/features/media/domain/episode_item.dart';
import 'package:cinemuse_app/features/media/domain/media_details_parts.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/own_review.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/profile/application/profile_providers.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/episodes/episode_carousel_card.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/cast_row.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/person_card.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/video_card.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/videos_row.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/hero/details_hero.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/episodes/episode_list_card.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/episodes/episode_carousel_row.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/hero/responsive_action_buttons.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:cinemuse_app/l10n/app_localizations_it.dart';
import 'package:cinemuse_app/shared/widgets/app_back_button.dart';
import 'package:cinemuse_app/shared/widgets/carousels/carousel_vertical_separator.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:cinemuse_app/shared/widgets/wreath.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/app_font.dart';
import '../../../helpers/cursor_helpers.dart';
import '../../../helpers/focus_helpers.dart';
import 'package:cinemuse_app/core/application/provider_retry.dart';

class MockUnifiedStreamResolver extends Mock implements UnifiedStreamResolver {}

class _MockOwnReviews extends Mock implements OwnReviewsRepository {}

class _FakeMovieLogs extends OptimisticMovieLogs {
  _FakeMovieLogs(super.tmdbId, this._logs);

  final List<WatchLog> _logs;

  @override
  Stream<List<WatchLog>> build() => Stream.value(_logs);
}

class FakeSettingsNotifier extends SettingsNotifier {
  FakeSettingsNotifier([this.initial = const UserSettings()]);

  final UserSettings initial;

  @override
  UserSettings build() => initial;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockUnifiedStreamResolver mockResolver;

  setUpAll(
    () => registerFallbackValue((tmdbId: 0, mediaType: MediaKind.movie)),
  );

  setUp(() {
    mockResolver = MockUnifiedStreamResolver();
    when(
      () => mockResolver.hasCachedStream(
        any(),
        any(),
        season: any(named: 'season'),
        episode: any(named: 'episode'),
      ),
    ).thenReturn(false);
  });

  Widget buildTestableWidget(
    Widget child, {
    List<dynamic> overrides = const [],
    Locale? locale,
  }) {
    return ProviderScope(
      retry: noProviderRetry,
      overrides: [
        unifiedStreamResolverProvider.overrideWithValue(mockResolver),
        settingsProvider.overrideWith(FakeSettingsNotifier.new),
        ...overrides.cast(),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );
  }

  group('Videos row', () {
    // Trailers the way TMDB sends them: newest first, languages mixed.
    MediaVideo video(String name, String language, {String type = 'Trailer'}) =>
        MediaVideo.fromTmdbMap({
          'key': name,
          'name': name,
          'site': 'YouTube',
          'type': type,
          'iso_639_1': language,
        });

    final mixed = [
      video('New Trailer', 'en'),
      video('Nuovo Trailer', 'it'),
      video('Behind the scenes', 'en', type: 'Featurette'),
      video('Official Trailer', 'en'),
      video('Trailer Ufficiale', 'it'),
    ];

    Future<void> pumpRow(
      WidgetTester tester,
      List<MediaVideo> videos,
      Locale locale,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1920, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        buildTestableWidget(VideosRow(videos: videos), locale: locale),
      );
      await tester.pump();
    }

    /// Fails unless [labels] are on screen, in this order from the left.
    void expectInOrder(WidgetTester tester, List<String> labels) {
      final lefts = [
        for (final l in labels) tester.getTopLeft(find.text(l)).dx,
      ];
      expect(lefts, [...lefts]..sort());
    }

    testWidgets('app in Italian: Italian trailers first, under separators', (
      tester,
    ) async {
      await pumpRow(tester, mixed, const Locale('it'));

      expectInOrder(tester, [
        'ITALIANO',
        'Nuovo Trailer',
        'Trailer Ufficiale',
        'INGLESE',
        'New Trailer',
        'Official Trailer',
      ]);
      expect(find.text('Behind the scenes'), findsNothing);
    });

    testWidgets('app in English: English trailers first', (tester) async {
      await pumpRow(tester, mixed, const Locale('en'));

      expectInOrder(tester, [
        'ENGLISH',
        'New Trailer',
        'Official Trailer',
        'ITALIAN',
        'Nuovo Trailer',
        'Trailer Ufficiale',
      ]);
    });

    testWidgets('only trailers in the other language: shown, no separator', (
      tester,
    ) async {
      await pumpRow(tester, [
        video('Official Trailer', 'en'),
      ], const Locale('it'));

      expect(find.text('Official Trailer'), findsOneWidget);
      expect(find.byType(CarouselVerticalSeparator), findsNothing);
    });

    testWidgets('only trailers in the app language: no separator', (
      tester,
    ) async {
      await pumpRow(tester, [
        video('Trailer Ufficiale', 'it'),
      ], const Locale('it'));

      expect(find.text('Trailer Ufficiale'), findsOneWidget);
      expect(find.byType(CarouselVerticalSeparator), findsNothing);
    });

    testWidgets(
      'the arrow keys go from Italian to English over the separator',
      (tester) async {
        await pumpRow(tester, [
          video('Trailer Ufficiale', 'it'),
          video('Official Trailer', 'en'),
        ], const Locale('it'));

        await tabTo(tester, find.text('Trailer Ufficiale'));
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();

        expect(
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<VideoCard>()
              ?.name,
          'Official Trailer',
        );
      },
    );

    testWidgets('as a list: going down, Italian first, under headings', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        buildTestableWidget(
          VideosRow(videos: mixed, asList: true),
          locale: const Locale('it'),
        ),
      );
      await tester.pump();

      final tops = [
        for (final l in [
          'ITALIANO',
          'Nuovo Trailer',
          'Trailer Ufficiale',
          'INGLESE',
          'New Trailer',
          'Official Trailer',
        ])
          tester.getTopLeft(find.text(l)).dy,
      ];
      expect(tops, [...tops]..sort());
      expect(find.byType(VideoListTile), findsNWidgets(4));
      expect(find.byType(VideoCard), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Cast as a list', () {
    testWidgets('crew then cast, going down, under headings', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        buildTestableWidget(
          const CastRow(
            asList: true,
            crew: [
              CrewMember(
                id: 1,
                name: 'Ada Regista',
                job: 'Director',
                department: 'Directing',
              ),
            ],
            cast: [
              CastMember(id: 2, name: 'Bruno Attore', character: 'Il conte'),
              CastMember(
                id: 3,
                name: 'Carla Attrice',
                character: 'La contessa',
              ),
            ],
          ),
          locale: const Locale('it'),
        ),
      );
      await tester.pump();

      final l10n = AppLocalizationsIt();
      final tops = [
        for (final l in [
          l10n.detailsSectionCrew,
          'Ada Regista',
          l10n.detailsSectionCast,
          'Bruno Attore',
          'Carla Attrice',
        ])
          tester.getTopLeft(find.text(l)).dy,
      ];
      expect(tops, [...tops]..sort());
      expect(find.byType(PersonListTile), findsNWidgets(3));
      expect(find.byType(PersonCard), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a person line activates via Enter', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        buildTestableWidget(
          PersonListTile(
            name: 'Actor Name',
            character: 'Hero',
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tabTo(tester, find.text('Actor Name'));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('a trailer line activates via Enter', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        buildTestableWidget(
          VideoListTile(
            youtubeKey: 'test_key',
            name: 'Official Trailer',
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tabTo(tester, find.text('Official Trailer'));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });
  });

  group('Details Page Navigation Tests', () {
    // REV-235: the back arrow was hidden on PC (Big Picture leftover).
    testWidgets('AppBackButton is shown on a widescreen window', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildTestableWidget(
          DetailsHero(
            mediaItem: MediaItem(
              tmdbId: 123,
              mediaType: MediaKind.movie,
              titleEn: 'Test Movie',
              updatedAt: DateTime(2026),
            ),
            onPlayClick: () {},
            onListTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppBackButton), findsOneWidget);
    });

    // REV-215: the hero title was always the English one.
    const titleCases = [
      (
        language: 'it',
        shown: 'Le ali della libertà',
        hidden: 'The Shawshank Redemption',
      ),
      (
        language: 'en',
        shown: 'The Shawshank Redemption',
        hidden: 'Le ali della libertà',
      ),
    ];
    for (final c in titleCases) {
      testWidgets('hero title follows the app language: ${c.language}', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          ProviderScope(
            retry: noProviderRetry,
            overrides: [
              unifiedStreamResolverProvider.overrideWithValue(mockResolver),
              settingsProvider.overrideWith(
                () =>
                    FakeSettingsNotifier(UserSettings(appLanguage: c.language)),
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: DetailsHero(
                  mediaItem: MediaItem(
                    tmdbId: 278,
                    mediaType: MediaKind.movie,
                    titleEn: 'The Shawshank Redemption',
                    titleIt: 'Le ali della libertà',
                    updatedAt: DateTime(2026),
                  ),
                  onPlayClick: () {},
                  onListTap: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(c.shown), findsOneWidget);
        expect(find.text(c.hidden), findsNothing);
      });
    }

    // REV-219 (b): the chevron was a second focus stop and its popup key
    // was new on every build.
    testWidgets('Play chevron is not a focus stop and opens the menu', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        buildTestableWidget(
          ResponsiveActionButtons(
            onPlayClick: () {},
            playButtonLabel: 'Play Now',
            mediaItem: MediaItem(
              tmdbId: 123,
              mediaType: MediaKind.movie,
              updatedAt: DateTime(2026),
            ),
            isFavorite: false,
            isInWatchlist: false,
            onListTap: () {},
            onDropClick: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final focused = FocusManager.instance.primaryFocus!.context!.widget;
      expect(
        find.descendant(
          of: find.byType(PopupMenuButton<int>),
          matching: find.byWidget(focused),
        ),
        findsNothing,
      );

      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.pumpAndSettle();
      expect(find.text('Stop Watching'), findsOneWidget);
    });

    // REV-284: holding Enter on Play pressed Play instead of opening its menu.
    testWidgets('holding Enter on Play opens its menu, a press plays', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var plays = 0;
      var drops = 0;
      await tester.pumpWidget(
        buildTestableWidget(
          ResponsiveActionButtons(
            onPlayClick: () => plays++,
            playButtonLabel: 'Play Now',
            mediaItem: MediaItem(
              tmdbId: 123,
              mediaType: MediaKind.movie,
              updatedAt: DateTime(2026),
            ),
            isFavorite: false,
            isInWatchlist: false,
            onListTap: () {},
            onDropClick: () => drops++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(plays, 1);
      expect(find.text('Stop Watching'), findsNothing);

      // A held key sends repeats until it is released.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 60));
        await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.text('Stop Watching'), findsOneWidget);
      expect(plays, 1);
      expect(drops, 0);
    });

    // REV-287: while the watch count loaded, a watched title said "Track".
    for (final kind in [MediaKind.movie, MediaKind.tv]) {
      testWidgets('Track shows a spinner while the ${kind.name} count loads', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var tracks = 0;
        await tester.pumpWidget(
          buildTestableWidget(
            ResponsiveActionButtons(
              onPlayClick: () {},
              playButtonLabel: 'Play Now',
              mediaItem: MediaItem(
                tmdbId: 123,
                mediaType: kind,
                updatedAt: DateTime(2026),
              ),
              isFavorite: false,
              isInWatchlist: false,
              onListTap: () {},
              onTrackTap: () => tracks++,
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Track').hitTestable(), findsNothing);
        await tester.tap(find.byType(CircularProgressIndicator));
        expect(tracks, 0);
      });
    }

    // REV-246: the ▾ next to Play showed the arrow cursor.
    testWidgets('Play ▾: the hand', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        buildTestableWidget(
          ResponsiveActionButtons(
            onPlayClick: () {},
            playButtonLabel: 'Play Now',
            mediaItem: MediaItem(
              tmdbId: 123,
              mediaType: MediaKind.movie,
              updatedAt: DateTime(2026),
            ),
            isFavorite: false,
            isInWatchlist: false,
            onListTap: () {},
            onDropClick: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectHandOver(tester, find.byIcon(Icons.keyboard_arrow_down));
    });

    // REV-253: the ▾ next to Play has a tooltip in the app's language.
    for (final (locale, l10n) in [
      (const Locale('en'), AppLocalizationsEn()),
      (const Locale('it'), AppLocalizationsIt()),
    ]) {
      testWidgets('Play ▾ tooltip in ${locale.languageCode}', (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          buildTestableWidget(
            ResponsiveActionButtons(
              onPlayClick: () {},
              playButtonLabel: 'Play Now',
              mediaItem: MediaItem(
                tmdbId: 123,
                mediaType: MediaKind.movie,
                updatedAt: DateTime(2026),
              ),
              isFavorite: false,
              isInWatchlist: false,
              onListTap: () {},
              onDropClick: () {},
            ),
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byTooltip(l10n.menuMoreOptions), findsOneWidget);
      });
    }

    // REV-219 (c): no date drew an empty text and a leading "•".
    testWidgets('hero info line has no leading dot without a date', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        buildTestableWidget(
          DetailsHero(
            mediaItem: MediaItem(
              tmdbId: 1,
              mediaType: MediaKind.movie,
              titleEn: 'No Date',
              voteAverage: 7.5,
              updatedAt: DateTime(2026),
            ),
            onPlayClick: () {},
            onListTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('7.5'), findsOneWidget);
      expect(find.text('•'), findsNothing);
    });

    group('your own score', () {
      setUpAll(loadAppFont);

      Future<void> pumpHero(
        WidgetTester tester, {
        required List<WatchLog> logs,
        int? rating = 9,
        double? voteAverage = 8.1,
        Size size = const Size(1280, 800),
      }) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repository = _MockOwnReviews();
        when(() => repository.get(any(), any())).thenAnswer(
          (_) async => rating == null
              ? null
              : OwnReview(
                  tmdbId: 438631,
                  mediaType: MediaKind.movie,
                  rating: rating,
                  createdAt: DateTime.utc(2026),
                  updatedAt: DateTime.utc(2026),
                ),
        );
        await tester.pumpWidget(
          buildTestableWidget(
            DetailsHero(
              mediaItem: MediaItem(
                tmdbId: 438631,
                mediaType: MediaKind.movie,
                titleEn: 'Dune',
                releaseDate: DateTime(2021, 10, 22),
                runtimeMinutes: 155,
                voteAverage: voteAverage,
                updatedAt: DateTime(2026),
              ),
              onPlayClick: () {},
              onListTap: () {},
            ),
            overrides: [
              userIdProvider.overrideWithValue('user-1'),
              ownReviewsRepositoryProvider.overrideWithValue(repository),
              movieWatchLogsProvider.overrideWith2(
                (id) => _FakeMovieLogs(id, logs),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();
      }

      final watch = WatchLog(
        tmdbId: 438631,
        mediaType: MediaKind.movie,
        loggedAt: DateTime.utc(2026),
      );

      testWidgets('shows beside the general one, with no dot between them', (
        tester,
      ) async {
        await pumpHero(tester, logs: [watch]);

        expect(find.text('8.1'), findsOneWidget);
        expect(find.text('9'), findsOneWidget);
        expect(tester.widget<Wreath>(find.byType(Wreath)).score, 10);
        // Between the date, the length and the scores: not inside the scores.
        expect(find.text('•'), findsNWidgets(2));
        expect(
          tester.getTopLeft(find.text('9')).dx,
          greaterThan(tester.getTopLeft(find.text('8.1')).dx),
        );
      });

      testWidgets('not rated: only the general one', (tester) async {
        await pumpHero(tester, logs: [watch], rating: null);

        expect(find.text('8.1'), findsOneWidget);
        expect(find.byType(Wreath), findsNothing);
      });

      testWidgets('every watch removed: the rating is hidden', (tester) async {
        await pumpHero(tester, logs: const []);

        expect(find.byType(Wreath), findsNothing);
      });

      testWidgets('no general score: yours shows alone', (tester) async {
        await pumpHero(tester, logs: [watch], voteAverage: null);

        expect(find.text('9'), findsOneWidget);
        expect(find.byIcon(Icons.star), findsNothing);
        expect(find.text('•'), findsNWidgets(2));
      });

      testWidgets('a screen reader says the score, not the full wreath', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await pumpHero(tester, logs: [watch]);

        expect(find.bySemanticsLabel('Score 9 out of 10'), findsOneWidget);
        expect(find.bySemanticsLabel('Score 10 out of 10'), findsNothing);
        semantics.dispose();
      });

      testWidgets('the remote skips it: the score takes no focus', (
        tester,
      ) async {
        await pumpHero(tester, logs: [watch]);

        expect(
          find.ancestor(
            of: find.byType(Wreath),
            matching: find.byType(DpadFocusable),
          ),
          findsNothing,
        );
      });

      testWidgets('the narrowest phone: the two scores stay on one line', (
        tester,
      ) async {
        await pumpHero(tester, logs: [watch], size: const Size(320, 800));

        expect(tester.takeException(), isNull);
        expect(
          tester.getCenter(find.text('9')).dy,
          tester.getCenter(find.text('8.1')).dy,
        );
      });
    });

    testWidgets(
      'ResponsiveActionButtons primary play button receives autofocus',
      (tester) async {
        bool playClicked = false;
        final mediaItem = MediaItem(
          tmdbId: 123,
          mediaType: MediaKind.movie,
          updatedAt: DateTime.now(),
        );

        await tester.pumpWidget(
          buildTestableWidget(
            ResponsiveActionButtons(
              onPlayClick: () => playClicked = true,
              playButtonLabel: 'Play Now',
              mediaItem: mediaItem,
              isFavorite: false,
              isInWatchlist: false,
              onListTap: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify that pressing Enter triggers the play button via autofocus
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        expect(playClicked, isTrue);
      },
    );

    testWidgets('EpisodeListCard is focusable and activates via D-Pad Enter', (
      tester,
    ) async {
      bool episodeTapped = false;
      final episode = EpisodeItem(
        episodeNumber: 1,
        seasonNumber: 1,
        name: 'Pilot',
        overview: 'The pilot episode.',
      );

      await tester.pumpWidget(
        buildTestableWidget(
          EpisodeListCard(
            episode: episode,
            seasonNumber: 1,
            mediaId: '123',
            isWatched: false,
            watchCount: 0,
            onEpisodeTap: (s, e, n, {restart = false}) => episodeTapped = true,
            onTrackOptions: (_, _) {},
            onFindMissingPreceding: (_, _) => [],
            onShowMarkPrecedingModal: (_, _, _) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tabTo(tester, find.text('Pilot'));

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();

      expect(episodeTapped, isTrue);
    });

    testWidgets(
      'PersonCard is focusable with DpadFocusable and activates via Enter',
      (tester) async {
        bool personTapped = false;

        await tester.pumpWidget(
          buildTestableWidget(
            PersonCard(
              name: 'Actor Name',
              character: 'Hero',
              onTap: () => personTapped = true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tabTo(tester, find.text('Actor Name'));

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        expect(personTapped, isTrue);
      },
    );

    testWidgets(
      'VideoCard is focusable with DpadFocusable and activates via Enter',
      (tester) async {
        bool videoTapped = false;

        await tester.pumpWidget(
          buildTestableWidget(
            VideoCard(
              youtubeKey: 'test_key',
              name: 'Official Trailer',
              onTap: () => videoTapped = true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tabTo(tester, find.text('Official Trailer'));

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        expect(videoTapped, isTrue);
      },
    );

    testWidgets(
      'EpisodeCarouselCard is focusable with DpadFocusable and activates via Enter',
      (tester) async {
        bool episodeTapped = false;
        final episode = EpisodeItem(
          episodeNumber: 3,
          seasonNumber: 2,
          name: 'The Great Escape',
          airDate: DateTime.parse('2024-05-12'),
          runtime: 52,
        );

        await tester.pumpWidget(
          buildTestableWidget(
            EpisodeCarouselCard(
              episode: episode,
              seasonNumber: 2,
              mediaId: '456',
              onEpisodeTap: (s, e, n, {restart = false}) =>
                  episodeTapped = true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('3. The Great Escape'), findsOneWidget);
        expect(find.text('EP 3'), findsOneWidget);
        expect(find.text('52m'), findsOneWidget);

        await tabTo(tester, find.text('3. The Great Escape'));

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        expect(episodeTapped, isTrue);
      },
    );

    testWidgets(
      'EpisodeCarouselRow renders horizontal episodes with season selector header',
      (tester) async {
        final episodes = [
          EpisodeItem(episodeNumber: 1, seasonNumber: 1, name: 'Episode 1'),
          EpisodeItem(episodeNumber: 2, seasonNumber: 1, name: 'Episode 2'),
        ];

        await tester.pumpWidget(
          buildTestableWidget(
            EpisodeCarouselRow(
              episodes: episodes,
              seasonNumber: 1,
              mediaId: '789',
              seasonSelector: const Text('Season 1 Selector'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Season 1 Selector'), findsOneWidget);
        expect(find.text('1. Episode 1'), findsOneWidget);
        expect(find.text('2. Episode 2'), findsOneWidget);
        expect(find.byType(EpisodeCarouselCard), findsNWidgets(2));
      },
    );

    testWidgets(
      'ResponsiveActionButtons play button keeps focus on arrowLeft',
      (tester) async {
        final mediaItem = MediaItem(
          tmdbId: 123,
          mediaType: MediaKind.movie,
          updatedAt: DateTime.now(),
        );

        await tester.pumpWidget(
          buildTestableWidget(
            ResponsiveActionButtons(
              mediaId: '123',
              mediaType: 'movie',
              mediaItem: mediaItem,
              onPlayClick: () {},
              onRestartClick: () {},
              playButtonLabel: 'Play',
              isFavorite: false,
              isInWatchlist: false,
              onListTap: () {},
              onTrackTap: () {},
              movieWatchCount: 0,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final focusBefore = FocusManager.instance.primaryFocus;
        expect(focusBefore, isNotNull);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();

        expect(FocusManager.instance.primaryFocus, focusBefore);
      },
    );

    testWidgets(
      'GenericCarouselRow arrowLeft at index > 0 moves to the previous card',
      (tester) async {
        final episodes = [
          EpisodeItem(episodeNumber: 1, seasonNumber: 1, name: 'Episode 1'),
          EpisodeItem(episodeNumber: 2, seasonNumber: 1, name: 'Episode 2'),
        ];

        await tester.pumpWidget(
          buildTestableWidget(
            EpisodeCarouselRow(
              episodes: episodes,
              seasonNumber: 1,
              mediaId: '789',
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tabTo(tester, find.text('1. Episode 1'));

        // Navigate right to the second card
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(isFocused(find.text('2. Episode 2')), isTrue);

        // Press arrowLeft from the second card: back to the first
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();

        expect(isFocused(find.text('1. Episode 1')), isTrue);
      },
    );

    testWidgets(
      'GenericCarouselRow arrowLeft at index 0 keeps focus on the first card',
      (tester) async {
        final episodes = [
          EpisodeItem(episodeNumber: 1, seasonNumber: 1, name: 'Episode 1'),
          EpisodeItem(episodeNumber: 2, seasonNumber: 1, name: 'Episode 2'),
        ];

        await tester.pumpWidget(
          buildTestableWidget(
            EpisodeCarouselRow(
              episodes: episodes,
              seasonNumber: 1,
              mediaId: '789',
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tabTo(tester, find.text('1. Episode 1'));

        // Press arrowLeft from the first card: focus must not escape the row
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();

        expect(isFocused(find.text('1. Episode 1')), isTrue);
      },
    );

    testWidgets(
      'ResponsiveActionButtons renders comment button and triggers onCommentsTap',
      (tester) async {
        bool commentsTapped = false;
        final mediaItem = MediaItem(
          tmdbId: 123,
          mediaType: MediaKind.movie,
          updatedAt: DateTime.now(),
        );

        await tester.pumpWidget(
          buildTestableWidget(
            ResponsiveActionButtons(
              onPlayClick: () {},
              playButtonLabel: 'Play',
              mediaItem: mediaItem,
              isFavorite: false,
              isInWatchlist: false,
              onListTap: () {},
              onTrackTap: () {},
              movieWatchCount: 0,
              onCommentsTap: () => commentsTapped = true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final commentButtonFinder = find.byIcon(Icons.chat_bubble_outline);
        expect(commentButtonFinder, findsOneWidget);

        await tester.tap(commentButtonFinder);
        await tester.pumpAndSettle();

        expect(commentsTapped, isTrue);
      },
    );
  });
}
