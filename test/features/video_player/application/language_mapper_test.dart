import 'package:cinemuse_app/features/video_player/application/language_mapper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';

void main() {
  group('LanguageMapper', () {
    test(
      'getDisplayLanguage maps ISO and language names to display strings',
      () {
        expect(LanguageMapper.getDisplayLanguage('it'), 'Italiano');
        expect(LanguageMapper.getDisplayLanguage('ita'), 'Italiano');
        expect(LanguageMapper.getDisplayLanguage('italian'), 'Italiano');
        expect(LanguageMapper.getDisplayLanguage('en'), 'English');
        expect(LanguageMapper.getDisplayLanguage('eng'), 'English');
        expect(LanguageMapper.getDisplayLanguage('fr'), 'Français');
        expect(LanguageMapper.getDisplayLanguage('de'), 'Deutsch');
        expect(LanguageMapper.getDisplayLanguage('es'), 'Español');
        expect(LanguageMapper.getDisplayLanguage('ja'), '日本語');
        expect(LanguageMapper.getDisplayLanguage('ko'), '한국어');
        expect(LanguageMapper.getDisplayLanguage('zh'), '中文');
        expect(
          LanguageMapper.getDisplayLanguage('sdh'),
          'SDH (Hard of Hearing)',
        );
      },
    );

    test('getDisplayLanguage handles numeric track fallback', () {
      expect(LanguageMapper.getDisplayLanguage('1'), 'Track 1');
      expect(LanguageMapper.getDisplayLanguage('42'), 'Track 42');
    });

    test('getDisplayLanguage returns raw string for unknown codes', () {
      expect(LanguageMapper.getDisplayLanguage('esperanto'), 'esperanto');
    });

    test('getCodes resolves aliases correctly', () {
      expect(
        LanguageMapper.getCodes('it'),
        containsAll(['ita', 'it', 'italiano']),
      );
      expect(
        LanguageMapper.getCodes('eng'),
        containsAll(['eng', 'en', 'english']),
      );
      expect(
        LanguageMapper.getCodes('french'),
        containsAll(['fra', 'fr', 'français', 'fre']),
      );
      expect(LanguageMapper.getCodes('custom'), ['custom']);
    });

    test('isMatch matches AudioTrack by language or title', () {
      final audioTrackEng = AudioTrack('1', 'Main Audio', 'en');
      expect(LanguageMapper.isMatch(audioTrackEng, 'en'), isTrue);
      expect(LanguageMapper.isMatch(audioTrackEng, 'eng'), isTrue);
      expect(LanguageMapper.isMatch(audioTrackEng, 'english'), isTrue);
      expect(LanguageMapper.isMatch(audioTrackEng, 'ita'), isFalse);

      final audioTrackItalianTitle = AudioTrack('2', 'Italiano 5.1', 'und');
      expect(LanguageMapper.isMatch(audioTrackItalianTitle, 'it'), isTrue);
      expect(LanguageMapper.isMatch(audioTrackItalianTitle, 'ita'), isTrue);
    });

    test('isMatch matches SubtitleTrack correctly', () {
      final subTrackIta = SubtitleTrack('sub1', 'Italiano SDH', 'ita');
      expect(LanguageMapper.isMatch(subTrackIta, 'it'), isTrue);
      expect(LanguageMapper.isMatch(subTrackIta, 'ita'), isTrue);
      expect(LanguageMapper.isMatch(subTrackIta, 'en'), isFalse);
    });

    test('isMatch ignores codes hidden inside other words (REV-143)', () {
      expect(
        LanguageMapper.isMatch(AudioTrack('1', 'French', ''), 'en'),
        isFalse,
      );
      expect(
        LanguageMapper.isMatch(AudioTrack('1', 'Commentary', 'und'), 'en'),
        isFalse,
      );
      expect(
        LanguageMapper.isMatch(AudioTrack('1', 'Japanese', ''), 'es'),
        isFalse,
      );
      expect(
        LanguageMapper.isMatch(AudioTrack('1', 'Chinese', ''), 'es'),
        isFalse,
      );
      expect(
        LanguageMapper.isMatch(SubtitleTrack('1', 'Subtitles', ''), 'es'),
        isFalse,
      );
      expect(
        LanguageMapper.isMatch(SubtitleTrack('1', 'Subtitles', ''), 'it'),
        isFalse,
      );
      expect(
        LanguageMapper.isMatch(AudioTrack('1', 'Director with cast', ''), 'it'),
        isFalse,
      );
      expect(LanguageMapper.isMatch(AudioTrack('1', '', 'fre'), 'en'), isFalse);
    });

    test('isMatch still finds whole words and tagged languages', () {
      expect(
        LanguageMapper.isMatch(AudioTrack('1', 'ES 5.1', ''), 'es'),
        isTrue,
      );
      expect(
        LanguageMapper.isMatch(AudioTrack('1', 'Español (Latino)', ''), 'es'),
        isTrue,
      );
      expect(
        LanguageMapper.isMatch(AudioTrack('1', 'English', ''), 'en'),
        isTrue,
      );
      expect(
        LanguageMapper.isMatch(AudioTrack('1', '', 'en-US'), 'en'),
        isTrue,
      );
      expect(LanguageMapper.isMatch(AudioTrack('1', '', 'spa'), 'es'), isTrue);
      expect(
        LanguageMapper.isMatch(AudioTrack('1', 'Italian', ''), 'it'),
        isTrue,
      );
      expect(
        LanguageMapper.isMatch(AudioTrack('1', 'Spanish', ''), 'es'),
        isTrue,
      );
    });

    test('a Spanish user gets the Spanish track, not Japanese (REV-143)', () {
      final tracks = [
        AudioTrack('1', 'Japanese', 'jpn'),
        AudioTrack('2', 'Spanish', 'spa'),
      ];
      final match = tracks.firstWhere((t) => LanguageMapper.isMatch(t, 'es'));
      expect(match.id, '2');
    });

    test('isMatch handles empty or null cases safely', () {
      final track = AudioTrack('1', 'Audio', 'en');
      expect(LanguageMapper.isMatch(track, ''), isFalse);
      expect(LanguageMapper.isMatch(null, 'en'), isFalse);
    });

    // REV-281: the language first, the title only when it adds something,
    // and the channels / codec so two audio tracks of one language differ.
    final labelCases = <(String, dynamic, String)>[
      (
        'title in another language',
        SubtitleTrack('1', 'NON UDENTI', 'eng'),
        'English · NON UDENTI',
      ),
      (
        'title repeats the language',
        SubtitleTrack('2', 'English', 'eng'),
        'English',
      ),
      (
        'title is the language code',
        SubtitleTrack('3', 'ita', 'ita'),
        'Italiano',
      ),
      ('no language: the title', SubtitleTrack('4', 'Forced', null), 'Forced'),
      (
        'no language, no title: the id',
        SubtitleTrack('5', null, null),
        'Track 5',
      ),
      (
        'audio channels + codec',
        AudioTrack('1', 'Italiano', 'ita', channelscount: 6, codec: 'eac3'),
        'Italiano · 5.1 · EAC3',
      ),
      (
        'audio stereo, no codec',
        AudioTrack('2', null, 'eng', channelscount: 2),
        'English · Stereo',
      ),
    ];
    for (final (name, track, expected) in labelCases) {
      test('trackLabel: $name', () {
        expect(LanguageMapper.trackLabel(track), expected);
      });
    }
  });
}
