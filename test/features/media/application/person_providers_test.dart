import 'dart:async';

import 'package:cinemuse_app/features/media/application/person_providers.dart';
import 'package:cinemuse_app/features/media/application/watch_history_store.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/person.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// REV-212: the person page's data now lives in autoDispose providers.
void main() {
  final person = PersonDetails(
    id: 7,
    name: 'Someone',
    cast: [
      PersonCredit(
        id: 603,
        mediaType: MediaKind.movie,
        title: 'The Matrix',
        releaseDate: DateTime(1999),
        voteCount: 100,
      ),
      PersonCredit(
        id: 1,
        mediaType: MediaKind.movie,
        title: 'The Oscars',
        releaseDate: DateTime(2010),
      ),
    ],
  );

  late StreamController<Map<String, WatchHistory>> history;
  late int detailLoads;
  late ProviderContainer container;

  setUp(() {
    history = StreamController<Map<String, WatchHistory>>.broadcast();
    detailLoads = 0;
    container = ProviderContainer(
      overrides: [
        personDetailsProvider.overrideWith((ref, id) async {
          detailLoads++;
          return person;
        }),
        watchHistoryStoreProvider.overrideWith((ref) => history.stream),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await history.close();
  });

  test(
    'filmography follows "show hidden"; seen stats follow the history',
    () async {
      final stats = container.listen(personSeenStatsProvider(7), (_, __) {});
      final shown = container.listen(
        personFilmographyProvider((personId: 7, showHidden: false)),
        (_, __) {},
      );
      final all = container.listen(
        personFilmographyProvider((personId: 7, showHidden: true)),
        (_, __) {},
      );
      await container.read(personDetailsProvider(7).future);

      expect(shown.read().map((c) => c.title), ['The Matrix']);
      expect(all.read(), hasLength(2));
      expect(stats.read().watchedCount, 0);

      history.add({
        'movie-603': WatchHistory(
          userId: 'u',
          tmdbId: 603,
          mediaType: MediaKind.movie,
          lastWatchedAt: DateTime.utc(2026),
        ),
      });
      await pumpEventQueue();

      expect(stats.read().watchedCount, 1);
      expect(detailLoads, 1);
    },
  );

  test('the details are freed when nothing reads them', () async {
    final sub = container.listen(personDetailsProvider(7), (_, __) {});
    await container.read(personDetailsProvider(7).future);
    expect(container.exists(personDetailsProvider(7)), isTrue);

    sub.close();
    await pumpEventQueue();

    expect(container.exists(personDetailsProvider(7)), isFalse);
  });
}
