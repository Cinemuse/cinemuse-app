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

    test('isMatch handles empty or null cases safely', () {
      final track = AudioTrack('1', 'Audio', 'en');
      expect(LanguageMapper.isMatch(track, ''), isFalse);
      expect(LanguageMapper.isMatch(null, 'en'), isFalse);
    });
  });
}
