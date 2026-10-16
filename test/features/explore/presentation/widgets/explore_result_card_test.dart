import 'dart:async';

import 'package:cinemuse_app/features/explore/presentation/widgets/explore_result_card.dart';
import 'package:cinemuse_app/features/explore/domain/explore_type.dart';
import 'package:cinemuse_app/features/media/application/person_providers.dart';
import 'package:cinemuse_app/features/media/application/watch_history_store.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/person.dart';
import 'package:cinemuse_app/features/media/presentation/media_details_screen.dart';
import 'package:cinemuse_app/features/media/presentation/person_details_screen.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/title_list_actions.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/media_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Remembers every route pushed, so a test can check where a tap went
/// without building the (network-heavy) details screen.
class _PushRecorder extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
  }
}

void main() {
  late _PushRecorder recorder;

  setUp(() => recorder = _PushRecorder());

  Widget buildCard(Map<String, dynamic> media, ExploreType type) {
    return ProviderScope(
      overrides: [
        // Keeps the person screen loading: no TMDB call in tests.
        personDetailsProvider.overrideWith(
          (ref, id) => Completer<PersonDetails?>().future,
        ),
        watchHistoryStoreProvider.overrideWith((ref) => Stream.value({})),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        navigatorObservers: [recorder],
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 360,
            child: ExploreResultCard(media: media, type: type),
          ),
        ),
      ),
    );
  }

  /// The screen a recorded route would show.
  Widget pushedScreen(WidgetTester tester) {
    final route = recorder.pushed.last as MaterialPageRoute<dynamic>;
    return route.builder(tester.element(find.byType(ExploreResultCard)));
  }

  const person = {'id': 287, 'name': 'Brad Pitt', 'profile_path': '/brad.jpg'};

  testWidgets('tapping a person opens the person screen', (tester) async {
    await tester.pumpWidget(buildCard(person, ExploreType.person));

    await tester.tap(find.byType(MediaCard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(PersonDetailsScreen), findsOneWidget);
    final screen = tester.widget<PersonDetailsScreen>(
      find.byType(PersonDetailsScreen),
    );
    expect(screen.personId, 287);
  });

  testWidgets('a person card is not a title: no watchlist or list options', (
    tester,
  ) async {
    await tester.pumpWidget(buildCard(person, ExploreType.person));

    final card = tester.widget<MediaCard>(find.byType(MediaCard));
    expect(card.listActions, isNull);

    await tester.longPress(find.byType(MediaCard));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(ExploreResultCard)),
    )!;
    expect(find.text(l10n.homeMoreInfo), findsOneWidget);
    expect(find.text(l10n.menuAddToWatchlist), findsNothing);
    expect(find.text(l10n.detailsAddToList), findsNothing);
  });

  testWidgets('tapping a TV show opens its details as tv', (tester) async {
    await tester.pumpWidget(
      buildCard({
        'id': 1399,
        'name': 'Game of Thrones',
        'poster_path': '/got.jpg',
        'first_air_date': '2011-04-17',
        'vote_average': 8.4,
      }, ExploreType.tv),
    );

    final card = tester.widget<MediaCard>(find.byType(MediaCard));
    final media = (card.listActions! as TitleListActions).media;
    expect(media.tmdbId, 1399);
    expect(media.mediaType, MediaKind.tv);

    // No pump after the tap: the details screen needs real services.
    await tester.tap(find.byType(MediaCard));

    final screen = pushedScreen(tester) as MediaDetailsScreen;
    expect(screen.mediaId, '1399');
    expect(screen.mediaType, 'tv');
  });
}
