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

class _MockResolver extends Mock implements UnifiedStreamResolver {}

// REV-211: "Read more" was a plain GestureDetector: no remote or keyboard.
void main() {
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
    return ProviderScope(
      overrides: [unifiedStreamResolverProvider.overrideWithValue(resolver)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: EpisodeListCard(
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
          ),
        ),
      ),
    );
  }

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
}
