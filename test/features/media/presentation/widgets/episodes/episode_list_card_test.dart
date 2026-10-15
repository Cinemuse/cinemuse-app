import 'package:cinemuse_app/features/media/domain/episode_item.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/episodes/episode_list_card.dart';
import 'package:cinemuse_app/features/streaming/unified_stream_resolver.dart';
import 'package:cinemuse_app/features/streaming/unified_stream_resolver_provider.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/focus_helpers.dart';
import '../../../../../helpers/menu_helpers.dart';

class _MockResolver extends Mock implements UnifiedStreamResolver {}

// REV-211: "Read more" was a plain GestureDetector: no remote or keyboard.
void main() {
  Widget card({
    String overview = 'A very long summary that goes on and on. ',
    int repeat = 12,
    double textScale = 1.0,
  }) {
    final resolver = _MockResolver();
    when(
      () => resolver.hasCachedStream(
        any(),
        any(),
        season: any(named: 'season'),
        episode: any(named: 'episode'),
      ),
    ).thenReturn(false);
    return ProviderScope(
      overrides: [unifiedStreamResolverProvider.overrideWithValue(resolver)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: EpisodeListCard(
              episode: EpisodeItem(
                episodeNumber: 1,
                seasonNumber: 1,
                name: 'Pilot',
                overview: overview * repeat,
              ),
              seasonNumber: 1,
              mediaId: '1429',
              isWatched: false,
              watchCount: 0,
              onTrackOptions: (_, _) {},
              onFindMissingPreceding: (_, _) => const [],
              onShowMarkPrecedingModal: (_, _, _) {},
            ),
          ),
        ),
      ),
    );
  }

  // REV-248: the right-click menu opened away from the pointer.
  group('the menu (REV-248)', () {
    Future<void> pumpWide(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(card(repeat: 1));
      await tester.pumpAndSettle();
    }

    testWidgets('right-click: it opens at the pointer', (tester) async {
      await pumpWide(tester);
      final cardRect = tester.getRect(find.byType(EpisodeListCard));
      final at = Offset(cardRect.width * 0.75, cardRect.center.dy);
      await rightClickAt(tester, at);

      expect(menuItems, findsWidgets);
      expectMenuAt(tester, at);
    });

    testWidgets('the ⋮ button: it opens under the button', (tester) async {
      await pumpWide(tester);
      final button = find.byTooltip('More Options');
      final buttonRect = tester.getRect(button);
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final first = tester.getRect(menuItems.first);
      expect(first.top - buttonRect.bottom, inInclusiveRange(0, 16));
      expect(
        first.left == buttonRect.left || first.right == buttonRect.right,
        isTrue,
        reason: 'menu $first, button $buttonRect',
      );
    });
  });

  Future<void> narrowWindow(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('"Read more": Enter expands, Enter again folds', (tester) async {
    await narrowWindow(tester);
    await tester.pumpWidget(card());
    await tester.pumpAndSettle();

    await tabTo(tester, find.text('Read more'));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Show less'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Read more'), findsOneWidget);
  });

  testWidgets('"Read more": taps expand and fold', (tester) async {
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

  // REV-214: "Read more" was measured at text size 1, so a summary cut only
  // by a bigger text size had no way to open it.
  testWidgets('text size 1.5: a summary cut at 2 lines shows "Read more"', (
    tester,
  ) async {
    await narrowWindow(tester);
    await tester.pumpWidget(card(overview: 'word ', repeat: 10));
    await tester.pumpAndSettle();
    expect(find.text('Read more'), findsNothing);

    await tester.pumpWidget(
      card(overview: 'word ', repeat: 10, textScale: 1.5),
    );
    await tester.pumpAndSettle();
    expect(find.text('Read more'), findsOneWidget);
  });
}
