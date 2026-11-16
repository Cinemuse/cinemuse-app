import 'package:cinemuse_app/core/error/supabase_failure.dart';
import 'package:cinemuse_app/core/services/system/supabase_service.dart';
import 'package:cinemuse_app/features/media/domain/own_review.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final ownReviewsRepositoryProvider = Provider<OwnReviewsRepository>((ref) {
  return OwnReviewsRepository(ref.watch(supabaseClientProvider));
});

/// The user's own ratings and reviews, on the server. Every call throws an
/// `AppFailure` when it fails.
class OwnReviewsRepository {
  static const _table = 'reviews';
  static const _columns =
      'tmdb_id, media_type, rating, review_text, created_at, updated_at';
  static const _titleColumns = 'user_id,tmdb_id,media_type';

  /// The server answers at most this many rows at a time.
  static const _pageSize = 1000;

  final SupabaseClient _client;

  OwnReviewsRepository(this._client);

  /// The user's rating of [title], or null when there is none.
  Future<OwnReview?> get(String userId, RatedTitle title) async {
    final row = await _client
        .from(_table)
        .select(_columns)
        .eq('user_id', userId)
        .eq('tmdb_id', title.tmdbId)
        .eq('media_type', title.mediaType.name)
        .maybeSingle()
        .withAppFailure();
    return row == null ? null : OwnReview.fromJson(row);
  }

  /// All the user's ratings.
  Future<List<OwnReview>> getAll(String userId) async {
    final reviews = <OwnReview>[];
    while (true) {
      final page = await _client
          .from(_table)
          .select(_columns)
          .eq('user_id', userId)
          // A fixed order, so no row falls between two pages.
          .order('tmdb_id')
          .order('media_type')
          .range(reviews.length, reviews.length + _pageSize - 1)
          .withAppFailure();
      reviews.addAll(page.map(OwnReview.fromJson));
      if (page.length < _pageSize) return reviews;
    }
  }

  /// Saves [rating] and [text] over any earlier rating of [title]. When it was
  /// first made stays as it was, because `created_at` isn't sent.
  Future<OwnReview> save(
    String userId,
    RatedTitle title, {
    required int rating,
    String? text,
  }) async {
    final row = await _client
        .from(_table)
        .upsert({
          'user_id': userId,
          'tmdb_id': title.tmdbId,
          'media_type': title.mediaType.name,
          'rating': rating,
          'review_text': text,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: _titleColumns)
        .select(_columns)
        .single()
        .withAppFailure();
    return OwnReview.fromJson(row);
  }

  /// Puts a removed rating back exactly as it was (Undo).
  Future<void> restore(String userId, OwnReview review) async {
    await _client.from(_table).upsert({
      'user_id': userId,
      'tmdb_id': review.tmdbId,
      'media_type': review.mediaType.name,
      'rating': review.rating,
      'review_text': review.text,
      'created_at': review.createdAt.toUtc().toIso8601String(),
      'updated_at': review.updatedAt.toUtc().toIso8601String(),
    }, onConflict: _titleColumns).withAppFailure();
  }

  Future<void> remove(String userId, RatedTitle title) async {
    await _client
        .from(_table)
        .delete()
        .eq('user_id', userId)
        .eq('tmdb_id', title.tmdbId)
        .eq('media_type', title.mediaType.name)
        .withAppFailure();
  }
}
