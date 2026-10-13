import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/streaming/unified_stream_resolver.dart';
import 'package:cinemuse_app/features/streaming/unified_stream_resolver_provider.dart';
import 'package:cinemuse_app/features/media/domain/episode_item.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/episodes/episode_carousel_card.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/person_card.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/video_card.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/hero/details_hero.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/episodes/episode_list_card.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/episodes/episode_carousel_row.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/hero/responsive_action_buttons.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/app_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockUnifiedStreamResolver extends Mock implements UnifiedStreamResolver {}

class FakeSettingsNotifier extends SettingsNotifier {
  FakeSettingsNotifier([this.initial = const UserSettings()]);

  final UserSettings initial;

  @override
  UserSettings build() => initial;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockUnifiedStreamResolver mockResolver;

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
  }) {
    return ProviderScope(
      overrides: [
        unifiedStreamResolverProvider.overrideWithValue(mockResolver),
        settingsProvider.overrideWith(FakeSettingsNotifier.new),
        ...overrides.cast(),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );
  }

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
    testWidgets('hero title follows the app language', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            unifiedStreamResolverProvider.overrideWithValue(mockResolver),
            settingsProvider.overrideWith(
              () => FakeSettingsNotifier(const UserSettings(appLanguage: 'it')),
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

      expect(find.text('Le ali della libertà'), findsOneWidget);
      expect(find.text('The Shawshank Redemption'), findsNothing);
    });

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
            onTrackOptions: (_, __) {},
            onFindMissingPreceding: (_, __) => [],
            onShowMarkPrecedingModal: (_, __, ___) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final focusWidget = tester.widget<Focus>(
        find
            .descendant(
              of: find.byType(EpisodeListCard),
              matching: find.byType(Focus),
            )
            .first,
      );
      focusWidget.focusNode?.requestFocus();
      await tester.pumpAndSettle();

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

        final focusWidget = tester.widget<Focus>(
          find
              .descendant(
                of: find.byType(PersonCard),
                matching: find.byType(Focus),
              )
              .first,
        );
        focusWidget.focusNode?.requestFocus();
        await tester.pumpAndSettle();

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

        final focusWidget = tester.widget<Focus>(
          find
              .descendant(
                of: find.byType(VideoCard),
                matching: find.byType(Focus),
              )
              .first,
        );
        focusWidget.focusNode?.requestFocus();
        await tester.pumpAndSettle();

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

        final focusWidget = tester.widget<Focus>(
          find
              .descendant(
                of: find.byType(EpisodeCarouselCard),
                matching: find.byType(Focus),
              )
              .first,
        );
        focusWidget.focusNode?.requestFocus();
        await tester.pumpAndSettle();

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

        // Focus the second card (index 1)
        final focusWidgets = tester
            .widgetList<Focus>(
              find.descendant(
                of: find.byType(EpisodeCarouselCard),
                matching: find.byType(Focus),
              ),
            )
            .toList();
        // Wait for initial row focus (which focuses the first card at index 0)
        focusWidgets[0].focusNode?.requestFocus();
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus, focusWidgets[0].focusNode);

        // Navigate right to index 1
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus, focusWidgets[1].focusNode);

        // Press arrowLeft from index 1: should move focus to index 0
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();

        expect(FocusManager.instance.primaryFocus, focusWidgets[0].focusNode);
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

        final focusWidgets = tester
            .widgetList<Focus>(
              find.descendant(
                of: find.byType(EpisodeCarouselCard),
                matching: find.byType(Focus),
              ),
            )
            .toList();

        focusWidgets[0].focusNode?.requestFocus();
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus, focusWidgets[0].focusNode);

        // Press arrowLeft from index 0: focus must not escape the row
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();

        expect(FocusManager.instance.primaryFocus, focusWidgets[0].focusNode);
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
