import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/own_review.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads a row of the table', () {
    final review = OwnReview.fromJson({
      'tmdb_id': 438631,
      'media_type': 'tv',
      'rating': 9,
      'review_text': '**Great**',
      'created_at': '2026-11-01T10:00:00+00:00',
      'updated_at': '2026-11-02T10:00:00+00:00',
    });

    expect(review.title, (tmdbId: 438631, mediaType: MediaKind.tv));
    expect(review.rating, 9);
    expect(review.text, '**Great**');
    expect(review.createdAt, DateTime.utc(2026, 11, 1, 10));
    expect(review.updatedAt, DateTime.utc(2026, 11, 2, 10));
    expect(review.titleKey, 'tv-438631');
  });

  test('a rating with no review has no text', () {
    final review = OwnReview.fromJson({
      'tmdb_id': 1,
      'media_type': 'movie',
      'rating': 1,
      'review_text': null,
      'created_at': '2026-11-01T10:00:00+00:00',
      'updated_at': '2026-11-01T10:00:00+00:00',
    });

    expect(review.mediaType, MediaKind.movie);
    expect(review.text, isNull);
  });

  group('unsaved text', () {
    final saved = OwnReview(
      tmdbId: 1,
      mediaType: MediaKind.movie,
      rating: 9,
      text: 'Great',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
    );

    test('reads back what it wrote', () {
      const draft = OwnReviewDraft(rating: 7, text: '**Long** text');

      expect(OwnReviewDraft.fromJson(draft.toJson()), draft);
    });

    test('anything else is no draft', () {
      expect(OwnReviewDraft.fromJson('text'), isNull);
      expect(OwnReviewDraft.fromJson({'rating': 7}), isNull);
      expect(OwnReviewDraft.fromJson({'rating': 11, 'text': ''}), isNull);
      expect(OwnReviewDraft.fromJson({'rating': 0, 'text': ''}), isNull);
    });

    test('compared with the saved rating', () {
      const same = OwnReviewDraft(rating: 9, text: 'Great');
      const otherScore = OwnReviewDraft(rating: 8, text: 'Great');
      const otherText = OwnReviewDraft(rating: 9, text: 'Great!');

      expect(same.differsFrom(saved), isFalse);
      expect(otherScore.differsFrom(saved), isTrue);
      expect(otherText.differsFrom(saved), isTrue);
    });

    test('with no rating, compared with an untouched editor', () {
      const untouched = OwnReviewDraft(
        rating: OwnReview.startingRating,
        text: '',
      );
      const typed = OwnReviewDraft(rating: OwnReview.startingRating, text: 'a');

      expect(untouched.differsFrom(null), isFalse);
      expect(typed.differsFrom(null), isTrue);
    });
  });
}
