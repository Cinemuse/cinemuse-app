import 'package:cinemuse_app/features/video_player/application/language_mapper.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:cinemuse_app/l10n/app_localizations_it.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';

void main() {
  final en = AppLocalizationsEn();

  group('LanguageMapper', () {
    test('a language shows its own name, then the app language\'s', () {
      final it = AppLocalizationsIt();
      expect(LanguageMapper.getDisplayLanguage('it', en), 'Italiano – Italian');
      expect(LanguageMapper.getDisplayLanguage('ita', it), 'Italiano');
      expect(LanguageMapper.getDisplayLanguage('italian', it), 'Italiano');
      expect(LanguageMapper.getDisplayLanguage('eng', en), 'English');
      expect(LanguageMapper.getDisplayLanguage('eng', it), 'English – Inglese');
      expect(LanguageMapper.getDisplayLanguage('ger', it), 'Deutsch – Tedesco');
      expect(LanguageMapper.getDisplayLanguage('ja', it), '日本語 – Giapponese');
      expect(
        LanguageMapper.getDisplayLanguage('pt-BR', it),
        'Português – Portoghese',
      );
      // Codes the player used to show as they were.
      expect(LanguageMapper.getDisplayLanguage('pol', it), 'Polski – Polacco');
      expect(
        LanguageMapper.getDisplayLanguage('hun', it),
        'Magyar – Ungherese',
      );
      expect(LanguageMapper.getDisplayLanguage('cze', en), 'Čeština – Czech');
    });

    test('every language has a name in the app languages', () {
      final it = AppLocalizationsIt();
      for (final code in ['por', 'ara', 'gre', 'heb', 'nob', 'rum', 'ukr']) {
        expect(LanguageMapper.getDisplayLanguage(code, en), contains(' – '));
        expect(LanguageMapper.getDisplayLanguage(code, it), contains(' – '));
      }
      for (final code in LanguageMapper.getCodes('fil')) {
        expect(LanguageMapper.languageKey(code), 'tl');
      }
    });

    test('getDisplayLanguage handles numeric track fallback', () {
      expect(LanguageMapper.getDisplayLanguage('1', en), 'Track 1');
      expect(LanguageMapper.getDisplayLanguage('42', en), 'Track 42');
      expect(
        LanguageMapper.getDisplayLanguage('1', AppLocalizationsIt()),
        'Traccia 1',
      );
    });

    test('getDisplayLanguage returns raw string for unknown codes', () {
      expect(LanguageMapper.getDisplayLanguage('esperanto', en), 'esperanto');
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

    // REV-281: the language first, then Forced / CC, the title only when it
    // adds something, and the channels / codec so two audio tracks of one
    // language differ.
    final labelCases = <(String, dynamic, String)>[
      (
        '"non udenti" is CC',
        SubtitleTrack('1', 'NON UDENTI', 'eng'),
        'English · CC',
      ),
      ('SDH is CC', SubtitleTrack('1', 'English SDH', 'eng'), 'English · CC'),
      (
        'title repeats the language',
        SubtitleTrack('2', 'English', 'eng'),
        'English',
      ),
      (
        'title is the language code',
        SubtitleTrack('3', 'ita', 'ita'),
        'Italiano – Italian',
      ),
      (
        'forced, the language only in the title',
        SubtitleTrack('4', 'English (Forced)', null),
        'English · Forced',
      ),
      (
        'forced, no language',
        SubtitleTrack('4', 'Forced', null),
        'Track 4 · Forced',
      ),
      (
        'anime signs are forced, the title adds "Songs"',
        SubtitleTrack('6', 'Signs & Songs', 'eng'),
        'English · Forced · Signs & Songs',
      ),
      (
        'a title that says more',
        SubtitleTrack('7', 'Commentary', 'eng'),
        'English · Commentary',
      ),
      (
        '"sdh" as the language',
        SubtitleTrack('8', null, 'sdh'),
        'Track 8 · CC',
      ),
      (
        'no language, no title: the id',
        SubtitleTrack('5', null, null),
        'Track 5',
      ),
      (
        'audio channels + codec',
        AudioTrack('1', 'Italiano', 'ita', channelscount: 6, codec: 'eac3'),
        'Italiano – Italian · 5.1 · EAC3',
      ),
      (
        'audio stereo, no codec',
        AudioTrack('2', null, 'eng', channelscount: 2),
        'English · Stereo',
      ),
    ];
    for (final (name, track, expected) in labelCases) {
      test('trackLabel: $name', () {
        expect(
          LanguageMapper.trackLabel(
            track,
            en,
            kind: LanguageMapper.subtitleKind(track),
          ),
          expected,
        );
      });
    }

    test('the file\'s own flag wins over the title', () {
      final track = SubtitleTrack('1', 'English', 'eng');
      expect(LanguageMapper.subtitleKind(track), SubtitleKind.full);
      expect(
        LanguageMapper.subtitleKind(track, flagged: SubtitleKind.forced),
        SubtitleKind.forced,
      );
      expect(
        LanguageMapper.subtitleKind(track, flagged: SubtitleKind.cc),
        SubtitleKind.cc,
      );
    });

    test('tracks are grouped by language, English and Italian first', () {
      final tracks = [
        SubtitleTrack('1', null, 'ger'),
        SubtitleTrack('2', 'SDH', 'eng'),
        SubtitleTrack('3', null, 'ita'),
        SubtitleTrack('4', null, null),
        SubtitleTrack('5', 'Forced', 'eng'),
        SubtitleTrack('6', null, 'spa'),
        SubtitleTrack('7', null, 'eng'),
        SubtitleTrack('8', 'Forzati', 'ita'),
        SubtitleTrack('9', null, 'jpn'),
        SubtitleTrack('10', null, 'eng'),
      ];
      final sorted = LanguageMapper.sortedByLanguage(
        tracks,
        LanguageMapper.subtitleKind,
      );
      expect(sorted.map((t) => t.id), [
        // English: full (file order), forced, CC.
        '7', '10', '5', '2',
        // Italian.
        '3', '8',
        // The others by their own name, then no language.
        '1', '6', '9', '4',
      ]);
    });
  });
}
