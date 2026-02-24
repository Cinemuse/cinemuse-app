import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('it'),
  ];

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get navSearch;

  /// No description provided for @navExplore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get navExplore;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @navLibrary.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navLibrary;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get commonLoading;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get commonError;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @searchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search movies, series, people...'**
  String get searchPlaceholder;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results found for \"{query}\"'**
  String searchNoResults(Object query);

  /// No description provided for @searchEmptyStateTitle.
  ///
  /// In en, this message translates to:
  /// **'Find your next favorite story'**
  String get searchEmptyStateTitle;

  /// No description provided for @searchItemYear.
  ///
  /// In en, this message translates to:
  /// **'{year}'**
  String searchItemYear(Object year);

  /// No description provided for @searchMovies.
  ///
  /// In en, this message translates to:
  /// **'Movies'**
  String get searchMovies;

  /// No description provided for @searchSeries.
  ///
  /// In en, this message translates to:
  /// **'Series'**
  String get searchSeries;

  /// No description provided for @searchPersons.
  ///
  /// In en, this message translates to:
  /// **'Persons'**
  String get searchPersons;

  /// No description provided for @searchAdvancedFilters.
  ///
  /// In en, this message translates to:
  /// **'Advanced Filters'**
  String get searchAdvancedFilters;

  /// No description provided for @searchFilterAction.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get searchFilterAction;

  /// No description provided for @searchFilteredResults.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get searchFilteredResults;

  /// No description provided for @searchSortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort By'**
  String get searchSortBy;

  /// No description provided for @searchMostPopular.
  ///
  /// In en, this message translates to:
  /// **'Most Popular'**
  String get searchMostPopular;

  /// No description provided for @searchHighestRated.
  ///
  /// In en, this message translates to:
  /// **'Highest Rated'**
  String get searchHighestRated;

  /// No description provided for @searchNewestReleases.
  ///
  /// In en, this message translates to:
  /// **'Newest Releases'**
  String get searchNewestReleases;

  /// No description provided for @searchLanguages.
  ///
  /// In en, this message translates to:
  /// **'Languages'**
  String get searchLanguages;

  /// No description provided for @searchGenres.
  ///
  /// In en, this message translates to:
  /// **'Genres'**
  String get searchGenres;

  /// No description provided for @searchRating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get searchRating;

  /// No description provided for @searchYearRange.
  ///
  /// In en, this message translates to:
  /// **'Year Range'**
  String get searchYearRange;

  /// No description provided for @searchVoteCount.
  ///
  /// In en, this message translates to:
  /// **'Vote Count'**
  String get searchVoteCount;

  /// No description provided for @searchRuntime.
  ///
  /// In en, this message translates to:
  /// **'Runtime'**
  String get searchRuntime;

  /// No description provided for @searchClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get searchClearAll;

  /// No description provided for @searchNoResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get searchNoResultsTitle;

  /// No description provided for @searchTryAdjusting.
  ///
  /// In en, this message translates to:
  /// **'Try adjusting your filters'**
  String get searchTryAdjusting;

  /// No description provided for @searchMatchAny.
  ///
  /// In en, this message translates to:
  /// **'Match Any'**
  String get searchMatchAny;

  /// No description provided for @searchMatchAll.
  ///
  /// In en, this message translates to:
  /// **'Match All'**
  String get searchMatchAll;

  /// No description provided for @searchLanguagePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Add a language...'**
  String get searchLanguagePlaceholder;

  /// No description provided for @searchNoLanguagesFound.
  ///
  /// In en, this message translates to:
  /// **'No languages found'**
  String get searchNoLanguagesFound;

  /// No description provided for @searchFilteredByPerson.
  ///
  /// In en, this message translates to:
  /// **'Filtered by person'**
  String get searchFilteredByPerson;

  /// No description provided for @searchFilteredByStudio.
  ///
  /// In en, this message translates to:
  /// **'Filtered by studio'**
  String get searchFilteredByStudio;

  /// No description provided for @detailsEpisodes.
  ///
  /// In en, this message translates to:
  /// **'Episodes'**
  String get detailsEpisodes;

  /// No description provided for @detailsCast.
  ///
  /// In en, this message translates to:
  /// **'Cast'**
  String get detailsCast;

  /// No description provided for @detailsPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get detailsPlay;

  /// No description provided for @detailsMyList.
  ///
  /// In en, this message translates to:
  /// **'My List'**
  String get detailsMyList;

  /// No description provided for @detailsErrorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error loading details: {error}'**
  String detailsErrorLoading(Object error);

  /// No description provided for @detailsDecryptingMetadata.
  ///
  /// In en, this message translates to:
  /// **'Decrypting metadata...'**
  String get detailsDecryptingMetadata;

  /// No description provided for @detailsEpisodesRegistry.
  ///
  /// In en, this message translates to:
  /// **'Episodes Registry'**
  String get detailsEpisodesRegistry;

  /// No description provided for @detailsMarkSeasonWatched.
  ///
  /// In en, this message translates to:
  /// **'Mark season as watched'**
  String get detailsMarkSeasonWatched;

  /// No description provided for @detailsSeasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Season'**
  String get detailsSeasonLabel;

  /// No description provided for @detailsSeasonNumber.
  ///
  /// In en, this message translates to:
  /// **'Season {num}'**
  String detailsSeasonNumber(Object num);

  /// No description provided for @detailsSynopsis.
  ///
  /// In en, this message translates to:
  /// **'Synopsis'**
  String get detailsSynopsis;

  /// No description provided for @detailsResumeEpisode.
  ///
  /// In en, this message translates to:
  /// **'Resume S{season} E{episode}'**
  String detailsResumeEpisode(Object episode, Object season);

  /// No description provided for @detailsResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get detailsResume;

  /// No description provided for @detailsPlayNow.
  ///
  /// In en, this message translates to:
  /// **'Play Now'**
  String get detailsPlayNow;

  /// No description provided for @detailsSeriesProgress.
  ///
  /// In en, this message translates to:
  /// **'Series Progress'**
  String get detailsSeriesProgress;

  /// No description provided for @detailsCreativeVision.
  ///
  /// In en, this message translates to:
  /// **'Creative Vision'**
  String get detailsCreativeVision;

  /// No description provided for @detailsVerdict.
  ///
  /// In en, this message translates to:
  /// **'Verdict'**
  String get detailsVerdict;

  /// No description provided for @detailsReviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get detailsReviews;

  /// No description provided for @detailsReviewsAll.
  ///
  /// In en, this message translates to:
  /// **'Read all reviews'**
  String get detailsReviewsAll;

  /// No description provided for @detailsFinances.
  ///
  /// In en, this message translates to:
  /// **'Finances'**
  String get detailsFinances;

  /// No description provided for @detailsProductionDNA.
  ///
  /// In en, this message translates to:
  /// **'Production DNA'**
  String get detailsProductionDNA;

  /// No description provided for @detailsRate.
  ///
  /// In en, this message translates to:
  /// **'RATE'**
  String get detailsRate;

  /// No description provided for @detailsMarkRemaining.
  ///
  /// In en, this message translates to:
  /// **'Mark Remaining'**
  String get detailsMarkRemaining;

  /// No description provided for @detailsMarkAll.
  ///
  /// In en, this message translates to:
  /// **'Mark All'**
  String get detailsMarkAll;

  /// No description provided for @detailsRewatchSeries.
  ///
  /// In en, this message translates to:
  /// **'Rewatch Series'**
  String get detailsRewatchSeries;

  /// No description provided for @detailsRemoveAll.
  ///
  /// In en, this message translates to:
  /// **'Remove All'**
  String get detailsRemoveAll;

  /// No description provided for @detailsBudget.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get detailsBudget;

  /// No description provided for @detailsRevenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get detailsRevenue;

  /// No description provided for @detailsExternalLinks.
  ///
  /// In en, this message translates to:
  /// **'External Links'**
  String get detailsExternalLinks;

  /// No description provided for @detailsVideos.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get detailsVideos;

  /// No description provided for @detailsLinks.
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get detailsLinks;

  /// No description provided for @seasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Season {number}'**
  String seasonLabel(Object number);

  /// No description provided for @personBiography.
  ///
  /// In en, this message translates to:
  /// **'Biography'**
  String get personBiography;

  /// No description provided for @personKnownFor.
  ///
  /// In en, this message translates to:
  /// **'Known For'**
  String get personKnownFor;

  /// No description provided for @personFilmography.
  ///
  /// In en, this message translates to:
  /// **'Filmography'**
  String get personFilmography;

  /// No description provided for @personSeen.
  ///
  /// In en, this message translates to:
  /// **'Seen'**
  String get personSeen;

  /// No description provided for @personYearsOld.
  ///
  /// In en, this message translates to:
  /// **'years old'**
  String get personYearsOld;

  /// No description provided for @personNoImage.
  ///
  /// In en, this message translates to:
  /// **'No image available'**
  String get personNoImage;

  /// No description provided for @personShowMore.
  ///
  /// In en, this message translates to:
  /// **'Show More'**
  String get personShowMore;

  /// No description provided for @personShowLess.
  ///
  /// In en, this message translates to:
  /// **'Show Less'**
  String get personShowLess;

  /// No description provided for @personShowHidden.
  ///
  /// In en, this message translates to:
  /// **'Show Hidden'**
  String get personShowHidden;

  /// No description provided for @personShowingCredits.
  ///
  /// In en, this message translates to:
  /// **'Showing {visible} of {total} credits'**
  String personShowingCredits(Object total, Object visible);

  /// No description provided for @personNoImg.
  ///
  /// In en, this message translates to:
  /// **'No image'**
  String get personNoImg;

  /// No description provided for @personSeries.
  ///
  /// In en, this message translates to:
  /// **'Series'**
  String get personSeries;

  /// No description provided for @personMovie.
  ///
  /// In en, this message translates to:
  /// **'Movie'**
  String get personMovie;

  /// No description provided for @playerSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get playerSettings;

  /// No description provided for @playerQuality.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get playerQuality;

  /// No description provided for @playerAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get playerAudio;

  /// No description provided for @playerSelectQuality.
  ///
  /// In en, this message translates to:
  /// **'Select Source'**
  String get playerSelectQuality;

  /// No description provided for @playerSelectAudio.
  ///
  /// In en, this message translates to:
  /// **'Select Audio Track'**
  String get playerSelectAudio;

  /// No description provided for @playerResolving.
  ///
  /// In en, this message translates to:
  /// **'Resolving stream with Real-Debrid...'**
  String get playerResolving;

  /// No description provided for @playerErrorResolving.
  ///
  /// In en, this message translates to:
  /// **'Error resolving stream:\n{error}'**
  String playerErrorResolving(Object error);

  /// No description provided for @playerNoAudioFound.
  ///
  /// In en, this message translates to:
  /// **'No audio tracks found'**
  String get playerNoAudioFound;

  /// No description provided for @playerSubtitles.
  ///
  /// In en, this message translates to:
  /// **'Subtitles'**
  String get playerSubtitles;

  /// No description provided for @playerSelectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select Subtitle Track'**
  String get playerSelectSubtitle;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsIdentity.
  ///
  /// In en, this message translates to:
  /// **'Identity & Access'**
  String get settingsIdentity;

  /// No description provided for @settingsIdentityDesc.
  ///
  /// In en, this message translates to:
  /// **'Manage your personal details and access preferences.'**
  String get settingsIdentityDesc;

  /// No description provided for @settingsCustomization.
  ///
  /// In en, this message translates to:
  /// **'App Customization'**
  String get settingsCustomization;

  /// No description provided for @settingsCustomizationDesc.
  ///
  /// In en, this message translates to:
  /// **'Customize your viewing experience and app appearance.'**
  String get settingsCustomizationDesc;

  /// No description provided for @settingsIntegrations.
  ///
  /// In en, this message translates to:
  /// **'Integrations'**
  String get settingsIntegrations;

  /// No description provided for @settingsIntegrationsDesc.
  ///
  /// In en, this message translates to:
  /// **'Connect third-party services to enhance your experience.'**
  String get settingsIntegrationsDesc;

  /// No description provided for @settingsData.
  ///
  /// In en, this message translates to:
  /// **'Data & Storage'**
  String get settingsData;

  /// No description provided for @settingsDataDesc.
  ///
  /// In en, this message translates to:
  /// **'Manage your local data and cache.'**
  String get settingsDataDesc;

  /// No description provided for @settingsImport.
  ///
  /// In en, this message translates to:
  /// **'Import & Export'**
  String get settingsImport;

  /// No description provided for @settingsImportDesc.
  ///
  /// In en, this message translates to:
  /// **'Transfer your data to and from other services.'**
  String get settingsImportDesc;

  /// No description provided for @settingsDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get settingsDisplayName;

  /// No description provided for @settingsDisplayNameDesc.
  ///
  /// In en, this message translates to:
  /// **'Your public display name.'**
  String get settingsDisplayNameDesc;

  /// No description provided for @settingsEnterName.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get settingsEnterName;

  /// No description provided for @settingsEnableRealDebrid.
  ///
  /// In en, this message translates to:
  /// **'Enable Real-Debrid'**
  String get settingsEnableRealDebrid;

  /// No description provided for @settingsEnableRealDebridDesc.
  ///
  /// In en, this message translates to:
  /// **'Enable high-speed streaming via Real-Debrid.'**
  String get settingsEnableRealDebridDesc;

  /// No description provided for @settingsRealDebridKey.
  ///
  /// In en, this message translates to:
  /// **'Real-Debrid API Key'**
  String get settingsRealDebridKey;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsAppLanguage.
  ///
  /// In en, this message translates to:
  /// **'App Language'**
  String get settingsAppLanguage;

  /// No description provided for @settingsAppLanguageDesc.
  ///
  /// In en, this message translates to:
  /// **'Change the interface language.'**
  String get settingsAppLanguageDesc;

  /// No description provided for @settingsAudioLanguage.
  ///
  /// In en, this message translates to:
  /// **'Audio Language'**
  String get settingsAudioLanguage;

  /// No description provided for @settingsAudioLanguageDesc.
  ///
  /// In en, this message translates to:
  /// **'Preferred audio language for playback.'**
  String get settingsAudioLanguageDesc;

  /// No description provided for @settingsEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsEnglish;

  /// No description provided for @settingsItalian.
  ///
  /// In en, this message translates to:
  /// **'Italian'**
  String get settingsItalian;

  /// No description provided for @settingsPlayer.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get settingsPlayer;

  /// No description provided for @settingsPrimaryColor.
  ///
  /// In en, this message translates to:
  /// **'Primary Color'**
  String get settingsPrimaryColor;

  /// No description provided for @settingsPrimaryColorDesc.
  ///
  /// In en, this message translates to:
  /// **'Main accent color for the player.'**
  String get settingsPrimaryColorDesc;

  /// No description provided for @settingsSecondaryColor.
  ///
  /// In en, this message translates to:
  /// **'Secondary Color'**
  String get settingsSecondaryColor;

  /// No description provided for @settingsSecondaryColorDesc.
  ///
  /// In en, this message translates to:
  /// **'Secondary accent color for the player.'**
  String get settingsSecondaryColorDesc;

  /// No description provided for @settingsOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get settingsOther;

  /// No description provided for @settingsShowDebugPanel.
  ///
  /// In en, this message translates to:
  /// **'Show Debug Panel'**
  String get settingsShowDebugPanel;

  /// No description provided for @settingsShowDebugPanelDesc.
  ///
  /// In en, this message translates to:
  /// **'Display technical details overlay.'**
  String get settingsShowDebugPanelDesc;

  /// No description provided for @settingsSmartSearch.
  ///
  /// In en, this message translates to:
  /// **'Smart Search Filter'**
  String get settingsSmartSearch;

  /// No description provided for @settingsSmartSearchDesc.
  ///
  /// In en, this message translates to:
  /// **'Intelligently filter search results.'**
  String get settingsSmartSearchDesc;

  /// No description provided for @settingsTotalDocSize.
  ///
  /// In en, this message translates to:
  /// **'Total Document Size'**
  String get settingsTotalDocSize;

  /// No description provided for @settingsTotalDocSizeDesc.
  ///
  /// In en, this message translates to:
  /// **'Total size of all your stored data.'**
  String get settingsTotalDocSizeDesc;

  /// No description provided for @settingsUserProfile.
  ///
  /// In en, this message translates to:
  /// **'User Profile'**
  String get settingsUserProfile;

  /// No description provided for @settingsWatchedMovies.
  ///
  /// In en, this message translates to:
  /// **'Watched Movies'**
  String get settingsWatchedMovies;

  /// No description provided for @settingsWatchedSeries.
  ///
  /// In en, this message translates to:
  /// **'Watched Series'**
  String get settingsWatchedSeries;

  /// No description provided for @settingsLists.
  ///
  /// In en, this message translates to:
  /// **'Lists'**
  String get settingsLists;

  /// No description provided for @settingsAggregatedStats.
  ///
  /// In en, this message translates to:
  /// **'Aggregated Stats'**
  String get settingsAggregatedStats;

  /// No description provided for @settingsSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get settingsSave;

  /// No description provided for @settingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get settingsSaved;

  /// No description provided for @settingsBack.
  ///
  /// In en, this message translates to:
  /// **'Back to Settings'**
  String get settingsBack;

  /// No description provided for @settingsLogout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get settingsLogout;

  /// No description provided for @settingsProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get settingsProfile;

  /// No description provided for @navLiveTV.
  ///
  /// In en, this message translates to:
  /// **'Live TV'**
  String get navLiveTV;

  /// No description provided for @liveTvTitle.
  ///
  /// In en, this message translates to:
  /// **'Live TV'**
  String get liveTvTitle;

  /// No description provided for @liveTvSelectChannel.
  ///
  /// In en, this message translates to:
  /// **'Select a channel to start watching'**
  String get liveTvSelectChannel;

  /// No description provided for @liveTvNow.
  ///
  /// In en, this message translates to:
  /// **'NOW'**
  String get liveTvNow;

  /// No description provided for @liveTvNext.
  ///
  /// In en, this message translates to:
  /// **'NEXT'**
  String get liveTvNext;

  /// No description provided for @liveTvLive.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get liveTvLive;

  /// No description provided for @liveTvNoEpg.
  ///
  /// In en, this message translates to:
  /// **'No program information available'**
  String get liveTvNoEpg;

  /// No description provided for @liveTvLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading channels...'**
  String get liveTvLoading;

  /// No description provided for @liveTvError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load channels'**
  String get liveTvError;

  /// No description provided for @liveTvAllChannels.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get liveTvAllChannels;

  /// No description provided for @liveTvHd.
  ///
  /// In en, this message translates to:
  /// **'HD'**
  String get liveTvHd;

  /// No description provided for @liveTvNoChannels.
  ///
  /// In en, this message translates to:
  /// **'No channels found'**
  String get liveTvNoChannels;

  /// No description provided for @settingsLiveTvRegion.
  ///
  /// In en, this message translates to:
  /// **'Live TV Region'**
  String get settingsLiveTvRegion;

  /// No description provided for @settingsLiveTvRegionDesc.
  ///
  /// In en, this message translates to:
  /// **'Select your local region for regional channels.'**
  String get settingsLiveTvRegionDesc;

  /// No description provided for @settingsNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get settingsNone;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
