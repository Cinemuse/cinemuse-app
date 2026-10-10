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
  String get commonClose => 'Close';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonCreate => 'Create';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonClearAll => 'Clear All';

  @override
  String get commonUndo => 'Undo';

  @override
  String get commonFeatured => 'FEATURED';

  @override
  String get commonSeeAll => 'See All';

  @override
  String get commonUnexpectedError => 'An unexpected error occurred';

  @override
  String get commonOk => 'OK';

  @override
  String get commonUnknown => 'Unknown';

  @override
  String get commonAnonymous => 'Anonymous';

  @override
  String get filterMax => 'Max';

  @override
  String get offlineScreenTitle => 'Connection Required';

  @override
  String get offlineScreenMessage =>
      'This feature requires an internet connection to browse content and stream media.';

  @override
  String get searchPlaceholder => 'Search movies, series, people...';

  @override
  String get searchRecentSearches => 'Recent Searches';

  @override
  String get searchHoldToDelete => 'Hold to delete';

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
  String get searchWatchProviders => 'Watch Providers';

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
  String detailsListDeleted(Object name) {
    return 'List \'$name\' deleted.';
  }

  @override
  String get detailsCollectionsTitle => 'Collections';

  @override
  String get detailsCollectionsDesc => 'Your custom themed lists.';

  @override
  String get detailsCollection => 'Collection';

  @override
  String get detailsMoreLikeThis => 'More Like This';

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
  String detailsMarkPreviousDesc(Object count) {
    return 'Do you also want to mark the $count previous unwatched episode(s) as watched?';
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
  String get homeHeroPauseCarousel => 'Pause carousel';

  @override
  String get homeHeroResumeCarousel => 'Resume carousel';

  @override
  String get homeTrendingNow => 'Trending Now';

  @override
  String get homePopularMovies => 'Popular Movies';

  @override
  String get homePopularSeries => 'Popular Series';

  @override
  String get homeContinueWatching => 'Continue Watching';

  @override
  String get homeSportSchedule => 'Sport Schedule';

  @override
  String get sportFootball => 'Football';

  @override
  String get sportBasketball => 'Basketball';

  @override
  String get sportMotorcycling => 'Motorcycling';

  @override
  String get sportVolleyball => 'Volleyball';

  @override
  String get sportAthletics => 'Athletics';

  @override
  String get sportTennis => 'Tennis';

  @override
  String get sportCycling => 'Cycling';

  @override
  String get sportRugby => 'Rugby';

  @override
  String get sportF1 => 'Formula 1';

  @override
  String get sportGeneric => 'Sport Event';

  @override
  String sportWatchOnChannel(String channel) {
    return 'Watch on $channel';
  }

  @override
  String get sportChannelsTitle => 'Channels';

  @override
  String homeRemovedFromContinueWatching(Object title) {
    return 'Removed $title';
  }

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
  String get authWelcomeBackDesc =>
      'Sign in to access your library and settings';

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
  String detailsEpisodeFallback(int number) {
    return 'Episode $number';
  }

  @override
  String detailsEpisodeWithSeason(int season, int episode, String name) {
    return 'S$season E$episode • $name';
  }

  @override
  String get detailsMarkSeasonWatched => 'Mark season as watched';

  @override
  String get detailsSeasonLabel => 'Season';

  @override
  String detailsSeasonsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Seasons',
      one: '1 Season',
    );
    return '$_temp0';
  }

  @override
  String detailsEpisodesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Episodes',
      one: '1 Episode',
    );
    return '$_temp0';
  }

  @override
  String detailsEpisodeRuntime(int minutes) {
    return '${minutes}m/ep';
  }

  @override
  String detailsPlaySeasonEpisode(int season, int episode) {
    return 'Play S$season E$episode';
  }

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
  String get detailsVerdictExcellent => 'Sublime';

  @override
  String get detailsVerdictGood => 'Recommended';

  @override
  String get detailsVerdictAverage => 'Watchable';

  @override
  String get detailsVerdictPoor => 'Forgettable';

  @override
  String get detailsReviews => 'Reviews';

  @override
  String get detailsReviewsAll => 'Read all reviews';

  @override
  String get detailsNoReviews => 'No reviews found.';

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
  String get detailsRemoveAll => 'Clear Watch History';

  @override
  String get detailsSelectDate => 'Select Date';

  @override
  String get detailsConfirm => 'Confirm';

  @override
  String get detailsMarkEntireSeriesPrompt =>
      'Mark the entire series as watched?';

  @override
  String get detailsManageHistorySeriesPrompt =>
      'Manage your history for this series.';

  @override
  String get detailsClearAllSeriesLogsSubtitle =>
      'Clear all logs for all seasons';

  @override
  String get detailsTrackEpisodeProgress =>
      'Track your progress for this episode.';

  @override
  String get detailsMarkRewatch => 'Mark a Rewatch';

  @override
  String get detailsMarkAsWatched => 'Mark as Watched';

  @override
  String get detailsSeeAllDatesWatched => 'See all dates you watched this';

  @override
  String get detailsRemoveOneWatch => 'Remove One Watch';

  @override
  String get detailsDeleteLatestEntry => 'Delete the latest entry';

  @override
  String get detailsClearAllEpisodeLogs => 'Clear all logs for this episode';

  @override
  String get detailsTrackMovieProgress => 'Track your progress for this movie.';

  @override
  String get detailsClearAllMovieLogs => 'Clear all logs for this movie';

  @override
  String detailsWatchedOnDate(String date) {
    return 'Watched on $date';
  }

  @override
  String get detailsWatchHistoryLogs => 'Watch History Logs';

  @override
  String get detailsErrorLoadingHistory => 'Error loading history';

  @override
  String get detailsBudget => 'Budget';

  @override
  String get detailsRevenue => 'Revenue';

  @override
  String get detailsExternalLinks => 'External Links';

  @override
  String get detailsOfficialWebsite => 'Official Website';

  @override
  String get detailsMedia => 'Media';

  @override
  String get detailsLinks => 'Links';

  @override
  String get detailsMore => 'More';

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
  String get detailsGallery => 'Gallery';

  @override
  String get detailsGallerySubtitle => 'Backdrops, posters, and logos';

  @override
  String detailsBackdropsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Backdrops',
      one: '1 Backdrop',
    );
    return '$_temp0';
  }

  @override
  String detailsPostersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Posters',
      one: '1 Poster',
    );
    return '$_temp0';
  }

  @override
  String detailsLogosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Logos',
      one: '1 Logo',
    );
    return '$_temp0';
  }

  @override
  String get detailsNoImages => 'No images available';

  @override
  String get detailsBackdrops => 'Backdrops';

  @override
  String get detailsPosters => 'Posters';

  @override
  String get detailsLogos => 'Logos';

  @override
  String get detailsGalleryPrevious => 'Previous Image';

  @override
  String get detailsGalleryNext => 'Next Image';

  @override
  String get detailsGalleryDownload => 'Download Image';

  @override
  String get detailsGalleryDownloadSuccess => 'Image saved successfully';

  @override
  String get detailsGalleryDownloadFailed => 'Failed to download image';

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
  String get playerSubtitleSize => 'Subtitle Size';

  @override
  String get playerSubtitleDelay => 'Subtitle Delay';

  @override
  String get playerSubtitleDelayReset => 'Reset';

  @override
  String get playerSelectAudio => 'Audio Tracks';

  @override
  String get playerTrackOff => 'Off / Disable';

  @override
  String get playerTrackNoAudio => 'No Audio / Mute';

  @override
  String get playerInternalTracks => 'INTERNAL TRACKS';

  @override
  String get playerAudioTracks => 'AUDIO TRACKS';

  @override
  String get playerExternalTracks => 'EXTERNAL TRACKS';

  @override
  String get playerNoExternalSubtitles => 'No external subtitles found.';

  @override
  String get playerFailedLoadSubtitle => 'Failed to load external subtitle.';

  @override
  String playerSubtitlesCount(int count) {
    return '$count subtitles';
  }

  @override
  String get playerResolving => 'Resolving stream...';

  @override
  String get playerSkipResolution => 'Skip';

  @override
  String get playerTryingNextSource => 'Stream failed, trying next source...';

  @override
  String get playerAllSourcesExhausted =>
      'All sources failed. Please go back and try again.';

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
  String get playerNoQualityOptions =>
      'No quality options available for this stream.';

  @override
  String get youtubeDefaultTitle => 'YouTube Video';

  @override
  String get youtubeStreamLabel => 'YouTube Stream';

  @override
  String get playerResolvingStream => 'Resolving Stream...';

  @override
  String get playerCheckingDebridCache => 'Checking debrid cache';

  @override
  String get sectionVisualArchives => 'Visual Archives';

  @override
  String get failureNetwork =>
      'Can\'t reach the server. Check your connection.';

  @override
  String get failureAuth => 'Please sign in again.';

  @override
  String get failureServer => 'The server had a problem. Try again later.';

  @override
  String get failureNotFound => 'This item couldn\'t be found.';

  @override
  String get failureStreaming => 'This video couldn\'t be played.';

  @override
  String get failureValidation => 'Some data was invalid.';

  @override
  String get failureUnknown => 'Something went wrong.';

  @override
  String get streamingErrorNoProviders =>
      'No streaming addons are enabled. Please check your settings.';

  @override
  String streamingErrorCapabilityMissing(Object category) {
    return 'No enabled addon supports $category. Please check your settings.';
  }

  @override
  String get streamingErrorNoResults => 'No results found across addons.';

  @override
  String get streamingErrorResolutionFailed =>
      'Failed to resolve the selected stream. Link might not be available in cache.';

  @override
  String get streamingErrorMediaDetails => 'Could not fetch media details.';

  @override
  String get streamingErrorImdbId => 'Could not resolve IMDB ID.';

  @override
  String streamingErrorProviderSearchFailed(Object providerName) {
    return 'Search failed for addon: $providerName.';
  }

  @override
  String get playerFiles => 'Files';

  @override
  String playerFilesCount(int count) {
    return '$count files available';
  }

  @override
  String playerProviderFailed(String time) {
    return 'Failed ($time)';
  }

  @override
  String playerProviderResults(int count, String time) {
    return '$count results ($time)';
  }

  @override
  String get playerSkipToPlayback => 'Skip to playback';

  @override
  String get playerSelectFile => 'Select File';

  @override
  String get playerSubtitles => 'Subtitles';

  @override
  String get playerSelectSubtitle => 'Select Subtitle Track';

  @override
  String get commonGoBack => 'Go Back';

  @override
  String get playerNextEpisode => 'Next Episode';

  @override
  String get playerPreviousChannel => 'Previous Channel';

  @override
  String get playerNextChannel => 'Next Channel';

  @override
  String get playerChannelList => 'Channel List';

  @override
  String get playerPlay => 'Play';

  @override
  String get playerPause => 'Pause';

  @override
  String get playerStop => 'Stop';

  @override
  String get playerSkipBackward => 'Rewind 10 seconds';

  @override
  String get playerSkipForward => 'Forward 10 seconds';

  @override
  String get playerSubtitleAppearance => 'Subtitle Appearance';

  @override
  String get playerAppearanceFontSize => 'Font Size';

  @override
  String get playerAppearanceTextColor => 'Text Color';

  @override
  String get playerAppearanceBackground => 'Background Opacity';

  @override
  String get playerAppearanceBottomPadding => 'Bottom Padding';

  @override
  String get playerAppearanceSaveDefault => 'Save as Default';

  @override
  String get playerAppearanceReset => 'Reset to Default';

  @override
  String get playerAppearanceSave => 'Save';

  @override
  String get playerAppearanceSampleText => 'Sample Subtitle Text';

  @override
  String get playerSubtitleSync => 'Subtitle Sync';

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
  String get settingsIntegrations => 'Addons & Extensions';

  @override
  String get settingsIntegrationsDesc =>
      'Manage streaming providers, addons, and external integrations.';

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
  String get settingsProvidersTitle => 'Streaming Addons';

  @override
  String get settingsProvidersDesc => 'Manage your Stremio-compatible addons.';

  @override
  String get settingsAddNewAddon => 'ADD NEW ADDON';

  @override
  String get settingsInstall => 'Install';

  @override
  String get settingsAddonHint =>
      'Paste any Stremio manifest URL to add new content sources.';

  @override
  String get settingsInstalledAddons => 'INSTALLED ADDONS';

  @override
  String get settingsNoAddons => 'No addons installed yet';

  @override
  String get settingsAddonSuccess => 'Addon installed successfully';

  @override
  String get settingsCopiedToClipboard => 'URL copied to clipboard';

  @override
  String get settingsCopy => 'Copy URL';

  @override
  String get settingsRemove => 'Remove';

  @override
  String get settingsNativeIntegrations => 'Native Providers';

  @override
  String get settingsEnableAnimeTosho => 'Enable AnimeTosho';

  @override
  String get settingsEnableVixSrc => 'Enable VixSrc';

  @override
  String get settingsEnableAnimeUnity => 'Enable AnimeUnity';

  @override
  String get settingsEnableAnimeUnityDesc =>
      'Native anime streaming source (No Debrid required)';

  @override
  String get settingsEnableAnimeToshoWarning =>
      'Requires active Real-Debrid integration';

  @override
  String get settingsDebridServices => 'Debrid Services';

  @override
  String get settingsRealDebridTitle => 'Real-Debrid (Native)';

  @override
  String get settingsRealDebridKey => 'Real-Debrid API Key';

  @override
  String get settingsRealDebridKeyDesc =>
      'Used for native sources like AnimeTosho.';

  @override
  String get settingsTorBoxTitle => 'TorBox (Native)';

  @override
  String get settingsTorBoxKey => 'TorBox API Key';

  @override
  String get settingsTorBoxKeyDesc =>
      'Used for native sources like AnimeTosho.';

  @override
  String get settingsPreferredDebridTitle => 'Preferred Debrid Provider';

  @override
  String get settingsPreferredDebridDesc =>
      'Service to prioritize when content is cached on multiple providers.';

  @override
  String get settingsOpenSubtitlesTitle => 'OpenSubtitles.com';

  @override
  String get settingsOpenSubtitlesKey => 'OpenSubtitles API Key';

  @override
  String get settingsOpenSubtitlesKeyDesc =>
      'Used for external subtitle lookup. Requires a free API key.';

  @override
  String get settingsOpenSubtitlesAutoDownloadTitle =>
      'Auto-download missing subtitles';

  @override
  String get settingsOpenSubtitlesAutoDownloadDesc =>
      'Automatically fetch subtitles when your preferred language is missing from the stream. Consumes daily API quota.';

  @override
  String get settingsDisplayName => 'Display Name';

  @override
  String get settingsDisplayNameDesc => 'Your public display name.';

  @override
  String get settingsEnterName => 'Enter your name';

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
      'Preferred audio language for movies and series.';

  @override
  String get settingsSubtitleLanguage => 'Subtitle Language';

  @override
  String get settingsSubtitleLanguageDesc =>
      'Preferred subtitle language for movies and series.';

  @override
  String get settingsShowSubtitles => 'Show Subtitles';

  @override
  String get settingsJapanese => 'Japanese';

  @override
  String get settingsOriginal => 'Original';

  @override
  String get settingsPlayer => 'Media Preferences';

  @override
  String get settingsEnglish => 'English';

  @override
  String get settingsItalian => 'Italian';

  @override
  String get settingsSplitAnimePreferences => 'Split Anime Preferences';

  @override
  String get settingsSplitAnimePreferencesDesc =>
      'Use different audio and subtitle settings for anime.';

  @override
  String get settingsAnimeAudioLanguage => 'Anime Audio Language';

  @override
  String get settingsAnimeAudioLanguageDesc =>
      'Preferred audio language for anime.';

  @override
  String get settingsAnimeShowSubtitles => 'Anime Show Subtitles';

  @override
  String get settingsAnimeShowSubtitlesDesc =>
      'Enable or disable subtitles by default for anime.';

  @override
  String get settingsAnimeSubtitleLanguage => 'Anime Subtitle Language';

  @override
  String get settingsAnimeSubtitleLanguageDesc =>
      'Preferred subtitle language for anime.';

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
  String get settingsSmartSearch => 'Clean Stream Results';

  @override
  String get settingsSmartSearchDesc =>
      'Automatically hide items like CAM, Screener, 3D, or junk from addon results.';

  @override
  String get settingsMaxResolution => 'Max Resolution';

  @override
  String get settingsMaxResolutionDesc =>
      'Hide streams with a resolution higher than the selected one.';

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
  String get liveTvLive => 'Live';

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
  String get liveTvSearchPlaceholder => 'Search channels...';

  @override
  String get settingsLiveTv => 'Live TV';

  @override
  String get settingsLiveTvBufferSize => 'DVR Buffer Size';

  @override
  String get settingsLiveTvBufferSizeDesc =>
      'Maximum amount of history (in MB) to keep in memory/disk for the current channel.';

  @override
  String get settingsLiveTvDiskCache => 'Enable Disk Caching';

  @override
  String get settingsLiveTvDiskCacheDesc =>
      'Use local storage instead of RAM for the DVR buffer. Recommended for large buffers.';

  @override
  String get settingsNone => 'None';

  @override
  String get liveTvCategories => 'Categories';

  @override
  String get liveTvProviders => 'Providers';

  @override
  String get liveTvBrowse => 'Browse';

  @override
  String get liveTvGroupMode => 'Grouping';

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
  String get updateReadyToInstall => 'Update ready to install';

  @override
  String get updateFailed => 'Update failed. Please try again later.';

  @override
  String updateNoCompatibleApk(Object abi) {
    return 'No compatible update found for your device architecture ($abi)';
  }

  @override
  String get updateUpToDate => 'App is up to date';

  @override
  String get updateChangelog => 'What\'s New';

  @override
  String get updateCancel => 'Cancel Update';

  @override
  String get updateNetworkError =>
      'Network error during update. Please check your connection.';

  @override
  String get updateStorageError =>
      'Not enough storage space to download the update.';

  @override
  String get updateSourceError => 'The update source is currently unavailable.';

  @override
  String get menuMoreOptions => 'More Options';

  @override
  String get menuAddToWatchlist => 'Add to Watchlist';

  @override
  String get menuRemoveFromWatchlist => 'Remove from Watchlist';

  @override
  String get menuRemoveFromList => 'Remove from List';

  @override
  String get menuMarkAsWatched => 'Mark as Watched';

  @override
  String get menuMarkAsUnwatched => 'Mark as Unwatched';

  @override
  String get menuShare => 'Share';

  @override
  String get menuResume => 'Resume';

  @override
  String get menuRestart => 'Restart';

  @override
  String get menuClearProgress => 'Clear Progress';

  @override
  String get menuMarkWatchedNow => 'Mark as watched (now)';

  @override
  String get menuMarkWatchedCustomDate => 'Mark as watched (custom date)';

  @override
  String get menuPlay => 'Play';

  @override
  String get menuStopWatching => 'Stop Watching';

  @override
  String get menuCancelRewatch => 'Cancel Rewatch';

  @override
  String get menuRemoveFromContinueWatching => 'Remove from Continue Watching';

  @override
  String get menuRemoveCachedProvider => 'Remove Cached Stream';

  @override
  String get menuManageWatchHistory => 'Manage Watch History';

  @override
  String get liveTvTabAll => 'All';

  @override
  String get liveTvTabFavorites => 'Favorites';

  @override
  String get liveTvTabRecents => 'Recents';

  @override
  String get liveTvFilterChannels => 'Filter Channels';

  @override
  String get liveTvGroupBy => 'Group by';

  @override
  String get liveTvSubProvider => 'Sub-provider';

  @override
  String get liveTvApplyFilters => 'Apply Filters';

  @override
  String get liveTvClearFilters => 'Clear Filters';

  @override
  String get liveTvAddedToFavorites => 'Added to favorites';

  @override
  String get liveTvRemovedFromFavorites => 'Removed from favorites';

  @override
  String get liveTvNoFavorites => 'No favorite channels yet';

  @override
  String get liveTvNoFavoritesHint =>
      'Long-press a channel to add it to favorites';

  @override
  String get liveTvNoRecents => 'No recently watched channels';

  @override
  String get liveTvCustomPlaylists => 'Custom Playlists';

  @override
  String get liveTvCustomPlaylistsDesc =>
      'Add M3U/JSON playlists from URLs or local files.';

  @override
  String get liveTvNoCustomPlaylists => 'No custom playlists added yet';

  @override
  String get liveTvAddUrl => 'Add URL';

  @override
  String get liveTvAddFile => 'Add File';

  @override
  String get liveTvAddRemotePlaylist => 'Add Remote Playlist';

  @override
  String get liveTvPlaylistName => 'Playlist Name';

  @override
  String get liveTvPlaylistUrl => 'Playlist URL';

  @override
  String get liveTvPlaylistFormat => 'Format';

  @override
  String get liveTvOpenFileLocation => 'Open File Location';

  @override
  String get liveTvOpenLink => 'Open Link';

  @override
  String get liveTvManagePlaylists => 'Manage Playlists';

  @override
  String get liveTvTypeM3uFile => 'M3U File';

  @override
  String get liveTvTypeJsonFile => 'JSON File';

  @override
  String get liveTvTypeM3uUrl => 'M3U URL';

  @override
  String get liveTvTypeJsonUrl => 'JSON URL';

  @override
  String get liveTvPlaylists => 'Playlists';

  @override
  String get liveTvFilterAndPlaylists => 'Filter & Playlists';

  @override
  String get liveTvEpgSection => 'TV Guide (EPG)';

  @override
  String get liveTvEpgSectionDesc =>
      'Configure an electronic program guide source for channel schedules.';

  @override
  String get liveTvEpgUrl => 'EPG Guide URL';

  @override
  String get liveTvEpgCustom => 'Custom';

  @override
  String get liveTvEpgDefault => 'Cinemuse Unified (Default)';

  @override
  String get liveTvConfigureEpg => 'Configure EPG';

  @override
  String get liveTvResetEpg => 'Reset to Default';

  @override
  String get liveTvRefreshEpg => 'Refresh Guide';

  @override
  String get liveTvEpgRefreshed => 'EPG guide refreshed successfully';

  @override
  String get liveTvEpgDialogTitle => 'Configure EPG Guide';

  @override
  String get liveTvEpgDialogHint => 'Enter an XMLTV or JSON EPG URL';

  @override
  String get tvTimeComments => 'Comments';

  @override
  String get tvTimeNoComments => 'No comments yet.';

  @override
  String tvTimeReplies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count replies',
      one: '$count reply',
    );
    return '$_temp0';
  }

  @override
  String get tvTimeLoadingComments => 'Loading comments...';

  @override
  String get tvTimeCommentsError => 'Could not load comments.';

  @override
  String get commentsSpoilerWarning => 'Spoiler Warning';

  @override
  String get commentsTapToReveal => 'Tap to reveal';

  @override
  String get commentsSortMostLiked => 'Most Liked';

  @override
  String get commentsSortRecent => 'Recent';

  @override
  String get commentsSortRating => 'Highest Rating';

  @override
  String get commentsFilterAnyLanguage => 'Any Language';

  @override
  String get commentsFilterEnglish => 'English';

  @override
  String get commentsFilterItalian => 'Italian';

  @override
  String get commentsFilterEnIt => 'English + Italian';

  @override
  String get commentsFilterAllSources => 'All Sources';

  @override
  String get commentsSourceSerializd => 'Serializd';

  @override
  String get commentsSourceLetterboxd => 'Letterboxd';

  @override
  String get commentsSourceImdb => 'IMDb';

  @override
  String get settingsSearchPreferences => 'Search Preferences';

  @override
  String get settingsAutoSkipProviders => 'Auto-Skip Slow Providers';

  @override
  String get settingsAutoSkipProvidersDesc =>
      'Skip streaming providers that take longer than 30 seconds to respond.';

  @override
  String get profileRecentMovies => 'Recent Movies';

  @override
  String get profileRecentSeries => 'Recent Series';

  @override
  String get statsTimeBreakdown => 'Time Breakdown';

  @override
  String get statsAllTime => 'All Time';

  @override
  String get statsMovies => 'Movies';

  @override
  String get statsSeries => 'Series';

  @override
  String get statsLast7Days => 'Last 7 Days';

  @override
  String get statsLast30Days => 'Last 30 Days';

  @override
  String get statsLastYear => 'Last Year';

  @override
  String get statsMoviesStats => 'Movies Stats';

  @override
  String get statsSeriesStats => 'Series Stats';

  @override
  String get statsEpisodes => 'Episodes';

  @override
  String get statsSeasons => 'Seasons';

  @override
  String get statsTime => 'Time';

  @override
  String get detailsCreatorsAndDirectors => 'Creators & Directors';

  @override
  String get detailsDirector => 'Director';

  @override
  String get detailsCreator => 'Creator';

  @override
  String get detailsWriter => 'Writer';

  @override
  String get detailsWriters => 'Writers';

  @override
  String get detailsPeople => 'Cast & Crew';

  @override
  String get detailsSectionCrew => 'CREW';

  @override
  String get detailsSectionCast => 'CAST';

  @override
  String get detailsTvTimeComments => 'Comments';

  @override
  String get detailsTrack => 'Track';

  @override
  String get detailsWatched => 'Watched';

  @override
  String detailsWatchedCount(int count) {
    return 'Watched x$count';
  }

  @override
  String get detailsUpToDate => 'Up to date';

  @override
  String detailsUpToDateCount(int count) {
    return 'Up to date x$count';
  }

  @override
  String get detailsFinishSeries => 'Finish Series';

  @override
  String get commonNoContent => 'No content available';

  @override
  String get commonStopCasting => 'STOP CASTING';

  @override
  String get castConnectDevice => 'Connect to device';

  @override
  String get castNoDevices => 'No devices found';

  @override
  String get castRefresh => 'Refresh';

  @override
  String get profileNoRecentItems => 'No recently watched items';

  @override
  String get detailsEditList => 'Edit List';

  @override
  String get detailsDeleteList => 'Delete List';

  @override
  String get detailsTvTimeCommentsNotAvailable =>
      'Comments not available for this media';

  @override
  String get detailsTvTimeCommentsNotAvailableSeries =>
      'Comments not available for this series';

  @override
  String get detailsFailedLoadCollection => 'Failed to load collection details';

  @override
  String get detailsFeaturedCritic => 'Featured Critic';

  @override
  String get offlineBannerTitle => 'Offline Mode';

  @override
  String get offlineBannerMessage => 'Showing locally cached content only.';

  @override
  String get castSearching => 'Searching for devices...';

  @override
  String castError(String error) {
    return 'Error: $error';
  }

  @override
  String castCastingTo(String deviceName) {
    return 'Casting to $deviceName';
  }

  @override
  String castSeasonEpisode(int season, int episode) {
    return 'Season $season • Episode $episode';
  }

  @override
  String statsDaysHours(int days, int hours) {
    return '${days}d ${hours}h';
  }

  @override
  String get listWatchLater => 'Watch Later';

  @override
  String get listFavorites => 'Favorites';

  @override
  String get listYourQueue => 'Your queue';

  @override
  String get listCuratedPicks => 'Your curated picks';

  @override
  String get listDropped => 'Dropped';

  @override
  String get listDroppedSubtitle => 'Titles you interrupted.';

  @override
  String get menuRestoreContinueWatching => 'Restore to Continue Watching';

  @override
  String get listUntitled => 'Untitled List';

  @override
  String get listNameHint => 'List Name';

  @override
  String get listDescriptionHint => 'Add a description...';

  @override
  String listItemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '$count item',
    );
    return '$_temp0';
  }

  @override
  String get listEmptyTitle => 'This list is empty';

  @override
  String get listEmptyMessage => 'Add media from the details page';

  @override
  String get collectionTitleFallback => 'Collection';

  @override
  String get collectionSubtitle => 'Movie Collection';

  @override
  String get listPinToHome => 'Pin to Home';

  @override
  String get listUnpinFromHome => 'Unpin from Home';

  @override
  String get listPinnedSuccess => 'Pinned to Home';

  @override
  String get listUnpinnedSuccess => 'Unpinned from Home';

  @override
  String get playerLiveSources => 'Available Streams';

  @override
  String get playerPreferredQuality => 'Preferred Quality (Default)';

  @override
  String get playerActiveSource => 'Active';

  @override
  String get playerSourceFailed => 'Unavailable';

  @override
  String get watchHistoryTitle => 'Watch History';

  @override
  String watchHistorySubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count titles',
      one: '1 title',
    );
    return '$_temp0';
  }

  @override
  String watchHistoryFilteredCount(int filtered, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total titles',
      one: '1 title',
    );
    return '$filtered of $_temp0';
  }

  @override
  String watchHistoryBreakdown(int movies, int series) {
    String _temp0 = intl.Intl.pluralLogic(
      movies,
      locale: localeName,
      other: '$movies movies',
      one: '1 movie',
    );
    String _temp1 = intl.Intl.pluralLogic(
      series,
      locale: localeName,
      other: '$series series',
      one: '1 series',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String watchHistoryMoviesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count movies',
      one: '1 movie',
    );
    return '$_temp0';
  }

  @override
  String watchHistoryFilteredMoviesCount(int filtered, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total movies',
      one: '1 movie',
    );
    return '$filtered of $_temp0';
  }

  @override
  String watchHistorySeriesBreakdown(int series, int seasons, int episodes) {
    String _temp0 = intl.Intl.pluralLogic(
      series,
      locale: localeName,
      other: '$series series',
      one: '1 series',
    );
    String _temp1 = intl.Intl.pluralLogic(
      seasons,
      locale: localeName,
      other: '$seasons seasons',
      one: '1 season',
    );
    String _temp2 = intl.Intl.pluralLogic(
      episodes,
      locale: localeName,
      other: '$episodes episodes',
      one: '1 episode',
    );
    return '$_temp0, $_temp1, $_temp2';
  }

  @override
  String watchHistoryFilteredSeriesBreakdown(
    int filteredSeries,
    int totalSeries,
    int seasons,
    int episodes,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      totalSeries,
      locale: localeName,
      other: '$totalSeries series',
      one: '1 series',
    );
    String _temp1 = intl.Intl.pluralLogic(
      seasons,
      locale: localeName,
      other: '$seasons seasons',
      one: '1 season',
    );
    String _temp2 = intl.Intl.pluralLogic(
      episodes,
      locale: localeName,
      other: '$episodes episodes',
      one: '1 episode',
    );
    return '$filteredSeries of $_temp0, $_temp1, $_temp2';
  }

  @override
  String get watchHistorySearchPlaceholder => 'Search watched titles...';

  @override
  String get watchHistoryAll => 'All';

  @override
  String get watchHistoryStatusAll => 'All Statuses';

  @override
  String get watchHistoryStatusWatching => 'In Progress';

  @override
  String get watchHistoryStatusCompleted => 'Completed';

  @override
  String get watchHistoryStatusDropped => 'Dropped';

  @override
  String get watchHistorySortRecent => 'Recently Watched';

  @override
  String get watchHistorySortTitle => 'Title (A-Z)';

  @override
  String get watchHistoryViewGrid => 'Grid';

  @override
  String get watchHistoryViewTimeline => 'Timeline';

  @override
  String get watchHistoryDateToday => 'Today';

  @override
  String get watchHistoryDateYesterday => 'Yesterday';

  @override
  String get watchHistoryDateThisWeek => 'This Week';

  @override
  String get watchHistoryDateThisMonth => 'This Month';

  @override
  String get watchHistoryResume => 'Resume';

  @override
  String get watchHistoryWatchAgain => 'Watch Again';

  @override
  String get watchHistoryReplay => 'Replay';

  @override
  String watchHistorySeasonEpisode(int season, int episode) {
    return 'Season $season • Episode $episode';
  }

  @override
  String watchHistoryHoursAgo(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String watchHistoryMinutesAgo(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes ago',
      one: '1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String get watchHistoryEmpty => 'No watch history found';

  @override
  String get watchHistoryGranularityDaily => 'Daily';

  @override
  String get watchHistoryGranularityMonthly => 'Monthly';

  @override
  String get watchHistoryGranularityYearly => 'Yearly';

  @override
  String watchHistoryStackedEpisodes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count episodes',
      one: '1 episode',
    );
    return '$_temp0';
  }

  @override
  String watchHistoryEpisodeRange(int season, int start, int end) {
    return 'S$season E$start–E$end';
  }

  @override
  String watchHistoryMultiSeasonRange(
    int startSeason,
    int startEpisode,
    int endSeason,
    int endEpisode,
  ) {
    return 'S$startSeason E$startEpisode–S$endSeason E$endEpisode';
  }

  @override
  String watchHistorySeasonRange(int startSeason, int endSeason) {
    return 'S$startSeason–S$endSeason';
  }

  @override
  String get watchHistoryFiltersTitle => 'Filters';

  @override
  String get watchHistoryResetFilters => 'Reset';

  @override
  String get watchHistoryApplyFilters => 'Apply Filters';

  @override
  String get watchHistoryFilterType => 'Media Type';

  @override
  String get watchHistoryFilterStatus => 'Watch Status';

  @override
  String get watchHistoryFilterSort => 'Sort By';

  @override
  String get watchHistoryFilterGranularity => 'Timeline Grouping';

  @override
  String watchHistoryActiveFilterCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count filters',
      one: '1 filter',
    );
    return '$_temp0';
  }

  @override
  String get bigPictureMode => 'Big Picture Mode';

  @override
  String get bigPictureModeSubtitle =>
      'Optimized 10-foot UI for TV and remote navigation';

  @override
  String get liveTvFullWindow => 'Full Window';

  @override
  String get liveTvSplitView => 'Split View';

  @override
  String get liveTvChannels => 'Channels';

  @override
  String get liveTvCloseOverlay => 'Close channel list';

  @override
  String get liveTvGoToLive => 'Go to Live';

  @override
  String get playerFullscreen => 'Fullscreen';

  @override
  String get playerExitFullscreen => 'Exit fullscreen';

  @override
  String get seriesStatusOngoing => 'Ongoing';

  @override
  String get menuViewWatchHistory => 'View Watch History';

  @override
  String get liveTvWatchChannel => 'Watch Channel';

  @override
  String get liveTvJumpToNow => 'Jump to Live';

  @override
  String get liveTvTvGuide => 'TV Guide';

  @override
  String get liveTvNoProgramDetails =>
      'No synopsis available for this program.';

  @override
  String liveTvMinutesRemaining(int minutes) {
    return '${minutes}m remaining';
  }

  @override
  String get playerCached => 'CACHED';

  @override
  String get castDefaultDevice => 'Chromecast';

  @override
  String playerErrorPrefix(String error) {
    return 'Error: $error';
  }
}
