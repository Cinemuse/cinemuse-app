import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:cinemuse_app/features/media/domain/comment.dart';
import 'package:cinemuse_app/features/media/domain/episode_item.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/collection_tile.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/comment_tile.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/episodes/episode_list_card.dart';
import 'package:cinemuse_app/features/streaming/unified_stream_resolver.dart';
import 'package:cinemuse_app/features/streaming/unified_stream_resolver_provider.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockResolver extends Mock implements UnifiedStreamResolver {}

// REV-211: the collection tile, the spoiler's "tap to reveal" and the
// episode "Read more" were plain GestureDetectors: no remote or keyboard.
void main() {
  Widget app(Widget child, {List<Override> overrides = const []}) =>
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      );

  /// Tabs until the control around [label] has the focus.
  Future<void> focusOn(WidgetTester tester, Finder label) async {
    final node = Focus.of(tester.element(label));
    for (var i = 0; i < 20 && !node.hasPrimaryFocus; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(node.hasPrimaryFocus, isTrue);
  }

  group('collection tile', () {
    late int opens;
    Widget tile() => app(
      const CollectionTile(
        collection: MediaCollection(
          id: 10,
          name: 'Star Wars Collection',
          parts: [],
        ),
      ),
      overrides: [
        collectionModelProvider.overrideWith((ref, id) async {
          opens++;
          return null;
        }),
      ],
    );

    setUp(() => opens = 0);

    testWidgets('Enter opens the collection', (tester) async {
      await tester.pumpWidget(tile());
      await focusOn(tester, find.text('Star Wars Collection'));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(opens, 1);
    });

    testWidgets('a tap opens the collection', (tester) async {
      await tester.pumpWidget(tile());
      await tester.tap(find.text('Star Wars Collection'));
      await tester.pumpAndSettle();
      expect(opens, 1);
    });
  });

  group('comment spoiler', () {
    late int reveals;
    Widget tile() => app(
      CommentTile(
        comment: const Comment(
          id: '1',
          author: CommentAuthor(id: 'a', username: 'someone'),
          text: 'Bruce Willis was dead all along',
          isSpoiler: true,
          source: CommentSource.imdb,
        ),
        isSpoilerRevealed: false,
        onRevealSpoiler: () => reveals++,
      ),
    );

    setUp(() => reveals = 0);

    testWidgets('Enter on "Tap to reveal" reveals it', (tester) async {
      await tester.pumpWidget(tile());
      await focusOn(tester, find.text('Tap to reveal'));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(reveals, 1);
    });

    testWidgets('a tap reveals it', (tester) async {
      await tester.pumpWidget(tile());
      await tester.tap(find.text('Tap to reveal'));
      await tester.pump();
      expect(reveals, 1);
    });
  });

  group('episode "Read more"', () {
    Widget card() {
      final resolver = _MockResolver();
      when(
        () => resolver.hasCachedStream(
          any(),
          any(),
          season: any(named: 'season'),
          episode: any(named: 'episode'),
        ),
      ).thenReturn(false);
      return app(
        EpisodeListCard(
          episode: EpisodeItem(
            episodeNumber: 1,
            seasonNumber: 1,
            name: 'Pilot',
            overview: 'A very long summary that goes on and on. ' * 12,
          ),
          seasonNumber: 1,
          mediaId: '1429',
          isWatched: false,
          watchCount: 0,
          onTrackOptions: (_, _) {},
          onFindMissingPreceding: (_, _) => const [],
          onShowMarkPrecedingModal: (_, _, _) {},
        ),
        overrides: [unifiedStreamResolverProvider.overrideWithValue(resolver)],
      );
    }

    Future<void> narrowWindow(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    testWidgets('Enter expands, Enter again folds', (tester) async {
      await narrowWindow(tester);
      await tester.pumpWidget(card());
      await tester.pumpAndSettle();

      await focusOn(tester, find.text('Read more'));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Show less'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Read more'), findsOneWidget);
    });

    testWidgets('taps expand and fold', (tester) async {
      await narrowWindow(tester);
      await tester.pumpWidget(card());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Read more'));
      await tester.pumpAndSettle();
      expect(find.text('Show less'), findsOneWidget);

      await tester.tap(find.text('Show less'));
      await tester.pumpAndSettle();
      expect(find.text('Read more'), findsOneWidget);
    });
  });
}
