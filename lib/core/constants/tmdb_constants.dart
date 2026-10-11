import 'package:cinemuse_app/l10n/app_localizations.dart';

/// TMDB genres and original languages offered in the Explore filters.
/// Names come from [TmdbFilterNames], so they follow the app language.
class TmdbConstants {
  static const List<int> movieGenreIds = [
    28, 12, 16, 35, 80, 99, 18, 10751, 14, 36, //
    27, 10402, 9648, 10749, 878, 10770, 53, 10752, 37,
  ];

  /// TMDB series use their own genre ids (e.g. 10759 instead of 28 + 12).
  static const List<int> tvGenreIds = [
    10759, 16, 35, 80, 99, 18, 10751, 10762, 9648, 10763, //
    10764, 10765, 10766, 10767, 10768, 37,
  ];

  /// ISO 639-1 codes, as TMDB's `with_original_language` expects.
  static const List<String> languageCodes = [
    'en', 'es', 'fr', 'de', 'it', 'pt', 'ru', 'ja', 'ko', 'zh', //
    'hi', 'nl', 'sv', 'da', 'pl', 'tr', 'th', 'id',
  ];
}

/// Translated names for [TmdbConstants.movieGenreIds],
/// [TmdbConstants.tvGenreIds] and
/// [TmdbConstants.languageCodes] (REV-15).
extension TmdbFilterNames on AppLocalizations {
  /// The genre name; the bare id for a genre not in the list.
  String genreName(int id) => switch (id) {
    28 => genreAction,
    12 => genreAdventure,
    16 => genreAnimation,
    35 => genreComedy,
    80 => genreCrime,
    99 => genreDocumentary,
    18 => genreDrama,
    10751 => genreFamily,
    14 => genreFantasy,
    36 => genreHistory,
    27 => genreHorror,
    10402 => genreMusic,
    9648 => genreMystery,
    10749 => genreRomance,
    878 => genreSciFi,
    10770 => genreTVMovie,
    53 => genreThriller,
    10752 => genreWar,
    37 => genreWestern,
    10759 => genreActionAdventure,
    10762 => genreKids,
    10763 => genreNews,
    10764 => genreReality,
    10765 => genreSciFiFantasy,
    10766 => genreSoap,
    10767 => genreTalk,
    10768 => genreWarPolitics,
    _ => '$id',
  };

  /// The language name; the bare code for a language not in the list.
  String languageName(String code) => switch (code) {
    'en' => languageEnglish,
    'es' => languageSpanish,
    'fr' => languageFrench,
    'de' => languageGerman,
    'it' => languageItalian,
    'pt' => languagePortuguese,
    'ru' => languageRussian,
    'ja' => languageJapanese,
    'ko' => languageKorean,
    'zh' => languageChinese,
    'hi' => languageHindi,
    'nl' => languageDutch,
    'sv' => languageSwedish,
    'da' => languageDanish,
    'pl' => languagePolish,
    'tr' => languageTurkish,
    'th' => languageThai,
    'id' => languageIndonesian,
    _ => code,
  };
}
