import 'package:flutter/widgets.dart';

/// Centralized TMDB image URL builder with responsive sizing.
///
/// Instead of hardcoding `https://image.tmdb.org/t/p/w500$path` everywhere,
/// widgets call `TmdbImageHelper.posterUrl(context, path)` and get the
/// optimal resolution for the current screen.
class TmdbImageHelper {
  static const _base = 'https://image.tmdb.org/t/p';

  /// Poster images (portrait, ~2:3 ratio).
  /// Used by: MediaCard, collection_card, agenda_widget.
  /// Mobile: w342, Desktop: w500.
  static String? posterUrl(BuildContext context, String? path) {
    if (path == null) return null;
    final size = _isDesktop(context) ? 'w500' : 'w342';
    return '$_base/$size$path';
  }

  /// Backdrop images (landscape, 16:9).
  /// Used by: HeroSection, DetailsHero.
  /// Mobile: w780, Desktop: w1280.
  static String? backdropUrl(BuildContext context, String? path) {
    if (path == null) return null;
    final size = _isDesktop(context) ? 'w1280' : 'w780';
    return '$_base/$size$path';
  }

  /// Small backdrop for cards (e.g. BackdropCard at 280px wide).
  /// Mobile: w300, Desktop: w780.
  static String? backdropCardUrl(BuildContext context, String? path) {
    if (path == null) return null;
    final size = _isDesktop(context) ? 'w780' : 'w300';
    return '$_base/$size$path';
  }

  /// Profile/avatar images (small circular or square).
  /// Used by: person_card, person_details_screen.
  /// Mobile: w185, Desktop: w342.
  static String? profileUrl(BuildContext context, String? path) {
    if (path == null) return null;
    final size = _isDesktop(context) ? 'w342' : 'w185';
    return '$_base/$size$path';
  }

  /// Episode stills (landscape thumbnails).
  /// Mobile: w300, Desktop: w500.
  static String? stillUrl(BuildContext context, String? path) {
    if (path == null) return null;
    final size = _isDesktop(context) ? 'w500' : 'w300';
    return '$_base/$size$path';
  }

  /// Logos (provider logos, network logos).
  /// Always small — w200 everywhere.
  static String? logoUrl(String? path) {
    if (path == null) return null;
    return '$_base/w200$path';
  }

  /// Tiny poster thumbnails (e.g. filmography list).
  /// Always w92.
  static String? thumbnailUrl(String? path) {
    if (path == null) return null;
    return '$_base/w92$path';
  }

  /// Gallery / full-screen preview images.
  /// Always original (user is zooming in).
  static String? originalUrl(String? path) {
    if (path == null) return null;
    return '$_base/original$path';
  }

  static bool _isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1200;
  }
}
