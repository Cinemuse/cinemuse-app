import 'package:cinemuse_app/features/updates/domain/release_notes.dart';
import 'package:flutter_test/flutter_test.dart';

const _bothLanguages = '''
## English
- Live TV guide: Page up turns a screen

## Italiano
- Guida TV: Pagina su scorre una schermata
''';

Map<String, dynamic> _release(
  String tag, {
  bool prerelease = false,
  bool draft = false,
}) => {'tag_name': tag, 'prerelease': prerelease, 'draft': draft};

void main() {
  group('ReleaseNotes.tryParse', () {
    test('reads each language and drops the tag\'s v', () {
      final notes = ReleaseNotes.tryParse('v2.1.0', _bothLanguages)!;

      expect(notes.version, '2.1.0');
      expect(notes.inLanguage('en'), '- Live TV guide: Page up turns a screen');
      expect(
        notes.inLanguage('it'),
        '- Guida TV: Pagina su scorre una schermata',
      );
    });

    test('Windows line ends and loose spaces in the titles', () {
      final notes = ReleaseNotes.tryParse(
        'v2.1.0',
        '##  English \r\n- One\r\n## italiano\r\n- Uno\r\n',
      )!;

      expect(notes.inLanguage('en'), '- One');
      expect(notes.inLanguage('it'), '- Uno');
    });

    test('a missing Italian part: English instead', () {
      final notes = ReleaseNotes.tryParse('v2.1.0', '## English\n- One\n')!;

      expect(notes.inLanguage('it'), '- One');
    });

    test('a language the notes don\'t have: English', () {
      final notes = ReleaseNotes.tryParse('v2.1.0', _bothLanguages)!;

      expect(notes.inLanguage('de'), notes.inLanguage('en'));
    });

    test('only an Italian part: shown in any language', () {
      final notes = ReleaseNotes.tryParse('v2.1.0', '## Italiano\n- Uno\n')!;

      expect(notes.inLanguage('en'), '- Uno');
    });

    test('other titles inside a language stay in its notes', () {
      final notes = ReleaseNotes.tryParse(
        'v2.1.0',
        '## English\n### Live TV\n- One\n## Italiano\n- Uno\n',
      )!;

      expect(notes.inLanguage('en'), '### Live TV\n- One');
    });

    test('no notes: a text GitHub wrote, an empty text, nothing', () {
      expect(
        ReleaseNotes.tryParse(
          'v2.0.0',
          "## What's Changed\n* Cinemuse 2.0 by someone\n",
        ),
        isNull,
      );
      expect(
        ReleaseNotes.tryParse('v2.1.0', '## English\n\n## Italiano\n'),
        isNull,
      );
      expect(ReleaseNotes.tryParse('v2.1.0', ''), isNull);
      expect(ReleaseNotes.tryParse('v2.1.0', null), isNull);
    });
  });

  group('newerReleases', () {
    List<String> tags(List<Map<String, dynamic>> releases) => [
      for (final r in releases) r['tag_name'] as String,
    ];

    test('several new versions: all of them, newest first', () {
      final newer = newerReleases(
        [
          _release('v2.1.0'),
          _release('v2.2.0'),
          _release('v2.0.0'),
          _release('v2.1.1'),
        ],
        '2.0.0',
        '1',
      );

      expect(tags(newer), ['v2.2.0', 'v2.1.1', 'v2.1.0']);
    });

    test('one new version', () {
      expect(
        tags(
          newerReleases([_release('v2.1.0'), _release('v2.0.0')], '2.0.0', '1'),
        ),
        ['v2.1.0'],
      );
    });

    test('test releases and drafts are skipped', () {
      final newer = newerReleases(
        [
          _release('v2.2.0-beta.1', prerelease: true),
          _release('v2.3.0', draft: true),
          _release('v2.1.0'),
        ],
        '2.0.0',
        '1',
      );

      expect(tags(newer), ['v2.1.0']);
    });

    test('up to date, or an unreadable tag: nothing', () {
      expect(
        newerReleases(
          [
            _release('v2.0.0'),
            _release('nightly'),
            {'name': 'x'},
          ],
          '2.0.0',
          '1',
        ),
        isEmpty,
      );
    });

    test('a newer build of the same version counts', () {
      expect(tags(newerReleases([_release('v2.0.0+2')], '2.0.0', '1')), [
        'v2.0.0+2',
      ]);
    });
  });
}
