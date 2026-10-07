import 'package:cinemuse_app/core/application/display_mode_provider.dart';
import 'package:cinemuse_app/core/services/streaming/unified_stream_resolver.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/episode_thumbnail_card.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/person_card.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/video_card.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/details_hero.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/episode_card.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/episode_carousel_row.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/responsive_action_buttons.dart';
import 'package:cinemuse_app/features/navigation/nav_providers.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/app_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockUnifiedStreamResolver extends Mock implements UnifiedStreamResolver {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockUnifiedStreamResolver mockResolver;

  setUp(() {
    mockResolver = MockUnifiedStreamResolver();
    when(() => mockResolver.hasCachedStream(any(), any(),
        season: any(named: 'season'),
        episode: any(named: 'episode'))).thenReturn(false);
  });

  Widget buildTestableWidget(
    Widget child, {
    DisplayMode mode = DisplayMode.bigPicture,
    List<dynamic> overrides = const [],
  }) {
    return ProviderScope(
      key: ValueKey(mode),
      overrides: [
        displayModeProvider.overrideWith((ref) {
          final notifier = DisplayModeNotifier();
          notifier.setMode(mode);
          return notifier;
        }),
        unifiedStreamResolverProvider.overrideWithValue(mockResolver),
        ...overrides.cast(),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );
  }

  group('Details Page Big Picture Navigation Tests', () {
    testWidgets('AppBackButton is hidden in Big Picture mode and visible in standard mode',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          DetailsHero(
            media: const {'id': '123', 'type': 'movie', 'title': 'Test Movie'},
            details: const {'title': 'Test Movie'},
            onPlayClick: () {},
            onListTap: () {},
          ),
          mode: DisplayMode.bigPicture,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppBackButton), findsNothing);

      await tester.pumpWidget(
        buildTestableWidget(
          DetailsHero(
            media: const {'id': '123', 'type': 'movie', 'title': 'Test Movie'},
            details: const {'title': 'Test Movie'},
            onPlayClick: () {},
            onListTap: () {},
          ),
          mode: DisplayMode.standard,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppBackButton), findsOneWidget);
    });

    testWidgets('ResponsiveActionButtons primary play button receives autofocus',
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
    });

    testWidgets('EpisodeCard is focusable and activates via D-Pad Enter',
        (tester) async {
      bool episodeTapped = false;
      final episode = {
        'episode_number': 1,
        'name': 'Pilot',
        'overview': 'The pilot episode.',
      };

      await tester.pumpWidget(
        buildTestableWidget(
          EpisodeCard(
            episode: episode,
            seasonNumber: 1,
            media: const {'id': '123'},
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
        find.descendant(of: find.byType(EpisodeCard), matching: find.byType(Focus)).first,
      );
      focusWidget.focusNode?.requestFocus();
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();

      expect(episodeTapped, isTrue);
    });

    testWidgets('PersonCard is focusable with DpadFocusable and activates via Enter',
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
        find.descendant(of: find.byType(PersonCard), matching: find.byType(Focus)).first,
      );
      focusWidget.focusNode?.requestFocus();
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(personTapped, isTrue);
    });

    testWidgets('VideoCard is focusable with DpadFocusable and activates via Enter',
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
        find.descendant(of: find.byType(VideoCard), matching: find.byType(Focus)).first,
      );
      focusWidget.focusNode?.requestFocus();
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(videoTapped, isTrue);
    });

    testWidgets(
        'EpisodeThumbnailCard is focusable with DpadFocusable and activates via Enter',
        (tester) async {
      bool episodeTapped = false;
      final episode = {
        'episode_number': 3,
        'name': 'The Great Escape',
        'air_date': '2024-05-12',
        'runtime': 52,
      };

      await tester.pumpWidget(
        buildTestableWidget(
          EpisodeThumbnailCard(
            episode: episode,
            seasonNumber: 2,
            mediaId: '456',
            onTap: () => episodeTapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3. The Great Escape'), findsOneWidget);
      expect(find.text('EP 3'), findsOneWidget);
      expect(find.text('52m'), findsOneWidget);

      final focusWidget = tester.widget<Focus>(
        find.descendant(
          of: find.byType(EpisodeThumbnailCard),
          matching: find.byType(Focus),
        ).first,
      );
      focusWidget.focusNode?.requestFocus();
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(episodeTapped, isTrue);
    });

    testWidgets(
        'EpisodeCarouselRow renders horizontal episodes with season selector header',
        (tester) async {
      final episodes = [
        {'episode_number': 1, 'name': 'Episode 1'},
        {'episode_number': 2, 'name': 'Episode 2'},
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
      expect(find.byType(EpisodeThumbnailCard), findsNWidgets(2));
    });

    testWidgets(
        'ResponsiveActionButtons play button left key event invokes tvRailFocusActionProvider',
        (tester) async {
      bool railFocused = false;
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
          overrides: [
            tvRailFocusActionProvider.overrideWith((ref) => () => railFocused = true),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();

      expect(railFocused, isTrue);
    });

    testWidgets(
        'GenericCarouselRow arrowLeft at index > 0 does NOT invoke tvRailFocusActionProvider',
        (tester) async {
      bool railFocused = false;
      final episodes = [
        {'episode_number': 1, 'name': 'Episode 1'},
        {'episode_number': 2, 'name': 'Episode 2'},
      ];

      await tester.pumpWidget(
        buildTestableWidget(
          EpisodeCarouselRow(
            episodes: episodes,
            seasonNumber: 1,
            mediaId: '789',
          ),
          overrides: [
            tvRailFocusActionProvider.overrideWith((ref) => () => railFocused = true),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Focus the second card (index 1)
      final focusWidgets = tester.widgetList<Focus>(
        find.descendant(
          of: find.byType(EpisodeThumbnailCard),
          matching: find.byType(Focus),
        ),
      ).toList();
      // Wait for initial row focus (which focuses the first card at index 0)
      focusWidgets[0].focusNode?.requestFocus();
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus, focusWidgets[0].focusNode);

      // Navigate right to index 1
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus, focusWidgets[1].focusNode);

      // Press arrowLeft from index 1: should move focus to index 0, NOT invoke rail focus action
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();

      expect(FocusManager.instance.primaryFocus, focusWidgets[0].focusNode);
      expect(railFocused, isFalse);
    });

    testWidgets(
        'GenericCarouselRow arrowLeft at index 0 DOES invoke tvRailFocusActionProvider',
        (tester) async {
      bool railFocused = false;
      final episodes = [
        {'episode_number': 1, 'name': 'Episode 1'},
        {'episode_number': 2, 'name': 'Episode 2'},
      ];

      await tester.pumpWidget(
        buildTestableWidget(
          EpisodeCarouselRow(
            episodes: episodes,
            seasonNumber: 1,
            mediaId: '789',
          ),
          overrides: [
            tvRailFocusActionProvider.overrideWith((ref) => () => railFocused = true),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final focusWidgets = tester.widgetList<Focus>(
        find.descendant(
          of: find.byType(EpisodeThumbnailCard),
          matching: find.byType(Focus),
        ),
      ).toList();

      focusWidgets[0].focusNode?.requestFocus();
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus, focusWidgets[0].focusNode);

      // Press arrowLeft from index 0: MUST invoke rail focus action
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();

      expect(railFocused, isTrue);
    });

    testWidgets('ResponsiveActionButtons renders comment button and triggers onCommentsTap',
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
    });
  });
}
