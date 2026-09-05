import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cinemuse_app/features/media/data/letterboxd_service.dart';
import 'package:cinemuse_app/features/media/domain/comment.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio mockDio;
  late LetterboxdService service;

  const sampleLetterboxdHtml = '''
<!DOCTYPE html>
<html>
<body>
  <div class="listitem">
    <article class="production-viewing -viewing">
      <a class="avatar -a40" href="/cinemafan/">
        <img src="https://a.ltrbxd.com/resized/avatar.jpg" alt="Cinema Fan" />
      </a>
      <div class="body">
        <div class="content-reactions-strip -viewing">
          <span class="inline-symbol inline-rating">
            <svg aria-label="★★★★½"><title>★★★★½</title></svg>
          </span>
          <span class="attribution-detail">
            <span class="owner"><strong class="displayname">Cinema Fan</strong></span>
          </span>
          <span class="date">
            <time class="timestamp" datetime="2024-05-01T12:00:00.000Z">01 May 2024</time>
          </span>
          <a class="metadata"><span class="label">14</span></a>
        </div>
        <div class="js-review">
          <div class="body-text js-review-body">
            <p>An absolute cinematic masterpiece!</p>
          </div>
          <div class="viewing-actions">
            <p class="like-link-target" data-count="3500"></p>
          </div>
        </div>
      </div>
    </article>
  </div>
  <div class="listitem">
    <article class="production-viewing -viewing has-spoilers">
      <div class="body">
        <div class="content-reactions-strip -viewing">
          <span class="attribution-detail">
            <span class="owner"><strong class="displayname">Spoiler User</strong></span>
          </span>
        </div>
        <div class="js-review">
          <div class="body-text js-review-body">
            <p>He was dead the whole time!</p>
          </div>
        </div>
      </div>
    </article>
  </div>
</body>
</html>
''';

  setUpAll(() {
    registerFallbackValue(Options());
  });

  setUp(() {
    mockDio = MockDio();
    service = LetterboxdService(mockDio);
  });

  group('LetterboxdService', () {
    test('toSlug cleans movie title properly', () {
      expect(LetterboxdService.toSlug('Fight Club'), 'fight-club');
      expect(LetterboxdService.toSlug('Dune: Part Two'), 'dune-part-two');
      expect(LetterboxdService.toSlug('Fast & Furious'), 'fast-and-furious');
      expect(LetterboxdService.toSlug(''), 'film');
    });

    test('parseReviewsHtml extracts reviews with ratings, likes, replies, and spoilers', () {
      final comments = service.parseReviewsHtml(sampleLetterboxdHtml);

      expect(comments.length, 2);

      final first = comments[0];
      expect(first.author.username, 'Cinema Fan');
      expect(first.author.avatarUrl, 'https://a.ltrbxd.com/resized/avatar.jpg');
      expect(first.text, 'An absolute cinematic masterpiece!');
      expect(first.rating, 4.5);
      expect(first.likeCount, 3500);
      expect(first.replyCount, 14);
      expect(first.isSpoiler, false);
      expect(first.source, CommentSource.letterboxd);
      expect(first.createdAt, DateTime.parse('2024-05-01T12:00:00.000Z'));

      final second = comments[1];
      expect(second.author.username, 'Spoiler User');
      expect(second.text, 'He was dead the whole time!');
      expect(second.isSpoiler, true);
      expect(second.rating, isNull);
    });

    test('parseReviewsHtml strips Letterboxd spoiler boilerplate and extracts hidden text', () {
      const spoilerHtml = '''
<div class="listitem">
  <article class="production-viewing -viewing -has-spoilers">
    <div class="body">
      <span class="attribution-detail">
        <span class="owner"><strong class="displayname">Film Critic</strong></span>
      </span>
      <div class="js-review">
        <div class="body-text js-review-body">
          <p class="view-date-link -spoilers">
            This review may contain spoilers. <a class="reveal js-reveal">I can handle the truth.</a>
          </p>
          <div class="hidden-spoilers expanded-text">
            <p>The protagonist was actually the villain from 10 years ago!</p>
          </div>
        </div>
      </div>
    </div>
  </article>
</div>
''';

      final comments = service.parseReviewsHtml(spoilerHtml);
      expect(comments.length, 1);
      final comment = comments.first;
      expect(comment.isSpoiler, true);
      expect(comment.text, 'The protagonist was actually the villain from 10 years ago!');
      expect(comment.text.contains('This review may contain spoilers'), false);
      expect(comment.text.contains('I can handle the truth'), false);
    });

    test('fetchMovieReviews resolves canonical slug using tmdbId redirect', () async {
      when(
        () => mockDio.get(
          'https://letterboxd.com/tmdb/496243/',
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 302,
          headers: Headers.fromMap({
            'location': ['/film/parasite-2019/'],
          }),
        ),
      );

      when(
        () => mockDio.get<String>(
          'https://letterboxd.com/film/parasite-2019/reviews/by/activity/',
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
          data: sampleLetterboxdHtml,
        ),
      );

      final comments = await service.fetchMovieReviews(
        tmdbId: 496243,
        title: 'Parasite',
        year: 2019,
        page: 1,
      );

      expect(comments.length, 2);
      expect(comments.first.author.username, 'Cinema Fan');
    });

    test('fetchMovieReviews disambiguates releases by year from og:title', () async {
      const wrongYearHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta property="og:title" content="Parasite (1982)" />
</head>
<body>
  <article class="production-viewing -viewing">
    <div class="body">
      <div class="js-review"><div class="body-text js-review-body"><p>Old movie</p></div></div>
    </div>
  </article>
</body>
</html>
''';

      const correctYearHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta property="og:title" content="Parasite (2019)" />
</head>
<body>
  <article class="production-viewing -viewing">
    <div class="body">
      <div class="js-review"><div class="body-text js-review-body"><p>Bong Joon-ho masterpiece</p></div></div>
    </div>
  </article>
</body>
</html>
''';

      when(
        () => mockDio.get<String>(
          'https://letterboxd.com/film/parasite-2019/reviews/by/activity/',
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
          data: wrongYearHtml,
        ),
      );

      when(
        () => mockDio.get<String>(
          'https://letterboxd.com/film/parasite/reviews/by/activity/',
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
          data: correctYearHtml,
        ),
      );

      final comments = await service.fetchMovieReviews(
        title: 'Parasite',
        year: 2019,
        page: 1,
      );

      expect(comments.length, 1);
      expect(comments.first.text, 'Bong Joon-ho masterpiece');
    });

    test('fetchMovieReviews fetches next page directly from cache', () async {
      when(
        () => mockDio.get(
          'https://letterboxd.com/tmdb/496243/',
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 302,
          headers: Headers.fromMap({
            'location': ['/film/parasite-2019/'],
          }),
        ),
      );

      when(
        () => mockDio.get<String>(
          'https://letterboxd.com/film/parasite-2019/reviews/by/activity/',
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
          data: sampleLetterboxdHtml,
        ),
      );

      when(
        () => mockDio.get<String>(
          'https://letterboxd.com/film/parasite-2019/reviews/by/activity/page/2/',
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
          data: sampleLetterboxdHtml,
        ),
      );

      // Page 1 resolves redirect and populates cache
      await service.fetchMovieReviews(tmdbId: 496243, page: 1);

      // Page 2 hits cache directly
      final page2 = await service.fetchMovieReviews(tmdbId: 496243, page: 2);
      expect(page2.length, 2);
    });

    test('fetchMovieReviews returns empty list on network failure without throwing', () async {
      when(
        () => mockDio.get<String>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenThrow(DioException(requestOptions: RequestOptions(path: '')));

      final comments = await service.fetchMovieReviews(title: 'Unknown Film');
      expect(comments, isEmpty);
    });
  });
}
