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
  String get commonCreate => 'Create';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonFeatured => 'FEATURED';

  @override
  String get commonUnexpectedError => 'An unexpected error occurred';

  @override
  String get commonOk => 'OK';

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
  String detailsErrorLoadingSeason(Object error) {
    return 'Error loading season: $error';
  }

  @override
  String get detailsSeasonNotFound => 'Season details not found';

  @override
  String get detailsDeleteListTitle => 'Delete List?';

  @override
  String detailsDeleteListConfirm(Object name) {
    return 'Are you sure you want to delete \'$name\'?';
  }

  @override
  String get detailsCollectionsTitle => 'Collections';

  @override
  String get detailsCollectionsDesc => 'Your custom themed lists.';

  @override
  String get detailsNewCollection => 'New Collection';

  @override
  String get detailsNoCollections =>
      'No Collections yet. Create one to start organizing!';

  @override
  String get detailsAddToList => 'Add to List';

  @override
  String get detailsNoCustomLists => 'No custom lists yet';

  @override
  String get detailsCreateNewList => 'Create New List';

  @override
  String get detailsMarkPreviousTitle => 'Mark previous?';

  @override
  String detailsMarkPreviousDesc(Object count, Object episode) {
    return 'You marked Episode $episode. Do you also want to mark the $count previous unwatched episode(s) as watched?';
  }

  @override
  String get detailsOnlyThisOne => 'Only this one';

  @override
  String get detailsCollectionNameHint =>
      'Collection Name (e.g., \'Sci-Fi Gems\')';

  @override
  String get homeErrorLoadingFeatures => 'Error loading features';

  @override
  String get homeMoreInfo => 'More Info';

  @override
  String get homeTrendingNow => 'Trending Now';

  @override
  String get homePopularMovies => 'Popular Movies';

  @override
  String get homePopularSeries => 'Popular Series';

  @override
  String get authContinueGuest => 'Continue as Guest';

  @override
  String get authWelcomeBack => 'Welcome Back';

  @override
  String get authJoinCineMuse => 'Join CineMuse';

  @override
  String get authEnterCredentials =>
      'Enter your credentials to access your account';

  @override
  String get authCreateAccount => 'Create an account to start watching';

  @override
  String get authEmail => 'EMAIL';

  @override
  String get authPassword => 'PASSWORD';

  @override
  String get authSignIn => 'Sign In';

  @override
  String get authCreateAccountAction => 'Create Account';

  @override
  String get authNoAccount => 'Don\'t have an account?';

  @override
  String get authHaveAccount => 'Already have an account?';

  @override
  String get authOr => 'OR';

  @override
  String get authDebugLogin => 'Debug Login';

  @override
  String settingsErrorSaving(Object error) {
    return 'Error saving: $error';
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
  String get detailsReviews => 'Reviews';

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
  String get detailsVideos => 'Videos';

  @override
  String get detailsLinks => 'Links';

  @override
  String seasonLabel(Object number) {
    return 'Season $number';
  }

  @override
  String detailsEpisodeNumber(Object num) {
    return 'EP $num';
  }

  @override
  String get detailsReadMore => 'Read more';

  @override
  String get detailsShowLess => 'Show less';

  @override
  String get detailsTooltipWatched => 'Watched';

  @override
  String get detailsTooltipMarkWatched =>
      'Mark as Watched (Long press for date)';

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
  String get playerResolvingYoutube => 'Loading YouTube video...';

  @override
  String playerErrorResolving(Object error) {
    return 'Error resolving stream:\n$error';
  }

  @override
  String playerErrorResolvingYoutube(Object error) {
    return 'Error loading YouTube video:\n$error';
  }

  @override
  String get playerNoAudioFound => 'No audio tracks found';

  @override
  String get playerSubtitles => 'Subtitles';

  @override
  String get playerSelectSubtitle => 'Select Subtitle Track';

  @override
  String get commonGoBack => 'Go Back';

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
  String get settingsUserProfile => 'User Library';

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
  String get settingsProfile => 'Library';

  @override
  String get profileOverview => 'OVERVIEW';

  @override
  String get profileCollections => 'COLLECTIONS';

  @override
  String get profileActivity => 'ACTIVITY';

  @override
  String get profileActivityComingSoon => 'Activity Coming Soon';

  @override
  String get profileUserDashboard => 'User Library';

  @override
  String get profileErrorLoading => 'Error loading library';

  @override
  String profileMemberSince(Object year) {
    return 'Member since $year';
  }

  @override
  String get navLiveTV => 'Live TV';

  @override
  String get liveTvTitle => 'Live TV';

  @override
  String get liveTvSelectChannel => 'Select a channel to start watching';

  @override
  String get liveTvNow => 'NOW';

  @override
  String get liveTvNext => 'NEXT';

  @override
  String get liveTvLive => 'LIVE';

  @override
  String get liveTvNoEpg => 'No program information available';

  @override
  String get liveTvLoading => 'Loading channels...';

  @override
  String get liveTvError => 'Failed to load channels';

  @override
  String get liveTvAllChannels => 'All';

  @override
  String get liveTvHd => 'HD';

  @override
  String get liveTvNoChannels => 'No channels found';

  @override
  String get settingsLiveTvRegion => 'Live TV Region';

  @override
  String get settingsLiveTvRegionDesc =>
      'Select your local region for regional channels.';

  @override
  String get settingsNone => 'None';

  @override
  String get agendaTitle => 'Agenda';

  @override
  String get agendaSubtitle => 'Upcoming releases from your library';

  @override
  String get agendaLoading => 'Checking for updates...';

  @override
  String get agendaNoEvents => 'No upcoming releases found';

  @override
  String get agendaToday => 'Today';

  @override
  String get agendaTomorrow => 'Tomorrow';

  @override
  String get agendaThisWeek => 'This Week';

  @override
  String get agendaNextWeek => 'Next Week';

  @override
  String get agendaLater => 'Later';

  @override
  String get agendaMovie => 'Movie';

  @override
  String get agendaSeries => 'Series';

  @override
  String get agendaRecentlyReleased => 'Recently Released';

  @override
  String get agendaTbd => 'TBD / Coming Soon';

  @override
  String get agendaTbdLabel => 'TBD';

  @override
  String get updateAvailable => 'Update Available';

  @override
  String get updateDialogTitle => 'New version available';

  @override
  String get updateDialogMessage =>
      'A new version of Cinemuse is available. Would you like to update now?';

  @override
  String get updateNow => 'Update Now';

  @override
  String get later => 'Later';

  @override
  String downloadingUpdate(Object progress) {
    return 'Downloading update $progress%';
  }

  @override
  String get updateFailed => 'Update failed. Please try again later.';
}
