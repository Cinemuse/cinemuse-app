import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:flutter_test/flutter_test.dart';

MediaItem _item({String? en, String? it}) => MediaItem(
  tmdbId: 1,
  mediaType: MediaKind.movie,
  titleEn: en,
  titleIt: it,
  updatedAt: DateTime(2026),
);

void main() {
  group('MediaItem.hasCompleteTitle', () {
    test('a real title is complete', () {
      expect(_item(en: 'Dune').hasCompleteTitle('en'), isTrue);
    });

    test('missing, blank and placeholder titles are not', () {
      expect(_item().hasCompleteTitle('en'), isFalse);
      expect(_item(en: '  ').hasCompleteTitle('en'), isFalse);
      expect(_item(en: 'Unknown').hasCompleteTitle('en'), isFalse);
      expect(_item(en: '...').hasCompleteTitle('en'), isFalse);
    });

    test('checks the title of the given language', () {
      final item = _item(en: 'The Book', it: '...');
      expect(item.hasCompleteTitle('en'), isTrue);
      expect(item.hasCompleteTitle('it'), isFalse);
    });
  });
}
