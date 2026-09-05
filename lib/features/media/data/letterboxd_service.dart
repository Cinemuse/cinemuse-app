import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:html/dom.dart' hide Comment;
import 'package:html/parser.dart' as html_parser;
import 'package:cinemuse_app/features/media/domain/comment.dart';

/// Service responsible for scraping and parsing Letterboxd film reviews.
class LetterboxdService {
  static const String _baseUrl = 'https://letterboxd.com';
  static const Map<String, String> _defaultHeaders = {
    'User-Agent':
        'Mozilla/5.0 (compatible; Bingbot/2.0; +http://www.bing.com/bingbot.htm)',
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
    'Referer': 'https://letterboxd.com/',
  };

  final Dio _dio;
  final Map<String, String> _slugCache = {};

  LetterboxdService(this._dio);

  /// Converts a movie [title] and optional [year] into a Letterboxd slug.
  static String toSlug(String title, [int? year]) {
    var cleaned = title
        .toLowerCase()
        .replaceAll(RegExp(r'&'), 'and')
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'[\s-]+'), '-');

    if (cleaned.isEmpty) {
      cleaned = 'film';
    }
    return cleaned;
  }

  /// Fetches reviews from Letterboxd for a movie.
  ///
  /// Resolves the canonical slug deterministically using [tmdbId] or [imdbId]
  /// via Letterboxd's direct redirect endpoints, falling back to [title] and [year]
  /// slug resolution if IDs are unavailable or unresolvable.
  Future<List<Comment>> fetchMovieReviews({
    int? tmdbId,
    String? imdbId,
    String? title,
    int? year,
    int page = 1,
  }) async {
    final cacheKey = tmdbId != null && tmdbId > 0
        ? 'tmdb:$tmdbId'
        : (imdbId != null && imdbId.isNotEmpty
            ? 'imdb:$imdbId'
            : 'title:${title ?? ""}:$year');

    String? resolvedSlug = _slugCache[cacheKey];

    // 1. Resolve canonical slug deterministically from IDs if not cached
    if (resolvedSlug == null) {
      resolvedSlug =
          await _resolveSlugFromIds(tmdbId: tmdbId, imdbId: imdbId);

      // 2. If IDs could not resolve, fall back to title & year candidate matching
      if (resolvedSlug == null && title != null && title.isNotEmpty) {
        resolvedSlug = await _resolveSlugFromTitle(title, year);
      }

      if (resolvedSlug != null) {
        _slugCache[cacheKey] = resolvedSlug;
      }
    }

    if (resolvedSlug == null) {
      return [];
    }

    return _fetchReviewsForSlug(resolvedSlug, page: page);
  }

  Future<String?> _resolveSlugFromIds({int? tmdbId, String? imdbId}) async {
    if (tmdbId != null && tmdbId > 0) {
      final slug = await _queryRedirectSlug('$_baseUrl/tmdb/$tmdbId/');
      if (slug != null) return slug;
    }

    if (imdbId != null && imdbId.isNotEmpty) {
      final slug = await _queryRedirectSlug('$_baseUrl/imdb/$imdbId/');
      if (slug != null) return slug;
    }

    return null;
  }

  Future<String?> _queryRedirectSlug(String url) async {
    try {
      final res = await _dio.get(
        url,
        options: Options(
          headers: _defaultHeaders,
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final location = res.headers['location']?.firstOrNull;
      if (location != null) {
        final match = RegExp(r'/film/([^/]+)/?').firstMatch(location);
        return match?.group(1);
      }
    } catch (e) {
      developer.log(
        'Failed to query redirect slug for $url',
        name: 'LetterboxdService',
        error: e,
      );
    }
    return null;
  }

  Future<String?> _resolveSlugFromTitle(String title, int? year) async {
    final baseSlug = toSlug(title);
    final candidateSlugs = _buildCandidateSlugs(baseSlug, year);

    for (final slug in candidateSlugs) {
      final html = await _fetchPageHtml(slug, page: 1);
      if (html != null && html.isNotEmpty) {
        final pageYear = _extractYearFromHtml(html);
        if (_isYearMatching(pageYear, year)) {
          return slug;
        }
      }
    }
    return null;
  }

  List<String> _buildCandidateSlugs(String baseSlug, int? year) {
    final slugs = <String>[];
    if (year != null) {
      slugs.add('$baseSlug-$year');
    }
    slugs.add(baseSlug);
    return slugs;
  }

  bool _isYearMatching(int? pageYear, int? targetYear) {
    if (pageYear == null || targetYear == null) return true;
    return (pageYear - targetYear).abs() <= 1;
  }

  static int? _extractYearFromHtml(String html) {
    final doc = html_parser.parse(html);
    final ogTitle =
        doc.querySelector('meta[property="og:title"]')?.attributes['content'];
    if (ogTitle != null) {
      final match = RegExp(r'\((\d{4})\)').firstMatch(ogTitle);
      if (match != null) {
        return int.tryParse(match.group(1)!);
      }
    }
    return null;
  }

  Future<List<Comment>> _fetchReviewsForSlug(
    String slug, {
    int page = 1,
  }) async {
    final html = await _fetchPageHtml(slug, page: page);
    if (html == null || html.isEmpty) {
      return [];
    }

    return parseReviewsHtml(html);
  }

  Future<String?> _fetchPageHtml(String slug, {int page = 1}) async {
    final url = page == 1
        ? '$_baseUrl/film/$slug/reviews/by/activity/'
        : '$_baseUrl/film/$slug/reviews/by/activity/page/$page/';

    try {
      final response = await _dio.get<String>(
        url,
        options: Options(
          headers: _defaultHeaders,
          responseType: ResponseType.plain,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200) {
        return response.data;
      }

      // Fallback for page 1: if reviews subpath returned 404, try main film page
      if (page == 1) {
        final fallbackRes = await _dio.get<String>(
          '$_baseUrl/film/$slug/',
          options: Options(
            headers: _defaultHeaders,
            responseType: ResponseType.plain,
            validateStatus: (status) => status != null && status < 500,
          ),
        );
        if (fallbackRes.statusCode == 200) {
          return fallbackRes.data;
        }
      }

      return null;
    } catch (e, stack) {
      developer.log(
        'Failed to fetch Letterboxd reviews for slug: $slug (page: $page)',
        name: 'LetterboxdService',
        error: e,
        stackTrace: stack,
      );
      return null;
    }
  }

  /// Parses Letterboxd HTML review markup into a list of [Comment] objects.
  List<Comment> parseReviewsHtml(String htmlContent) {
    final document = html_parser.parse(htmlContent);
    final articles = document.querySelectorAll(
      'article.production-viewing, article.-viewing, div.film-detail, li.film-detail',
    );
    final comments = <Comment>[];
    final seenIds = <String>{};

    for (final article in articles) {
      final comment = _parseArticle(article);
      if (comment != null && seenIds.add(comment.id)) {
        comments.add(comment);
      }
    }

    return comments;
  }

  Comment? _parseArticle(Element article) {
    // 1. Check for spoiler flags across article and children
    bool isSpoiler = article.classes.contains('has-spoilers') ||
        article.classes.contains('-has-spoilers') ||
        article.querySelector('.has-spoilers, .contains-spoilers, .hidden-spoilers, .-spoilers') != null ||
        article.attributes['data-contains-spoilers'] == 'true';

    // 2. Extract review body element
    final bodyEl = article.querySelector('.js-review-body, .body-text');
    if (bodyEl == null) return null;

    // Check if the review has a dedicated hidden spoilers container
    final hiddenSpoilersEl = bodyEl.querySelector('.hidden-spoilers, .collapsed-text, .expanded-text');
    String rawText;

    if (hiddenSpoilersEl != null) {
      isSpoiler = true;
      rawText = hiddenSpoilersEl.text.trim();
    } else {
      // Remove any inline spoiler prompt elements before reading text
      final spoilerPrompt = bodyEl.querySelector('p.-spoilers, .view-date-link.-spoilers, .js-reveal');
      if (spoilerPrompt != null) {
        isSpoiler = true;
        spoilerPrompt.remove();
      }
      rawText = bodyEl.text.trim();
    }

    // Clean up any remaining Letterboxd boilerplate text
    rawText = rawText
        .replaceAll(RegExp(r'This review may contain spoilers\.?', caseSensitive: false), '')
        .replaceAll(RegExp(r'I can handle the truth\.?', caseSensitive: false), '')
        .trim();

    if (rawText.isEmpty && !isSpoiler) return null;
    final text = rawText.isNotEmpty ? rawText : 'This review contains spoilers.';

    final authorEl = article.querySelector('.displayname, .owner');
    final authorName = authorEl?.text.trim() ?? 'Letterboxd User';

    final avatarImg = article.querySelector('.avatar img');
    final avatarUrl = avatarImg?.attributes['src'];

    final ratingEl = article.querySelector('.inline-rating svg, .inline-rating');
    final ratingLabel = ratingEl?.attributes['aria-label'] ??
        ratingEl?.querySelector('title')?.text ??
        '';
    final rating = _parseStarRating(ratingLabel);

    final likeEl = article.querySelector('.like-link-target, [data-component-class="LikeComponent"]');
    final likeCount = int.tryParse(likeEl?.attributes['data-count'] ?? '') ?? 0;

    final commentCountEl = article.querySelector('a.metadata .label');
    final replyCount = int.tryParse(commentCountEl?.text.trim() ?? '') ?? 0;

    final timeEl = article.querySelector('time.timestamp');
    final dateStr = timeEl?.attributes['datetime'];
    final createdAt = dateStr != null ? DateTime.tryParse(dateStr) : null;

    final id = article.querySelector('[data-likeable-identifier]')?.attributes['data-likeable-identifier'] ??
        '$authorName-${createdAt?.millisecondsSinceEpoch ?? text.hashCode}';

    return Comment(
      id: id,
      author: CommentAuthor(
        id: authorName,
        username: authorName,
        avatarUrl: avatarUrl,
      ),
      text: text,
      rating: rating,
      createdAt: createdAt,
      likeCount: likeCount,
      replyCount: replyCount,
      isSpoiler: isSpoiler,
      source: CommentSource.letterboxd,
    );
  }

  static double? _parseStarRating(String label) {
    if (label.isEmpty) return null;
    double stars = 0.0;
    for (int i = 0; i < label.length; i++) {
      final char = label[i];
      if (char == '★') {
        stars += 1.0;
      } else if (char == '½') {
        stars += 0.5;
      }
    }
    return stars > 0 ? stars : null;
  }
}
