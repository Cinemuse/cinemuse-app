// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navHome => 'Home';

  @override
  String get navSearch => 'Search';

  @override
  String get navSettings => 'Settings';

  @override
  String get navLibrary => 'Library';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get commonError => 'Error';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get searchPlaceholder => 'Search movies, series...';

  @override
  String searchNoResults(Object query) {
    return 'No results found for \"$query\"';
  }

  @override
  String get searchEmptyStateTitle => 'Find your next favorite story';

  @override
  String searchItemYear(Object year) {
    return '$year';
  }

  @override
  String get detailsEpisodes => 'Episodes';

  @override
  String get detailsCast => 'Cast';

  @override
  String get detailsPlay => 'Play';

  @override
  String get detailsMyList => 'My List';

  @override
  String detailsErrorLoading(Object error) {
    return 'Error loading details: $error';
  }

  @override
  String seasonLabel(Object number) {
    return 'Season $number';
  }

  @override
  String get playerSettings => 'Settings';

  @override
  String get playerQuality => 'Quality';

  @override
  String get playerAudio => 'Audio';

  @override
  String get playerSelectQuality => 'Select Quality';

  @override
  String get playerSelectAudio => 'Select Audio Track';

  @override
  String get playerResolving => 'Resolving stream with Real-Debrid...';

  @override
  String playerErrorResolving(Object error) {
    return 'Error resolving stream:\n$error';
  }

  @override
  String get playerNoAudioFound => 'No audio tracks found';
}
