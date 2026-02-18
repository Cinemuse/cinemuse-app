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
  String get navExplore => 'Explore';

  @override
  String get navSettings => 'Settings';

  @override
  String get navLibrary => 'Profile';

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
  String get searchPlaceholder => 'Search movies, series, people...';

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
  String get searchMovies => 'Movies';

  @override
  String get searchSeries => 'Series';

  @override
  String get searchPersons => 'Persons';

  @override
  String get searchAdvancedFilters => 'Advanced Filters';

  @override
  String get searchFilterAction => 'Filters';

  @override
  String get searchFilteredResults => 'Results';

  @override
  String get searchSortBy => 'Sort By';

  @override
  String get searchMostPopular => 'Most Popular';

  @override
  String get searchHighestRated => 'Highest Rated';

  @override
  String get searchNewestReleases => 'Newest Releases';

  @override
  String get searchLanguages => 'Languages';

  @override
  String get searchGenres => 'Genres';

  @override
  String get searchRating => 'Rating';

  @override
  String get searchYearRange => 'Year Range';

  @override
  String get searchVoteCount => 'Vote Count';

  @override
  String get searchRuntime => 'Runtime';

  @override
  String get searchClearAll => 'Clear All';

  @override
  String get searchNoResultsTitle => 'No results found';

  @override
  String get searchTryAdjusting => 'Try adjusting your filters';

  @override
  String get searchMatchAny => 'Match Any';

  @override
  String get searchMatchAll => 'Match All';

  @override
  String get searchLanguagePlaceholder => 'Add a language...';

  @override
  String get searchNoLanguagesFound => 'No languages found';

  @override
  String get searchFilteredByPerson => 'Filtered by person';

  @override
  String get searchFilteredByStudio => 'Filtered by studio';

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
  String get detailsDecryptingMetadata => 'Decrypting metadata...';

  @override
  String get detailsEpisodesRegistry => 'Episodes Registry';

  @override
  String get detailsMarkSeasonWatched => 'Mark season as watched';

  @override
  String get detailsSeasonLabel => 'Season';

  @override
  String detailsSeasonNumber(Object num) {
    return 'Season $num';
  }

  @override
  String get detailsSynopsis => 'Synopsis';

  @override
  String detailsResumeEpisode(Object episode, Object season) {
    return 'Resume S$season E$episode';
  }

  @override
  String get detailsResume => 'Resume';

  @override
  String get detailsPlayNow => 'Play Now';

  @override
  String get detailsSeriesProgress => 'Series Progress';

  @override
  String get detailsCreativeVision => 'Creative Vision';

  @override
  String get detailsVerdict => 'Verdict';

  @override
  String get detailsReviewsAll => 'Read all reviews';

  @override
  String get detailsFinances => 'Finances';

  @override
  String get detailsProductionDNA => 'Production DNA';

  @override
  String get detailsRate => 'RATE';

  @override
  String get detailsMarkRemaining => 'Mark Remaining';

  @override
  String get detailsMarkAll => 'Mark All';

  @override
  String get detailsRewatchSeries => 'Rewatch Series';

  @override
  String get detailsRemoveAll => 'Remove All';

  @override
  String get detailsBudget => 'Budget';

  @override
  String get detailsRevenue => 'Revenue';

  @override
  String get detailsExternalLinks => 'External Links';

  @override
  String seasonLabel(Object number) {
    return 'Season $number';
  }

  @override
  String get personBiography => 'Biography';

  @override
  String get personKnownFor => 'Known For';

  @override
  String get personFilmography => 'Filmography';

  @override
  String get personSeen => 'Seen';

  @override
  String get personYearsOld => 'years old';

  @override
  String get personNoImage => 'No image available';

  @override
  String get personShowMore => 'Show More';

  @override
  String get personShowLess => 'Show Less';

  @override
  String get personShowHidden => 'Show Hidden';

  @override
  String personShowingCredits(Object total, Object visible) {
    return 'Showing $visible of $total credits';
  }

  @override
  String get personNoImg => 'No image';

  @override
  String get personSeries => 'Series';

  @override
  String get personMovie => 'Movie';

  @override
  String get playerSettings => 'Settings';

  @override
  String get playerQuality => 'Source';

  @override
  String get playerAudio => 'Audio';

  @override
  String get playerSelectQuality => 'Select Source';

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

  @override
  String get playerSubtitles => 'Subtitles';

  @override
  String get playerSelectSubtitle => 'Select Subtitle Track';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsIdentity => 'Identity & Access';

  @override
  String get settingsIdentityDesc =>
      'Manage your personal details and access preferences.';

  @override
  String get settingsCustomization => 'App Customization';

  @override
  String get settingsCustomizationDesc =>
      'Customize your viewing experience and app appearance.';

  @override
  String get settingsIntegrations => 'Integrations';

  @override
  String get settingsIntegrationsDesc =>
      'Connect third-party services to enhance your experience.';

  @override
  String get settingsData => 'Data & Storage';

  @override
  String get settingsDataDesc => 'Manage your local data and cache.';

  @override
  String get settingsImport => 'Import & Export';

  @override
  String get settingsImportDesc =>
      'Transfer your data to and from other services.';

  @override
  String get settingsDisplayName => 'Display Name';

  @override
  String get settingsDisplayNameDesc => 'Your public display name.';

  @override
  String get settingsEnterName => 'Enter your name';

  @override
  String get settingsEnableRealDebrid => 'Enable Real-Debrid';

  @override
  String get settingsEnableRealDebridDesc =>
      'Enable high-speed streaming via Real-Debrid.';

  @override
  String get settingsRealDebridKey => 'Real-Debrid API Key';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsAppLanguage => 'App Language';

  @override
  String get settingsAppLanguageDesc => 'Change the interface language.';

  @override
  String get settingsAudioLanguage => 'Audio Language';

  @override
  String get settingsAudioLanguageDesc =>
      'Preferred audio language for playback.';

  @override
  String get settingsEnglish => 'English';

  @override
  String get settingsItalian => 'Italian';

  @override
  String get settingsPlayer => 'Player';

  @override
  String get settingsPrimaryColor => 'Primary Color';

  @override
  String get settingsPrimaryColorDesc => 'Main accent color for the player.';

  @override
  String get settingsSecondaryColor => 'Secondary Color';

  @override
  String get settingsSecondaryColorDesc =>
      'Secondary accent color for the player.';

  @override
  String get settingsOther => 'Other';

  @override
  String get settingsShowDebugPanel => 'Show Debug Panel';

  @override
  String get settingsShowDebugPanelDesc => 'Display technical details overlay.';

  @override
  String get settingsSmartSearch => 'Smart Search Filter';

  @override
  String get settingsSmartSearchDesc => 'Intelligently filter search results.';

  @override
  String get settingsTotalDocSize => 'Total Document Size';

  @override
  String get settingsTotalDocSizeDesc => 'Total size of all your stored data.';

  @override
  String get settingsUserProfile => 'User Profile';

  @override
  String get settingsWatchedMovies => 'Watched Movies';

  @override
  String get settingsWatchedSeries => 'Watched Series';

  @override
  String get settingsLists => 'Lists';

  @override
  String get settingsAggregatedStats => 'Aggregated Stats';

  @override
  String get settingsSave => 'Save';

  @override
  String get settingsSaved => 'Saved';

  @override
  String get settingsBack => 'Back to Settings';

  @override
  String get settingsLogout => 'Log out';

  @override
  String get settingsProfile => 'Profile';
}
