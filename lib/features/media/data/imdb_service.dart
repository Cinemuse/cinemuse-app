import 'dart:convert';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:cinemuse_app/features/media/domain/comment.dart';

/// Service responsible for fetching IMDb user reviews via the lightweight GraphQL endpoint.
class ImdbService {
  static const String _endpoint = 'https://caching.graphql.imdb.com/';
  static const Map<String, String> _defaultHeaders = {
    'Content-Type': 'application/json',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
    'Referer': 'https://www.imdb.com/',
  };

  final Dio _dio;
  final Map<String, String> _pageCursors = {};

  ImdbService(this._dio);

  /// Fetches reviews from IMDb for a movie, series, or episode with [imdbId].
  /// Supports [page] based pagination through GraphQL cursor caching.
  Future<List<Comment>> fetchReviews({
    required String imdbId,
    int limit = 15,
    int page = 1,
  }) async {
    final cleanId = imdbId.trim();
    if (cleanId.isEmpty) return const [];

    final formattedId = cleanId.startsWith('tt') ? cleanId : 'tt$cleanId';
    final previousCursor = page > 1 ? _pageCursors['$formattedId:p${page - 1}'] : null;

    final isPaginated = previousCursor != null && previousCursor.isNotEmpty;
    final query = isPaginated ? _reviewsGraphQLQueryAfter : _reviewsGraphQLQueryInitial;
    final variables = <String, dynamic>{
      'titleId': formattedId,
      'first': limit,
      if (isPaginated) 'after': previousCursor,
    };

    try {
      final response = await _dio.post<dynamic>(
        _endpoint,
        data: {
          'query': query,
          'variables': variables,
        },
        options: Options(headers: _defaultHeaders),
      );

      dynamic rawData = response.data;
      if (rawData is String) {
        try {
          rawData = jsonDecode(rawData);
        } catch (_) {
          return const [];
        }
      }

      if (rawData is! Map<String, dynamic>) return const [];

      final reviewsData = rawData['data']?['title']?['reviews'];
      if (reviewsData == null) return const [];

      final pageInfo = reviewsData['pageInfo'] as Map<String, dynamic>?;
      final nextCursor = pageInfo?['endCursor']?.toString();
      final hasNextPage = pageInfo?['hasNextPage'] == true;

      if (hasNextPage && nextCursor != null && nextCursor.isNotEmpty) {
        _pageCursors['$formattedId:p$page'] = nextCursor;
      }

      final edges = (reviewsData['edges'] as List<dynamic>?) ?? [];

      final comments = edges
          .whereType<Map<String, dynamic>>()
          .map(_mapGraphQLNodeToComment)
          .where((c) => c.text.isNotEmpty || (c.title != null && c.title!.isNotEmpty))
          .toList();

      developer.log(
        'Fetched ${comments.length} IMDb reviews for $formattedId (page $page)',
        name: 'ImdbService',
      );

      return comments;
    } catch (e, stack) {
      developer.log(
        'Failed to fetch IMDb reviews for $formattedId (page $page)',
        name: 'ImdbService',
        error: e,
        stackTrace: stack,
      );
      return const [];
    }
  }

  Comment _mapGraphQLNodeToComment(Map<String, dynamic> json) {
    final node = json['node'] as Map<String, dynamic>? ?? {};
    final id = node['id']?.toString() ?? '';
    final authorName = (node['author']?['nickName']?.toString() ?? 'IMDb User').trim();
    final summary = (node['summary']?['originalText']?.toString() ?? '').trim();

    final textObj = node['text']?['originalText'];
    String rawText = '';
    if (textObj is Map) {
      rawText = textObj['plaidHtml']?.toString() ?? '';
    } else if (textObj is String) {
      rawText = textObj;
    } else if (textObj != null) {
      rawText = textObj.toString();
    }

    final cleanedText = _cleanReviewText(rawText);

    // Normalize IMDb rating from 0-10 scale into 0-5 scale
    final rawRating = node['authorRating'];
    final rating = rawRating is num ? (rawRating / 2.0) : null;
    final date = _parseDate(node['submissionDate']?.toString());
    final upVotes = _parseInt(node['helpfulness']?['upVotes']);

    return Comment(
      id: 'imdb_$id',
      author: CommentAuthor(
        id: 'imdb_$authorName',
        username: authorName.isNotEmpty ? authorName : 'IMDb User',
      ),
      title: summary.isNotEmpty ? _unescapeHtml(summary) : null,
      text: _unescapeHtml(cleanedText),
      rating: rating,
      createdAt: date,
      likeCount: upVotes,
      source: CommentSource.imdb,
    );
  }

  String _cleanReviewText(String html) {
    if (html.isEmpty) return '';
    return html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .trim();
  }

  String _unescapeHtml(String text) {
    if (text.isEmpty) return '';
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&#27;', "'")
        .replaceAll('&#x2F;', '/');
  }

  DateTime? _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    return DateTime.tryParse(dateStr);
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  static const String _reviewsGraphQLQueryInitial = r'''
    query TitleReviews($titleId: ID!, $first: Int!) {
      title(id: $titleId) {
        reviews(first: $first) {
          total
          pageInfo {
            hasNextPage
            endCursor
          }
          edges {
            node {
              id
              author {
                nickName
              }
              authorRating
              submissionDate
              summary {
                originalText
              }
              text {
                originalText {
                  plaidHtml
                }
              }
              helpfulness {
                upVotes
                downVotes
              }
            }
          }
        }
      }
    }
  ''';

  static const String _reviewsGraphQLQueryAfter = r'''
    query TitleReviewsAfter($titleId: ID!, $first: Int!, $after: ID!) {
      title(id: $titleId) {
        reviews(first: $first, after: $after) {
          total
          pageInfo {
            hasNextPage
            endCursor
          }
          edges {
            node {
              id
              author {
                nickName
              }
              authorRating
              submissionDate
              summary {
                originalText
              }
              text {
                originalText {
                  plaidHtml
                }
              }
              helpfulness {
                upVotes
                downVotes
              }
            }
          }
        }
      }
    }
  ''';
}
