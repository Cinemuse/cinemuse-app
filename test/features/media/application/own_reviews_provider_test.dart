import 'dart:async';

import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:cinemuse_app/features/media/application/own_reviews_provider.dart';
import 'package:cinemuse_app/features/media/data/own_reviews_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/own_review.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/profile/application/profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockRepository extends Mock implements OwnReviewsRepository {}

class _FakeMovieLogs extends OptimisticMovieLogs {
  _FakeMovieLogs(super.tmdbId, this._logs);

  final List<WatchLog> _logs;

  @override
  Stream<List<WatchLog>> build() => Stream.value(_logs);
}

class _FakeSeriesLogs extends OptimisticSeriesLogs {
  _FakeSeriesLogs(super.tmdbId, this._logs);

  final List<WatchLog> _logs;

  @override
  Stream<List<WatchLog>> build() => Stream.value(_logs);
}

void main() {
  const userId = 'user-1';
  const dune = (tmdbId: 438631, mediaType: MediaKind.movie);
  const bakerStreet = (tmdbId: 438631, mediaType: MediaKind.tv);

  final review = OwnReview(
    tmdbId: dune.tmdbId,
    mediaType: dune.mediaType,
    rating: 9,
    text: 'Great',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 2),
  );
  final watch = WatchLog(
    tmdbId: dune.tmdbId,
    mediaType: dune.mediaType,
    loggedAt: DateTime.utc(2026, 1, 1),
  );

  late _MockRepository repository;

  setUpAll(() => registerFallbackValue(dune));

  ProviderContainer container({
    String? user = userId,
    List<WatchLog> movieLogs = const [],
    List<WatchLog> seriesLogs = const [],
  }) {
    final container = ProviderContainer(
      overrides: [
        userIdProvider.overrideWithValue(user),
        ownReviewsRepositoryProvider.overrideWithValue(repository),
        movieWatchLogsProvider.overrideWith2(
          (id) => _FakeMovieLogs(id, movieLogs),
        ),
        seriesWatchLogsProvider.overrideWith2(
          (id) => _FakeSeriesLogs(id, seriesLogs),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Keeps [provider] alive and waits for its first answer.
  Future<void> settle(
    ProviderContainer c,
    ProviderListenable<Object?> provider,
  ) async {
    final sub = c.listen(provider, (_, _) {});
    addTearDown(sub.close);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = _MockRepository();
    when(() => repository.get(any(), any())).thenAnswer((_) async => review);
    when(() => repository.getAll(any())).thenAnswer((_) async => [review]);
    when(() => repository.remove(any(), any())).thenAnswer((_) async {});
  });

  group('whether a title can be rated', () {
    test('a film with a finished watch can', () async {
      final c = container(movieLogs: [watch]);
      await settle(c, canRateTitleProvider(dune));
      expect(c.read(canRateTitleProvider(dune)), isTrue);
    });

    test('a series with one watched episode can', () async {
      final c = container(seriesLogs: [watch]);
      await settle(c, canRateTitleProvider(bakerStreet));
      expect(c.read(canRateTitleProvider(bakerStreet)), isTrue);
    });

    test('a film and a series with the same number are separate', () async {
      final c = container(seriesLogs: [watch]);
      await settle(c, canRateTitleProvider(dune));
      expect(c.read(canRateTitleProvider(dune)), isFalse);
    });

    test('a title not watched yet can\'t', () async {
      final c = container();
      await settle(c, canRateTitleProvider(dune));
      expect(c.read(canRateTitleProvider(dune)), isFalse);
    });
  });

  group('the rating a page shows', () {
    test('shows on a watched title', () async {
      final c = container(movieLogs: [watch]);
      await settle(c, visibleOwnReviewProvider(dune));
      expect(c.read(visibleOwnReviewProvider(dune)), review);
    });

    test('is hidden with every watch removed, but stays saved', () async {
      final c = container();
      await settle(c, visibleOwnReviewProvider(dune));
      expect(c.read(visibleOwnReviewProvider(dune)), isNull);
      await settle(c, ownReviewProvider(dune));
      expect(c.read(ownReviewProvider(dune)).value, review);
      verifyNever(() => repository.remove(any(), any()));
    });

    test('signed out asks nothing', () async {
      final c = container(user: null);
      await settle(c, ownReviewProvider(dune));
      expect(c.read(ownReviewProvider(dune)).value, isNull);
      verifyNever(() => repository.get(any(), any()));
    });

    test('a failed read is an error, not "no rating"', () async {
      when(
        () => repository.get(any(), any()),
      ).thenThrow(const NetworkFailure('offline'));
      final c = container(movieLogs: [watch]);
      await settle(c, ownReviewProvider(dune));
      expect(c.read(ownReviewProvider(dune)).hasError, isTrue);
    });
  });

  group('all the ratings', () {
    test('are found by the same key as the watch history', () async {
      final c = container();
      await settle(c, allOwnReviewsProvider);
      expect(c.read(allOwnReviewsProvider).value, {'movie-438631': review});
    });
  });

  group('saving', () {
    final saved = OwnReview(
      tmdbId: dune.tmdbId,
      mediaType: dune.mediaType,
      rating: 4,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 3, 3),
    );

    void answerSave() => when(
      () => repository.save(
        any(),
        any(),
        rating: any(named: 'rating'),
        text: any(named: 'text'),
      ),
    ).thenAnswer((_) async => saved);

    test('shows the new rating at once, with no second read', () async {
      answerSave();
      final c = container(movieLogs: [watch]);
      await settle(c, ownReviewProvider(dune));

      await c
          .read(ownReviewActionsProvider)
          .save(dune, rating: 4, text: 'Fine');

      expect(c.read(ownReviewProvider(dune)).value, saved);
      verify(() => repository.get(any(), any())).called(1);
      verify(
        () => repository.save(userId, dune, rating: 4, text: 'Fine'),
      ).called(1);
    });

    test('keeps the text exactly as typed', () async {
      answerSave();
      final c = container();

      await c
          .read(ownReviewActionsProvider)
          .save(dune, rating: 4, text: '  **a**\n');

      verify(
        () => repository.save(userId, dune, rating: 4, text: '  **a**\n'),
      ).called(1);
    });

    test('blank text counts as no review', () async {
      answerSave();
      final c = container();

      await c.read(ownReviewActionsProvider).save(dune, rating: 4, text: ' \n');

      verify(
        () => repository.save(userId, dune, rating: 4, text: null),
      ).called(1);
    });

    test('updates the Ratings view too', () async {
      answerSave();
      final c = container();
      await settle(c, allOwnReviewsProvider);

      await c.read(ownReviewActionsProvider).save(dune, rating: 4, text: '');
      await Future<void>.delayed(Duration.zero);

      verify(() => repository.getAll(userId)).called(2);
    });

    test('a failed save throws and leaves the old rating showing', () async {
      when(
        () => repository.save(
          any(),
          any(),
          rating: any(named: 'rating'),
          text: any(named: 'text'),
        ),
      ).thenThrow(const NetworkFailure('offline'));
      final c = container(movieLogs: [watch]);
      await settle(c, ownReviewProvider(dune));

      await expectLater(
        c.read(ownReviewActionsProvider).save(dune, rating: 4, text: ''),
        throwsA(isA<NetworkFailure>()),
      );

      expect(c.read(ownReviewProvider(dune)).value, review);
    });

    test('signed out is refused', () async {
      final c = container(user: null);

      await expectLater(
        c.read(ownReviewActionsProvider).save(dune, rating: 4, text: ''),
        throwsA(isA<AuthFailure>()),
      );
    });
  });

  group('removing', () {
    setUpAll(() => registerFallbackValue(review));

    setUp(() {
      when(() => repository.restore(any(), any())).thenAnswer((_) async {});
    });

    test('happens at once, before the Undo message closes', () async {
      final undone = Completer<bool>();
      final c = container(movieLogs: [watch]);
      await settle(c, ownReviewProvider(dune));

      unawaited(
        c
            .read(ownReviewActionsProvider)
            .removeWithUndo(review, undone: undone.future),
      );
      await Future<void>.delayed(Duration.zero);

      verify(() => repository.remove(userId, dune)).called(1);
      expect(c.read(ownReviewProvider(dune)).value, isNull);
      undone.complete(false);
    });

    test('without Undo it stays removed', () async {
      final c = container(movieLogs: [watch]);
      await settle(c, ownReviewProvider(dune));

      await c
          .read(ownReviewActionsProvider)
          .removeWithUndo(review, undone: Future.value(false));

      verifyNever(() => repository.restore(any(), any()));
      expect(c.read(ownReviewProvider(dune)).value, isNull);
    });

    test('Undo puts back the same rating, score and text', () async {
      final c = container(movieLogs: [watch]);
      await settle(c, ownReviewProvider(dune));

      await c
          .read(ownReviewActionsProvider)
          .removeWithUndo(review, undone: Future.value(true));

      verify(() => repository.restore(userId, review)).called(1);
      expect(c.read(ownReviewProvider(dune)).value, review);
    });

    test('Undo still works after every page has closed', () async {
      final undone = Completer<bool>();
      final c = container(movieLogs: [watch]);
      final page = c.listen(ownReviewProvider(dune), (_, _) {});
      await Future<void>.delayed(Duration.zero);

      final removal = c
          .read(ownReviewActionsProvider)
          .removeWithUndo(review, undone: undone.future);
      await Future<void>.delayed(Duration.zero);
      page.close();
      await Future<void>.delayed(Duration.zero);
      undone.complete(true);
      await removal;

      verify(() => repository.restore(userId, review)).called(1);
    });

    test('a failed removal throws and keeps the rating', () async {
      when(
        () => repository.remove(any(), any()),
      ).thenThrow(const NetworkFailure('offline'));
      final c = container(movieLogs: [watch]);
      await settle(c, ownReviewProvider(dune));

      await expectLater(
        c
            .read(ownReviewActionsProvider)
            .removeWithUndo(review, undone: Future.value(false)),
        throwsA(isA<NetworkFailure>()),
      );

      expect(c.read(ownReviewProvider(dune)).value, review);
    });
  });

  group('unsaved text', () {
    const draft = OwnReviewDraft(rating: 7, text: 'A long text');

    setUpAll(() => registerFallbackValue(review));

    setUp(() {
      when(() => repository.restore(any(), any())).thenAnswer((_) async {});
      when(
        () => repository.save(
          any(),
          any(),
          rating: any(named: 'rating'),
          text: any(named: 'text'),
        ),
      ).thenAnswer((_) async => review);
    });

    Future<OwnReviewDraft?> load(ProviderContainer c) =>
        c.read(ownReviewActionsProvider).loadDraft(dune, saved: review);

    Future<void> keep(ProviderContainer c) =>
        c.read(ownReviewActionsProvider).keepDraft(dune, draft, saved: review);

    test('comes back the next time the app opens', () async {
      await keep(container());

      expect(await load(container()), draft);
    });

    test('belongs to one title', () async {
      final c = container();
      await keep(c);

      expect(
        await c
            .read(ownReviewActionsProvider)
            .loadDraft(bakerStreet, saved: null),
        isNull,
      );
    });

    test('belongs to one account', () async {
      await keep(container());

      expect(await load(container(user: 'someone-else')), isNull);
    });

    test('text that says the same as the saved rating isn\'t kept', () async {
      final c = container();
      await keep(c);
      await c
          .read(ownReviewActionsProvider)
          .keepDraft(
            dune,
            OwnReviewDraft(rating: review.rating, text: review.text!),
            saved: review,
          );

      expect(await load(c), isNull);
    });

    test('a copy that now says what was saved elsewhere is dropped', () async {
      final c = container();
      await keep(c);
      final sameAsNow = OwnReview(
        tmdbId: dune.tmdbId,
        mediaType: dune.mediaType,
        rating: draft.rating,
        text: draft.text,
        createdAt: review.createdAt,
        updatedAt: review.updatedAt,
      );

      expect(
        await c
            .read(ownReviewActionsProvider)
            .loadDraft(dune, saved: sameAsNow),
        isNull,
      );
      expect(await load(c), isNull);
    });

    test('Save deletes it', () async {
      final c = container();
      await keep(c);

      await c.read(ownReviewActionsProvider).save(dune, rating: 7, text: 'a');

      expect(await load(c), isNull);
    });

    test('a failed Save keeps it', () async {
      when(
        () => repository.save(
          any(),
          any(),
          rating: any(named: 'rating'),
          text: any(named: 'text'),
        ),
      ).thenThrow(const NetworkFailure('offline'));
      final c = container();
      await keep(c);

      await expectLater(
        c.read(ownReviewActionsProvider).save(dune, rating: 7, text: 'a'),
        throwsA(isA<NetworkFailure>()),
      );

      expect(await load(c), draft);
    });

    test('Remove deletes it, and Undo doesn\'t bring it back', () async {
      final c = container();
      await keep(c);

      await c
          .read(ownReviewActionsProvider)
          .removeWithUndo(review, undone: Future.value(true));

      expect(await load(c), isNull);
    });

    test('a failed Remove keeps it', () async {
      when(
        () => repository.remove(any(), any()),
      ).thenThrow(const NetworkFailure('offline'));
      final c = container();
      await keep(c);

      await expectLater(
        c
            .read(ownReviewActionsProvider)
            .removeWithUndo(review, undone: Future.value(false)),
        throwsA(isA<NetworkFailure>()),
      );

      expect(await load(c), draft);
    });

    group('discarded', () {
      test('stays until the message closes', () async {
        final undone = Completer<bool>();
        final c = container();
        await keep(c);

        final discard = c
            .read(ownReviewActionsProvider)
            .discardDraftWithUndo(dune, undone: undone.future);
        await Future<void>.delayed(Duration.zero);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getKeys(), hasLength(1));

        undone.complete(false);
        await discard;
        expect(prefs.getKeys(), isEmpty);
      });

      test('Undo keeps it', () async {
        final c = container();
        await keep(c);

        await c
            .read(ownReviewActionsProvider)
            .discardDraftWithUndo(dune, undone: Future.value(true));

        expect(await load(c), draft);
      });

      test('opening the editor during the message keeps it', () async {
        final undone = Completer<bool>();
        final c = container();
        await keep(c);

        final discard = c
            .read(ownReviewActionsProvider)
            .discardDraftWithUndo(dune, undone: undone.future);
        await Future<void>.delayed(Duration.zero);
        expect(await load(c), draft);

        undone.complete(false);
        await discard;

        expect(await load(c), draft);
      });

      test('a second discard is the one that counts', () async {
        final first = Completer<bool>();
        final second = Completer<bool>();
        final c = container();
        final actions = c.read(ownReviewActionsProvider);
        await keep(c);

        final discards = [
          actions.discardDraftWithUndo(dune, undone: first.future),
          actions.discardDraftWithUndo(dune, undone: second.future),
        ];
        // The second message replacing the first closes the first.
        first.complete(false);
        await discards.first;
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getKeys(), hasLength(1));

        second.complete(true);
        await discards.last;
        expect(await load(c), draft);
      });
    });
  });
}
