import 'package:cinemuse_app/features/media/data/own_review_draft_storage.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/own_review.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const dune = (tmdbId: 438631, mediaType: MediaKind.movie);
  const sameNumberSeries = (tmdbId: 438631, mediaType: MediaKind.tv);
  const draft = OwnReviewDraft(rating: 7, text: 'A long text');

  final storage = OwnReviewDraftStorage();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('reads back what was written', () async {
    await storage.write('me', dune, draft);

    expect(await storage.read('me', dune), draft);
  });

  test('nothing written reads as nothing', () async {
    expect(await storage.read('me', dune), isNull);
  });

  test('a newer write replaces the older one', () async {
    await storage.write('me', dune, draft);
    const newer = OwnReviewDraft(rating: 8, text: 'Longer');
    await storage.write('me', dune, newer);

    expect(await storage.read('me', dune), newer);
  });

  test('a film and a series with the same number are separate', () async {
    await storage.write('me', dune, draft);

    expect(await storage.read('me', sameNumberSeries), isNull);
  });

  test('two accounts on one device are separate', () async {
    await storage.write('me', dune, draft);

    expect(await storage.read('someone-else', dune), isNull);
  });

  test('removing deletes only that one', () async {
    await storage.write('me', dune, draft);
    await storage.write('me', sameNumberSeries, draft);
    await storage.remove('me', dune);

    expect(await storage.read('me', dune), isNull);
    expect(await storage.read('me', sameNumberSeries), draft);
  });

  test('a damaged copy reads as nothing', () async {
    await storage.write('me', dune, draft);
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getKeys().single;
    await prefs.setString(key, '{not json');

    expect(await storage.read('me', dune), isNull);
  });
}
