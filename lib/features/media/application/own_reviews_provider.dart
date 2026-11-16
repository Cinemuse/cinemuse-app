import 'dart:async';

import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:cinemuse_app/features/media/data/own_review_draft_storage.dart';
import 'package:cinemuse_app/features/media/data/own_reviews_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/own_review.dart';
import 'package:cinemuse_app/features/profile/application/profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The user's saved rating of one title, read each time a page opens it: the
/// table doesn't stream, so another device's rating shows on the next opening.
/// It ignores whether the title was watched; [visibleOwnReviewProvider] doesn't.
final ownReviewProvider = AsyncNotifierProvider.autoDispose
    .family<OwnReviewNotifier, OwnReview?, RatedTitle>(OwnReviewNotifier.new);

class OwnReviewNotifier extends AsyncNotifier<OwnReview?> {
  OwnReviewNotifier(this.title);

  final RatedTitle title;

  @override
  Future<OwnReview?> build() async {
    final userId = ref.watch(userIdProvider);
    if (userId == null) return null;
    return ref.watch(ownReviewsRepositoryProvider).get(userId, title);
  }

  /// What was just saved or removed, so the page needn't read it again.
  void show(OwnReview? review) => state = AsyncData(review);
}

/// All the user's ratings by `titleKey`, for the Ratings view.
final allOwnReviewsProvider =
    FutureProvider.autoDispose<Map<String, OwnReview>>((ref) async {
      final userId = ref.watch(userIdProvider);
      if (userId == null) return const {};
      final reviews = await ref
          .watch(ownReviewsRepositoryProvider)
          .getAll(userId);
      return {for (final review in reviews) review.titleKey: review};
    });

/// Whether the user can rate [RatedTitle]: a film with a finished watch, a
/// series with a watched episode. Null while that isn't known yet.
final canRateTitleProvider = Provider.autoDispose.family<bool?, RatedTitle>((
  ref,
  title,
) {
  final logs = title.mediaType == MediaKind.tv
      ? ref.watch(seriesWatchLogsProvider(title.tmdbId))
      : ref.watch(movieWatchLogsProvider(title.tmdbId));
  return logs.value?.isNotEmpty;
});

/// The rating a page shows: once every watch of a title is removed its rating
/// is kept but hidden, and comes back when the title is watched again.
final visibleOwnReviewProvider = Provider.autoDispose
    .family<OwnReview?, RatedTitle>((ref, title) {
      if (ref.watch(canRateTitleProvider(title)) != true) return null;
      return ref.watch(ownReviewProvider(title)).value;
    });

/// Saving, removing and the unsaved text. Not autoDispose: an Undo can come
/// after the sheet and the title page have closed.
final ownReviewActionsProvider = Provider<OwnReviewActions>(
  OwnReviewActions.new,
);

class OwnReviewActions {
  OwnReviewActions(this._ref);

  final Ref _ref;

  /// Unsaved text waiting for its "Changes discarded" message to close.
  final _pendingDiscards = <RatedTitle, Object>{};

  OwnReviewsRepository get _repository =>
      _ref.read(ownReviewsRepositoryProvider);

  OwnReviewDraftStorage get _drafts => _ref.read(ownReviewDraftStorageProvider);

  String get _userId {
    final userId = _ref.read(userIdProvider);
    if (userId == null) throw const AuthFailure('Not signed in');
    return userId;
  }

  void _show(RatedTitle title, OwnReview? review) {
    _ref.read(ownReviewProvider(title).notifier).show(review);
    _ref.invalidate(allOwnReviewsProvider);
  }

  /// Saves [rating] and [text]; blank text counts as no review, and the unsaved
  /// copy goes. Throws an `AppFailure`, and then nothing changed.
  Future<void> save(
    RatedTitle title, {
    required int rating,
    required String text,
  }) async {
    final userId = _userId;
    final saved = await _repository.save(
      userId,
      title,
      rating: rating,
      text: text.trim().isEmpty ? null : text,
    );
    await _drafts.remove(userId, title);
    _show(title, saved);
  }

  /// Removes [review] and its unsaved copy at once, and puts the rating back if
  /// [undone] completes with true. Throws an `AppFailure`; a failed removal
  /// changes nothing.
  Future<void> removeWithUndo(
    OwnReview review, {
    required Future<bool> undone,
  }) async {
    final userId = _userId;
    await _repository.remove(userId, review.title);
    await _drafts.remove(userId, review.title);
    _show(review.title, null);
    if (await undone) {
      await _repository.restore(userId, review);
      _show(review.title, review);
    }
  }

  /// The unsaved text the editor opens with, if it says something other than
  /// [saved]. Opening it also calls off a discard still counting down: text the
  /// user is looking at again is never deleted under them.
  Future<OwnReviewDraft?> loadDraft(
    RatedTitle title, {
    required OwnReview? saved,
  }) async {
    final userId = _ref.read(userIdProvider);
    if (userId == null) return null;
    _pendingDiscards.remove(title);
    final draft = await _drafts.read(userId, title);
    if (draft == null || draft.differsFrom(saved)) return draft;
    await _drafts.remove(userId, title);
    return null;
  }

  /// Keeps what the editor holds, or deletes the copy once it says the same as
  /// [saved]. Doesn't throw, so it can run at every change.
  Future<void> keepDraft(
    RatedTitle title,
    OwnReviewDraft draft, {
    required OwnReview? saved,
  }) async {
    final userId = _ref.read(userIdProvider);
    if (userId == null) return;
    if (draft.differsFrom(saved)) {
      await _drafts.write(userId, title, draft);
    } else {
      await _drafts.remove(userId, title);
    }
  }

  /// Deletes the unsaved text when the message closes, unless [undone]
  /// completes with true or the editor was opened again meanwhile.
  Future<void> discardDraftWithUndo(
    RatedTitle title, {
    required Future<bool> undone,
  }) async {
    final userId = _userId;
    final discard = Object();
    _pendingDiscards[title] = discard;
    final isUndone = await undone;
    if (!identical(_pendingDiscards[title], discard)) return;
    _pendingDiscards.remove(title);
    if (!isUndone) await _drafts.remove(userId, title);
  }
}
