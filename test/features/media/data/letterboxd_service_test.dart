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
    <article class="production-viewing -viewing">
      <div class="body">
        <div class="content-reactions-strip -viewing">
          <span class="attribution-detail">
            <span class="owner"><strong class="displayname">Spoiler User</strong></span>
          </span>
        </div>
        <div class="js-review">
          <p class="body-text -prose js-spoiler-container">
            <em>This review may contain spoilers. <a href="#">I can handle the truth.</a></em>
          </p>
          <div class="body-text -prose -reset js-review-body js-collapsible-text" hidden="">
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

    test(
      'parseReviewsHtml extracts reviews with ratings, likes, replies, and spoilers',
      () {
        final comments = service.parseReviewsHtml(sampleLetterboxdHtml);

        expect(comments.length, 2);

        final first = comments[0];
        expect(first.author.username, 'Cinema Fan');
        expect(
          first.author.avatarUrl,
          'https://a.ltrbxd.com/resized/avatar.jpg',
        );
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
      },
    );

    test('a spoiler review keeps its text, without the warning', () {
      final comment = service.parseReviewsHtml(sampleLetterboxdHtml)[1];

      expect(comment.isSpoiler, true);
      expect(comment.text, 'He was dead the whole time!');
    });

    test('a review the site hides counts as a spoiler by itself too', () {
      final comments = service.parseReviewsHtml('''
<article class="production-viewing -viewing">
  <div class="body-text js-review-body" hidden=""><p>The end.</p></div>
</article>
''');

      expect(comments.single.isSpoiler, true);
    });

    test('a review with no text is left out', () {
      final comments = service.parseReviewsHtml('''
<article class="production-viewing -viewing">
  <p class="body-text js-spoiler-container">This review may contain spoilers.</p>
  <div class="body-text js-review-body" hidden=""></div>
</article>
''');

      expect(comments, isEmpty);
    });

    test('paragraphs and line breaks are kept', () {
      final comments = service.parseReviewsHtml('''
<article class="production-viewing -viewing">
  <div class="body-text js-review-body">
    <p>A garden party.<br>A basement.</p><p><i>The most</i> thrilling scene.</p>
  </div>
</article>
''');

      expect(
        comments.single.text,
        'A garden party.\nA basement.\n\nThe most thrilling scene.',
      );
    });

    group('a long review the page cuts short', () {
      const fullTextUrl = 'https://letterboxd.com/s/full-text/viewing:7/';

      String pageWith({bool spoiler = false}) =>
          '''
<article class="production-viewing -viewing">
  ${spoiler ? '<p class="body-text js-spoiler-container">This review may contain spoilers.</p>' : ''}
  <div class="body-text js-review-body" data-full-text-url="/s/full-text/viewing:7/" ${spoiler ? 'hidden=""' : ''}>
    <div class="collapsed-text"><p>The start of it…</p></div>
  </div>
</article>
''';

      Future<List<Comment>> fetchFilm(String page) async {
        when(
          () => mockDio.get<String>(
            'https://letterboxd.com/film/film/reviews/by/activity/',
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 200,
            data: page,
          ),
        );
        return service.fetchMovieReviews(title: 'Film');
      }

      void fullTextAnswers(String data, {int statusCode = 200}) {
        when(
          () =>
              mockDio.get<String>(fullTextUrl, options: any(named: 'options')),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: statusCode,
            data: data,
          ),
        );
      }

      test('is not taken for a spoiler', () {
        final comment = service.parseReviewsHtml(pageWith()).single;

        expect(comment.isSpoiler, false);
        expect(comment.text, 'The start of it…');
      });

      test('shows the whole text, in paragraphs', () async {
        fullTextAnswers('\n\t<p>The start of it, and more.</p><p>The end.</p>');

        final comment = (await fetchFilm(pageWith())).single;

        expect(comment.text, 'The start of it, and more.\n\nThe end.');
        expect(comment.isSpoiler, false);
      });

      test('stays hidden when it has spoilers', () async {
        fullTextAnswers('<p>The whole text.</p>');

        final comment = (await fetchFilm(pageWith(spoiler: true))).single;

        expect(comment.text, 'The whole text.');
        expect(comment.isSpoiler, true);
      });

      test('stays cut when the text does not load', () async {
        when(
          () =>
              mockDio.get<String>(fullTextUrl, options: any(named: 'options')),
        ).thenThrow(DioException(requestOptions: RequestOptions(path: '')));

        final comment = (await fetchFilm(pageWith())).single;

        expect(comment.text, 'The start of it…');
      });

      test('stays cut when the site refuses or sends another page', () async {
        for (final (data, status) in const [
          ('Not found', 404),
          ('  ', 200),
          ('<!DOCTYPE html><html><body>Prove you are human</body></html>', 200),
        ]) {
          fullTextAnswers(data, statusCode: status);

          final comment = (await fetchFilm(pageWith())).single;

          expect(comment.text, 'The start of it…');
        }
      });
    });

    test(
      'fetchMovieReviews resolves canonical slug using tmdbId redirect',
      () async {
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
      },
    );

    test(
      'fetchMovieReviews disambiguates releases by year from og:title',
      () async {
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
      },
    );

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

    test(
      'fetchMovieReviews returns empty list on network failure without throwing',
      () async {
        when(
          () => mockDio.get<String>(any(), options: any(named: 'options')),
        ).thenThrow(DioException(requestOptions: RequestOptions(path: '')));

        final comments = await service.fetchMovieReviews(title: 'Unknown Film');
        expect(comments, isEmpty);
      },
    );
  });
}
