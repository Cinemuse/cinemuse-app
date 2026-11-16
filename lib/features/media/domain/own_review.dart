import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:equatable/equatable.dart';

/// The film or series a rating belongs to: TMDB's film and series ids overlap.
typedef RatedTitle = ({int tmdbId, MediaKind mediaType});

/// The user's own rating of a film or a whole series, with an optional review.
class OwnReview extends Equatable {
  static const minRating = 1;
  static const maxRating = 10;

  /// Where a rating starts when the user hasn't given one yet.
  static const startingRating = 5;

  final int tmdbId;
  final MediaKind mediaType;
  final int rating;

  /// As typed, Markdown included; never empty, null when there is no review.
  final String? text;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OwnReview({
    required this.tmdbId,
    required this.mediaType,
    required this.rating,
    this.text,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OwnReview.fromJson(Map<String, dynamic> json) => OwnReview(
    tmdbId: json['tmdb_id'] as int,
    mediaType: MediaItem.fromString(json['media_type'] as String),
    rating: json['rating'] as int,
    text: json['review_text'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  RatedTitle get title => (tmdbId: tmdbId, mediaType: mediaType);

  /// Same as `WatchHistory.titleKey`.
  String get titleKey => '${mediaType.name}-$tmdbId';

  @override
  List<Object?> get props => [
    tmdbId,
    mediaType,
    rating,
    text,
    createdAt,
    updatedAt,
  ];
}

/// What the editor holds and hasn't saved, kept on the device so a stray tap
/// never loses a long text.
class OwnReviewDraft extends Equatable {
  final int rating;
  final String text;

  const OwnReviewDraft({required this.rating, required this.text});

  /// Null for anything that isn't a draft this app wrote.
  static OwnReviewDraft? fromJson(Object? json) {
    if (json case {
      'rating': final int rating,
      'text': final String text,
    } when rating >= OwnReview.minRating && rating <= OwnReview.maxRating) {
      return OwnReviewDraft(rating: rating, text: text);
    }
    return null;
  }

  Map<String, Object> toJson() => {'rating': rating, 'text': text};

  /// Whether it says something other than [saved], or than an untouched editor
  /// when nothing is saved.
  bool differsFrom(OwnReview? saved) =>
      rating != (saved?.rating ?? OwnReview.startingRating) ||
      text != (saved?.text ?? '');

  @override
  List<Object?> get props => [rating, text];
}
