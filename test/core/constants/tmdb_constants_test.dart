import 'package:cinemuse_app/core/constants/tmdb_constants.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final it = lookupAppLocalizations(const Locale('it'));

  test('every Explore genre has a name in English and Italian', () {
    for (final id in TmdbConstants.genreIds) {
      expect(en.genreName(id), isNot('$id'));
      expect(it.genreName(id), isNot('$id'));
    }
    expect(en.genreName(28), 'Action');
    expect(it.genreName(28), 'Azione');
  });

  test('every Explore language has a name in English and Italian', () {
    for (final code in TmdbConstants.languageCodes) {
      expect(en.languageName(code), isNot(code));
      expect(it.languageName(code), isNot(code));
    }
    expect(it.languageName('de'), 'Tedesco');
  });

  test('an unknown id or code falls back to itself', () {
    expect(en.genreName(1), '1');
    expect(en.languageName('xx'), 'xx');
  });
}
