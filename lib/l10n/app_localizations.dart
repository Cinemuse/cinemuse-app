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
  /// **'Library'**
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

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get commonCreate;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get commonClearAll;

  /// No description provided for @commonUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get commonUndo;

  /// No description provided for @commonFeatured.
  ///
  /// In en, this message translates to:
  /// **'FEATURED'**
  String get commonFeatured;

  /// No description provided for @commonUnexpectedError.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred'**
  String get commonUnexpectedError;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get commonUnknown;

  /// No description provided for @commonAnonymous.
  ///
  /// In en, this message translates to:
  /// **'Anonymous'**
  String get commonAnonymous;

  /// No description provided for @filterMax.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get filterMax;

  /// No description provided for @offlineScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection Required'**
  String get offlineScreenTitle;

  /// No description provided for @offlineScreenMessage.
  ///
  /// In en, this message translates to:
  /// **'This feature requires an internet connection to browse content and stream media.'**
  String get offlineScreenMessage;

  /// No description provided for @searchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search movies, series, people...'**
  String get searchPlaceholder;

  /// No description provided for @searchRecentSearches.
  ///
  /// In en, this message translates to:
  /// **'Recent Searches'**
  String get searchRecentSearches;

  /// No description provided for @searchHoldToDelete.
  ///
  /// In en, this message translates to:
  /// **'Hold to delete'**
  String get searchHoldToDelete;

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
  /// **'People'**
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

  /// No description provided for @searchWatchProviders.
  ///
  /// In en, this message translates to:
  /// **'Watch Providers'**
  String get searchWatchProviders;

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

  /// No description provided for @detailsErrorLoadingSeason.
  ///
  /// In en, this message translates to:
  /// **'Error loading season: {error}'**
  String detailsErrorLoadingSeason(Object error);

  /// No description provided for @detailsSeasonNotFound.
  ///
  /// In en, this message translates to:
  /// **'Season details not found'**
  String get detailsSeasonNotFound;

  /// No description provided for @detailsDeleteListTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete List?'**
  String get detailsDeleteListTitle;

  /// No description provided for @detailsDeleteListConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \'{name}\'?'**
  String detailsDeleteListConfirm(Object name);

  /// No description provided for @detailsListDeleted.
  ///
  /// In en, this message translates to:
  /// **'List \'{name}\' deleted.'**
  String detailsListDeleted(Object name);

  /// No description provided for @detailsCollectionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Collections'**
  String get detailsCollectionsTitle;

  /// No description provided for @detailsCollectionsDesc.
  ///
  /// In en, this message translates to:
  /// **'Your custom themed lists.'**
  String get detailsCollectionsDesc;

  /// No description provided for @detailsCollection.
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get detailsCollection;

  /// No description provided for @detailsMoreLikeThis.
  ///
  /// In en, this message translates to:
  /// **'More Like This'**
  String get detailsMoreLikeThis;

  /// No description provided for @detailsNewCollection.
  ///
  /// In en, this message translates to:
  /// **'New Collection'**
  String get detailsNewCollection;

  /// No description provided for @detailsNoCollections.
  ///
  /// In en, this message translates to:
  /// **'No Collections yet. Create one to start organizing!'**
  String get detailsNoCollections;

  /// No description provided for @detailsAddToList.
  ///
  /// In en, this message translates to:
  /// **'Add to List'**
  String get detailsAddToList;

  /// No description provided for @detailsNoCustomLists.
  ///
  /// In en, this message translates to:
  /// **'No custom lists yet'**
  String get detailsNoCustomLists;

  /// No description provided for @detailsCreateNewList.
  ///
  /// In en, this message translates to:
  /// **'Create New List'**
  String get detailsCreateNewList;

  /// No description provided for @detailsMarkPreviousTitle.
  ///
  /// In en, this message translates to:
  /// **'Mark previous?'**
  String get detailsMarkPreviousTitle;

  /// No description provided for @detailsMarkPreviousDesc.
  ///
  /// In en, this message translates to:
  /// **'Do you also want to mark the {count} previous unwatched episode(s) as watched?'**
  String detailsMarkPreviousDesc(Object count);

  /// No description provided for @detailsOnlyThisOne.
  ///
  /// In en, this message translates to:
  /// **'Only this one'**
  String get detailsOnlyThisOne;

  /// No description provided for @detailsCollectionNameHint.
  ///
  /// In en, this message translates to:
  /// **'Collection Name (e.g., \'Sci-Fi Gems\')'**
  String get detailsCollectionNameHint;

  /// No description provided for @homeErrorLoadingFeatures.
  ///
  /// In en, this message translates to:
  /// **'Error loading features'**
  String get homeErrorLoadingFeatures;

  /// No description provided for @homeMoreInfo.
  ///
  /// In en, this message translates to:
  /// **'More Info'**
  String get homeMoreInfo;

  /// No description provided for @homeHeroPauseCarousel.
  ///
  /// In en, this message translates to:
  /// **'Pause carousel'**
  String get homeHeroPauseCarousel;

  /// No description provided for @homeHeroResumeCarousel.
  ///
  /// In en, this message translates to:
  /// **'Resume carousel'**
  String get homeHeroResumeCarousel;

  /// No description provided for @homeTrendingNow.
  ///
  /// In en, this message translates to:
  /// **'Trending Now'**
  String get homeTrendingNow;

  /// No description provided for @homePopularMovies.
  ///
  /// In en, this message translates to:
  /// **'Popular Movies'**
  String get homePopularMovies;

  /// No description provided for @homePopularSeries.
  ///
  /// In en, this message translates to:
  /// **'Popular Series'**
  String get homePopularSeries;

  /// No description provided for @homeContinueWatching.
  ///
  /// In en, this message translates to:
  /// **'Continue Watching'**
  String get homeContinueWatching;

  /// No description provided for @homeSportSchedule.
  ///
  /// In en, this message translates to:
  /// **'Sport Schedule'**
  String get homeSportSchedule;

  /// No description provided for @sportFootball.
  ///
  /// In en, this message translates to:
  /// **'Football'**
  String get sportFootball;

  /// No description provided for @sportBasketball.
  ///
  /// In en, this message translates to:
  /// **'Basketball'**
  String get sportBasketball;

  /// No description provided for @sportMotorcycling.
  ///
  /// In en, this message translates to:
  /// **'Motorcycling'**
  String get sportMotorcycling;

  /// No description provided for @sportVolleyball.
  ///
  /// In en, this message translates to:
  /// **'Volleyball'**
  String get sportVolleyball;

  /// No description provided for @sportAthletics.
  ///
  /// In en, this message translates to:
  /// **'Athletics'**
  String get sportAthletics;

  /// No description provided for @sportTennis.
  ///
  /// In en, this message translates to:
  /// **'Tennis'**
  String get sportTennis;

  /// No description provided for @sportCycling.
  ///
  /// In en, this message translates to:
  /// **'Cycling'**
  String get sportCycling;

  /// No description provided for @sportRugby.
  ///
  /// In en, this message translates to:
  /// **'Rugby'**
  String get sportRugby;

  /// No description provided for @sportF1.
  ///
  /// In en, this message translates to:
  /// **'Formula 1'**
  String get sportF1;

  /// No description provided for @sportGeneric.
  ///
  /// In en, this message translates to:
  /// **'Sport Event'**
  String get sportGeneric;

  /// No description provided for @sportWatchOnChannel.
  ///
  /// In en, this message translates to:
  /// **'Watch on {channel}'**
  String sportWatchOnChannel(String channel);

  /// No description provided for @sportChannelsTitle.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get sportChannelsTitle;

  /// No description provided for @homeRemovedFromContinueWatching.
  ///
  /// In en, this message translates to:
  /// **'Removed {title}'**
  String homeRemovedFromContinueWatching(Object title);

  /// No description provided for @authContinueGuest.
  ///
  /// In en, this message translates to:
  /// **'Continue as Guest'**
  String get authContinueGuest;

  /// No description provided for @authWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get authWelcomeBack;

  /// No description provided for @authEnterCredentials.
  ///
  /// In en, this message translates to:
  /// **'Enter your credentials to access your account'**
  String get authEnterCredentials;

  /// No description provided for @authWelcomeBackDesc.
  ///
  /// In en, this message translates to:
  /// **'Sign in to access your library and settings'**
  String get authWelcomeBackDesc;

  /// No description provided for @authEmail.
  ///
  /// In en, this message translates to:
  /// **'EMAIL'**
  String get authEmail;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'PASSWORD'**
  String get authPassword;

  /// No description provided for @authSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get authSignIn;

  /// No description provided for @authOr.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get authOr;

  /// No description provided for @authDebugLogin.
  ///
  /// In en, this message translates to:
  /// **'Debug Login'**
  String get authDebugLogin;

  /// No description provided for @settingsErrorSaving.
  ///
  /// In en, this message translates to:
  /// **'Error saving: {error}'**
  String settingsErrorSaving(Object error);

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

  /// No description provided for @detailsEpisodeFallback.
  ///
  /// In en, this message translates to:
  /// **'Episode {number}'**
  String detailsEpisodeFallback(int number);

  /// No description provided for @detailsEpisodeWithSeason.
  ///
  /// In en, this message translates to:
  /// **'S{season} E{episode} • {name}'**
  String detailsEpisodeWithSeason(int season, int episode, String name);

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

  /// No description provided for @detailsSeasonsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Season} other{{count} Seasons}}'**
  String detailsSeasonsCount(int count);

  /// No description provided for @detailsEpisodesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Episode} other{{count} Episodes}}'**
  String detailsEpisodesCount(int count);

  /// No description provided for @detailsEpisodeRuntime.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m/ep'**
  String detailsEpisodeRuntime(int minutes);

  /// No description provided for @detailsPlaySeasonEpisode.
  ///
  /// In en, this message translates to:
  /// **'Play S{season} E{episode}'**
  String detailsPlaySeasonEpisode(int season, int episode);

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

  /// No description provided for @detailsVerdictExcellent.
  ///
  /// In en, this message translates to:
  /// **'Sublime'**
  String get detailsVerdictExcellent;

  /// No description provided for @detailsVerdictGood.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get detailsVerdictGood;

  /// No description provided for @detailsVerdictAverage.
  ///
  /// In en, this message translates to:
  /// **'Watchable'**
  String get detailsVerdictAverage;

  /// No description provided for @detailsVerdictPoor.
  ///
  /// In en, this message translates to:
  /// **'Forgettable'**
  String get detailsVerdictPoor;

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

  /// No description provided for @detailsNoReviews.
  ///
  /// In en, this message translates to:
  /// **'No reviews found.'**
  String get detailsNoReviews;

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
  /// **'Clear Watch History'**
  String get detailsRemoveAll;

  /// No description provided for @detailsSelectDate.
  ///
  /// In en, this message translates to:
  /// **'Select Date'**
  String get detailsSelectDate;

  /// No description provided for @detailsConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get detailsConfirm;

  /// No description provided for @detailsMarkEntireSeriesPrompt.
  ///
  /// In en, this message translates to:
  /// **'Mark the entire series as watched?'**
  String get detailsMarkEntireSeriesPrompt;

  /// No description provided for @detailsManageHistorySeriesPrompt.
  ///
  /// In en, this message translates to:
  /// **'Manage your history for this series.'**
  String get detailsManageHistorySeriesPrompt;

  /// No description provided for @detailsClearAllSeriesLogsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Clear all logs for all seasons'**
  String get detailsClearAllSeriesLogsSubtitle;

  /// No description provided for @detailsTrackEpisodeProgress.
  ///
  /// In en, this message translates to:
  /// **'Track your progress for this episode.'**
  String get detailsTrackEpisodeProgress;

  /// No description provided for @detailsMarkRewatch.
  ///
  /// In en, this message translates to:
  /// **'Mark a Rewatch'**
  String get detailsMarkRewatch;

  /// No description provided for @detailsMarkAsWatched.
  ///
  /// In en, this message translates to:
  /// **'Mark as Watched'**
  String get detailsMarkAsWatched;

  /// No description provided for @detailsSeeAllDatesWatched.
  ///
  /// In en, this message translates to:
  /// **'See all dates you watched this'**
  String get detailsSeeAllDatesWatched;

  /// No description provided for @detailsRemoveOneWatch.
  ///
  /// In en, this message translates to:
  /// **'Remove One Watch'**
  String get detailsRemoveOneWatch;

  /// No description provided for @detailsDeleteLatestEntry.
  ///
  /// In en, this message translates to:
  /// **'Delete the latest entry'**
  String get detailsDeleteLatestEntry;

  /// No description provided for @detailsClearAllEpisodeLogs.
  ///
  /// In en, this message translates to:
  /// **'Clear all logs for this episode'**
  String get detailsClearAllEpisodeLogs;

  /// No description provided for @detailsTrackMovieProgress.
  ///
  /// In en, this message translates to:
  /// **'Track your progress for this movie.'**
  String get detailsTrackMovieProgress;

  /// No description provided for @detailsClearAllMovieLogs.
  ///
  /// In en, this message translates to:
  /// **'Clear all logs for this movie'**
  String get detailsClearAllMovieLogs;

  /// No description provided for @detailsWatchedOnDate.
  ///
  /// In en, this message translates to:
  /// **'Watched on {date}'**
  String detailsWatchedOnDate(String date);

  /// No description provided for @detailsWatchHistoryLogs.
  ///
  /// In en, this message translates to:
  /// **'Watch History Logs'**
  String get detailsWatchHistoryLogs;

  /// No description provided for @detailsErrorLoadingHistory.
  ///
  /// In en, this message translates to:
  /// **'Error loading history'**
  String get detailsErrorLoadingHistory;

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

  /// No description provided for @detailsOfficialWebsite.
  ///
  /// In en, this message translates to:
  /// **'Official Website'**
  String get detailsOfficialWebsite;

  /// No description provided for @detailsMedia.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get detailsMedia;

  /// No description provided for @detailsLinks.
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get detailsLinks;

  /// No description provided for @detailsMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get detailsMore;

  /// No description provided for @seasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Season {number}'**
  String seasonLabel(Object number);

  /// No description provided for @detailsEpisodeNumber.
  ///
  /// In en, this message translates to:
  /// **'EP {num}'**
  String detailsEpisodeNumber(Object num);

  /// No description provided for @detailsReadMore.
  ///
  /// In en, this message translates to:
  /// **'Read more'**
  String get detailsReadMore;

  /// No description provided for @detailsShowLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get detailsShowLess;

  /// No description provided for @detailsTooltipWatched.
  ///
  /// In en, this message translates to:
  /// **'Watched'**
  String get detailsTooltipWatched;

  /// No description provided for @detailsTooltipMarkWatched.
  ///
  /// In en, this message translates to:
  /// **'Mark as Watched (Long press for date)'**
  String get detailsTooltipMarkWatched;

  /// No description provided for @detailsGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get detailsGallery;

  /// No description provided for @detailsGallerySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Backdrops, posters, and logos'**
  String get detailsGallerySubtitle;

  /// No description provided for @detailsBackdropsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Backdrop} other{{count} Backdrops}}'**
  String detailsBackdropsCount(int count);

  /// No description provided for @detailsPostersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Poster} other{{count} Posters}}'**
  String detailsPostersCount(int count);

  /// No description provided for @detailsLogosCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Logo} other{{count} Logos}}'**
  String detailsLogosCount(int count);

  /// No description provided for @detailsNoImages.
  ///
  /// In en, this message translates to:
  /// **'No images available'**
  String get detailsNoImages;

  /// No description provided for @detailsBackdrops.
  ///
  /// In en, this message translates to:
  /// **'Backdrops'**
  String get detailsBackdrops;

  /// No description provided for @detailsPosters.
  ///
  /// In en, this message translates to:
  /// **'Posters'**
  String get detailsPosters;

  /// No description provided for @detailsLogos.
  ///
  /// In en, this message translates to:
  /// **'Logos'**
  String get detailsLogos;

  /// No description provided for @detailsGalleryPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous Image'**
  String get detailsGalleryPrevious;

  /// No description provided for @detailsGalleryNext.
  ///
  /// In en, this message translates to:
  /// **'Next Image'**
  String get detailsGalleryNext;

  /// No description provided for @detailsGalleryDownload.
  ///
  /// In en, this message translates to:
  /// **'Download Image'**
  String get detailsGalleryDownload;

  /// No description provided for @detailsGalleryDownloadSuccess.
  ///
  /// In en, this message translates to:
  /// **'Image saved successfully'**
  String get detailsGalleryDownloadSuccess;

  /// No description provided for @detailsGalleryDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to download image'**
  String get detailsGalleryDownloadFailed;

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

  /// No description provided for @playerSubtitleSize.
  ///
  /// In en, this message translates to:
  /// **'Subtitle Size'**
  String get playerSubtitleSize;

  /// No description provided for @playerSubtitleDelay.
  ///
  /// In en, this message translates to:
  /// **'Subtitle Delay'**
  String get playerSubtitleDelay;

  /// No description provided for @playerSubtitleDelayReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get playerSubtitleDelayReset;

  /// No description provided for @playerSelectAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio Tracks'**
  String get playerSelectAudio;

  /// No description provided for @playerTrackOff.
  ///
  /// In en, this message translates to:
  /// **'Off / Disable'**
  String get playerTrackOff;

  /// No description provided for @playerTrackNoAudio.
  ///
  /// In en, this message translates to:
  /// **'No Audio / Mute'**
  String get playerTrackNoAudio;

  /// No description provided for @playerInternalTracks.
  ///
  /// In en, this message translates to:
  /// **'INTERNAL TRACKS'**
  String get playerInternalTracks;

  /// No description provided for @playerAudioTracks.
  ///
  /// In en, this message translates to:
  /// **'AUDIO TRACKS'**
  String get playerAudioTracks;

  /// No description provided for @playerExternalTracks.
  ///
  /// In en, this message translates to:
  /// **'EXTERNAL TRACKS'**
  String get playerExternalTracks;

  /// No description provided for @playerNoExternalSubtitles.
  ///
  /// In en, this message translates to:
  /// **'No external subtitles found.'**
  String get playerNoExternalSubtitles;

  /// No description provided for @playerFailedLoadSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Failed to load external subtitle.'**
  String get playerFailedLoadSubtitle;

  /// No description provided for @playerSubtitlesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} subtitles'**
  String playerSubtitlesCount(int count);

  /// No description provided for @playerResolving.
  ///
  /// In en, this message translates to:
  /// **'Resolving stream...'**
  String get playerResolving;

  /// No description provided for @playerSkipResolution.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get playerSkipResolution;

  /// No description provided for @playerTryingNextSource.
  ///
  /// In en, this message translates to:
  /// **'Stream failed, trying next source...'**
  String get playerTryingNextSource;

  /// No description provided for @playerAllSourcesExhausted.
  ///
  /// In en, this message translates to:
  /// **'All sources failed. Please go back and try again.'**
  String get playerAllSourcesExhausted;

  /// No description provided for @playerResolvingYoutube.
  ///
  /// In en, this message translates to:
  /// **'Loading YouTube video...'**
  String get playerResolvingYoutube;

  /// No description provided for @playerErrorResolving.
  ///
  /// In en, this message translates to:
  /// **'Error resolving stream:\n{error}'**
  String playerErrorResolving(Object error);

  /// No description provided for @playerYoutubeBlocked.
  ///
  /// In en, this message translates to:
  /// **'This trailer can\'t be played in the app.\nYouTube sometimes blocks apps like this one. You can watch it on YouTube instead.'**
  String get playerYoutubeBlocked;

  /// No description provided for @playerOpenOnYoutube.
  ///
  /// In en, this message translates to:
  /// **'Open on YouTube'**
  String get playerOpenOnYoutube;

  /// No description provided for @playerOpenOnYoutubeFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open YouTube on this device.'**
  String get playerOpenOnYoutubeFailed;

  /// No description provided for @playerNoAudioFound.
  ///
  /// In en, this message translates to:
  /// **'No audio tracks found'**
  String get playerNoAudioFound;

  /// No description provided for @playerNoQualityOptions.
  ///
  /// In en, this message translates to:
  /// **'No quality options available for this stream.'**
  String get playerNoQualityOptions;

  /// No description provided for @youtubeDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'YouTube Video'**
  String get youtubeDefaultTitle;

  /// No description provided for @youtubeStreamLabel.
  ///
  /// In en, this message translates to:
  /// **'YouTube Stream'**
  String get youtubeStreamLabel;

  /// No description provided for @playerResolvingStream.
  ///
  /// In en, this message translates to:
  /// **'Resolving Stream...'**
  String get playerResolvingStream;

  /// No description provided for @playerCheckingDebridCache.
  ///
  /// In en, this message translates to:
  /// **'Checking debrid cache'**
  String get playerCheckingDebridCache;

  /// No description provided for @sectionVisualArchives.
  ///
  /// In en, this message translates to:
  /// **'Visual Archives'**
  String get sectionVisualArchives;

  /// No description provided for @failureNetwork.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the server. Check your connection.'**
  String get failureNetwork;

  /// No description provided for @failureAuth.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again.'**
  String get failureAuth;

  /// No description provided for @failureServer.
  ///
  /// In en, this message translates to:
  /// **'The server had a problem. Try again later.'**
  String get failureServer;

  /// No description provided for @failureNotFound.
  ///
  /// In en, this message translates to:
  /// **'This item couldn\'t be found.'**
  String get failureNotFound;

  /// No description provided for @failureStreaming.
  ///
  /// In en, this message translates to:
  /// **'This video couldn\'t be played.'**
  String get failureStreaming;

  /// No description provided for @failureValidation.
  ///
  /// In en, this message translates to:
  /// **'Some data was invalid.'**
  String get failureValidation;

  /// No description provided for @failureUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get failureUnknown;

  /// No description provided for @shellPressBackAgainToExit.
  ///
  /// In en, this message translates to:
  /// **'Press Back again to exit'**
  String get shellPressBackAgainToExit;

  /// No description provided for @errorTimeout.
  ///
  /// In en, this message translates to:
  /// **'Connection timed out. Check your connection.'**
  String get errorTimeout;

  /// No description provided for @errorServerStatus.
  ///
  /// In en, this message translates to:
  /// **'The server returned an error ({statusCode}).'**
  String errorServerStatus(Object statusCode);

  /// No description provided for @errorCertificateHint.
  ///
  /// In en, this message translates to:
  /// **'Your system might be missing some root certificates. Try updating Windows or check your firewall/DNS.'**
  String get errorCertificateHint;

  /// No description provided for @authErrorInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password.'**
  String get authErrorInvalidCredentials;

  /// No description provided for @authErrorEmailNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your email address.'**
  String get authErrorEmailNotConfirmed;

  /// No description provided for @authErrorUserExists.
  ///
  /// In en, this message translates to:
  /// **'An account with this email already exists.'**
  String get authErrorUserExists;

  /// No description provided for @authErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Sign in failed. Please try again.'**
  String get authErrorGeneric;

  /// No description provided for @updatePreparingInstaller.
  ///
  /// In en, this message translates to:
  /// **'Preparing to launch the installer...'**
  String get updatePreparingInstaller;

  /// No description provided for @updateRestarting.
  ///
  /// In en, this message translates to:
  /// **'Files swapped. Restarting in a moment...'**
  String get updateRestarting;

  /// No description provided for @updatePleaseWait.
  ///
  /// In en, this message translates to:
  /// **'Please wait while we prepare the new version. Do not close the app.'**
  String get updatePleaseWait;

  /// No description provided for @genreAction.
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get genreAction;

  /// No description provided for @genreAdventure.
  ///
  /// In en, this message translates to:
  /// **'Adventure'**
  String get genreAdventure;

  /// No description provided for @genreAnimation.
  ///
  /// In en, this message translates to:
  /// **'Animation'**
  String get genreAnimation;

  /// No description provided for @genreComedy.
  ///
  /// In en, this message translates to:
  /// **'Comedy'**
  String get genreComedy;

  /// No description provided for @genreCrime.
  ///
  /// In en, this message translates to:
  /// **'Crime'**
  String get genreCrime;

  /// No description provided for @genreDocumentary.
  ///
  /// In en, this message translates to:
  /// **'Documentary'**
  String get genreDocumentary;

  /// No description provided for @genreDrama.
  ///
  /// In en, this message translates to:
  /// **'Drama'**
  String get genreDrama;

  /// No description provided for @genreFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get genreFamily;

  /// No description provided for @genreFantasy.
  ///
  /// In en, this message translates to:
  /// **'Fantasy'**
  String get genreFantasy;

  /// No description provided for @genreHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get genreHistory;

  /// No description provided for @genreHorror.
  ///
  /// In en, this message translates to:
  /// **'Horror'**
  String get genreHorror;

  /// No description provided for @genreMusic.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get genreMusic;

  /// No description provided for @genreMystery.
  ///
  /// In en, this message translates to:
  /// **'Mystery'**
  String get genreMystery;

  /// No description provided for @genreRomance.
  ///
  /// In en, this message translates to:
  /// **'Romance'**
  String get genreRomance;

  /// No description provided for @genreSciFi.
  ///
  /// In en, this message translates to:
  /// **'Sci-Fi'**
  String get genreSciFi;

  /// No description provided for @genreTVMovie.
  ///
  /// In en, this message translates to:
  /// **'TV Movie'**
  String get genreTVMovie;

  /// No description provided for @genreThriller.
  ///
  /// In en, this message translates to:
  /// **'Thriller'**
  String get genreThriller;

  /// No description provided for @genreWar.
  ///
  /// In en, this message translates to:
  /// **'War'**
  String get genreWar;

  /// No description provided for @genreWestern.
  ///
  /// In en, this message translates to:
  /// **'Western'**
  String get genreWestern;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageSpanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get languageSpanish;

  /// No description provided for @languageFrench.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get languageFrench;

  /// No description provided for @languageGerman.
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get languageGerman;

  /// No description provided for @languageItalian.
  ///
  /// In en, this message translates to:
  /// **'Italian'**
  String get languageItalian;

  /// No description provided for @languagePortuguese.
  ///
  /// In en, this message translates to:
  /// **'Portuguese'**
  String get languagePortuguese;

  /// No description provided for @languageRussian.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get languageRussian;

  /// No description provided for @languageJapanese.
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get languageJapanese;

  /// No description provided for @languageKorean.
  ///
  /// In en, this message translates to:
  /// **'Korean'**
  String get languageKorean;

  /// No description provided for @languageChinese.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get languageChinese;

  /// No description provided for @languageHindi.
  ///
  /// In en, this message translates to:
  /// **'Hindi'**
  String get languageHindi;

  /// No description provided for @languageDutch.
  ///
  /// In en, this message translates to:
  /// **'Dutch'**
  String get languageDutch;

  /// No description provided for @languageSwedish.
  ///
  /// In en, this message translates to:
  /// **'Swedish'**
  String get languageSwedish;

  /// No description provided for @languageDanish.
  ///
  /// In en, this message translates to:
  /// **'Danish'**
  String get languageDanish;

  /// No description provided for @languagePolish.
  ///
  /// In en, this message translates to:
  /// **'Polish'**
  String get languagePolish;

  /// No description provided for @languageTurkish.
  ///
  /// In en, this message translates to:
  /// **'Turkish'**
  String get languageTurkish;

  /// No description provided for @languageThai.
  ///
  /// In en, this message translates to:
  /// **'Thai'**
  String get languageThai;

  /// No description provided for @languageIndonesian.
  ///
  /// In en, this message translates to:
  /// **'Indonesian'**
  String get languageIndonesian;

  /// No description provided for @streamingErrorNoProviders.
  ///
  /// In en, this message translates to:
  /// **'No streaming addons are enabled. Please check your settings.'**
  String get streamingErrorNoProviders;

  /// No description provided for @streamingErrorCapabilityMissing.
  ///
  /// In en, this message translates to:
  /// **'No enabled addon supports {category}. Please check your settings.'**
  String streamingErrorCapabilityMissing(Object category);

  /// No description provided for @streamingErrorNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results found across addons.'**
  String get streamingErrorNoResults;

  /// No description provided for @streamingErrorResolutionFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to resolve the selected stream. Link might not be available in cache.'**
  String get streamingErrorResolutionFailed;

  /// No description provided for @streamingErrorMediaDetails.
  ///
  /// In en, this message translates to:
  /// **'Could not fetch media details.'**
  String get streamingErrorMediaDetails;

  /// No description provided for @streamingErrorImdbId.
  ///
  /// In en, this message translates to:
  /// **'Could not resolve IMDB ID.'**
  String get streamingErrorImdbId;

  /// No description provided for @streamingErrorProviderSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search failed for addon: {providerName}.'**
  String streamingErrorProviderSearchFailed(Object providerName);

  /// No description provided for @playerFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get playerFiles;

  /// No description provided for @playerFilesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} files available'**
  String playerFilesCount(int count);

  /// No description provided for @playerProviderFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed ({time})'**
  String playerProviderFailed(String time);

  /// No description provided for @playerProviderResults.
  ///
  /// In en, this message translates to:
  /// **'{count} results ({time})'**
  String playerProviderResults(int count, String time);

  /// No description provided for @playerSkipToPlayback.
  ///
  /// In en, this message translates to:
  /// **'Skip to playback'**
  String get playerSkipToPlayback;

  /// No description provided for @playerSelectFile.
  ///
  /// In en, this message translates to:
  /// **'Select File'**
  String get playerSelectFile;

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

  /// No description provided for @commonGoBack.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get commonGoBack;

  /// No description provided for @playerNextEpisode.
  ///
  /// In en, this message translates to:
  /// **'Next Episode'**
  String get playerNextEpisode;

  /// No description provided for @playerPreviousChannel.
  ///
  /// In en, this message translates to:
  /// **'Previous Channel'**
  String get playerPreviousChannel;

  /// No description provided for @playerNextChannel.
  ///
  /// In en, this message translates to:
  /// **'Next Channel'**
  String get playerNextChannel;

  /// No description provided for @playerChannelList.
  ///
  /// In en, this message translates to:
  /// **'Channel List'**
  String get playerChannelList;

  /// No description provided for @playerPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get playerPlay;

  /// No description provided for @playerPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get playerPause;

  /// No description provided for @playerStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get playerStop;

  /// No description provided for @playerSkipBackward.
  ///
  /// In en, this message translates to:
  /// **'Rewind 10 seconds'**
  String get playerSkipBackward;

  /// No description provided for @playerSkipForward.
  ///
  /// In en, this message translates to:
  /// **'Forward 10 seconds'**
  String get playerSkipForward;

  /// No description provided for @playerSubtitleAppearance.
  ///
  /// In en, this message translates to:
  /// **'Subtitle Appearance'**
  String get playerSubtitleAppearance;

  /// No description provided for @playerAppearanceFontSize.
  ///
  /// In en, this message translates to:
  /// **'Font Size'**
  String get playerAppearanceFontSize;

  /// No description provided for @playerAppearanceTextColor.
  ///
  /// In en, this message translates to:
  /// **'Text Color'**
  String get playerAppearanceTextColor;

  /// No description provided for @playerAppearanceBackground.
  ///
  /// In en, this message translates to:
  /// **'Background Opacity'**
  String get playerAppearanceBackground;

  /// No description provided for @playerAppearanceBottomPadding.
  ///
  /// In en, this message translates to:
  /// **'Bottom Padding'**
  String get playerAppearanceBottomPadding;

  /// No description provided for @playerAppearanceSaveDefault.
  ///
  /// In en, this message translates to:
  /// **'Save as Default'**
  String get playerAppearanceSaveDefault;

  /// No description provided for @playerAppearanceReset.
  ///
  /// In en, this message translates to:
  /// **'Reset to Default'**
  String get playerAppearanceReset;

  /// No description provided for @playerAppearanceSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get playerAppearanceSave;

  /// No description provided for @playerAppearanceSampleText.
  ///
  /// In en, this message translates to:
  /// **'Sample Subtitle Text'**
  String get playerAppearanceSampleText;

  /// No description provided for @playerSubtitleSync.
  ///
  /// In en, this message translates to:
  /// **'Subtitle Sync'**
  String get playerSubtitleSync;

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
  /// **'Addons & Extensions'**
  String get settingsIntegrations;

  /// No description provided for @settingsIntegrationsDesc.
  ///
  /// In en, this message translates to:
  /// **'Manage streaming providers, addons, and external integrations.'**
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

  /// No description provided for @settingsProvidersTitle.
  ///
  /// In en, this message translates to:
  /// **'Streaming Addons'**
  String get settingsProvidersTitle;

  /// No description provided for @settingsProvidersDesc.
  ///
  /// In en, this message translates to:
  /// **'Manage your Stremio-compatible addons.'**
  String get settingsProvidersDesc;

  /// No description provided for @settingsAddNewAddon.
  ///
  /// In en, this message translates to:
  /// **'ADD NEW ADDON'**
  String get settingsAddNewAddon;

  /// No description provided for @settingsInstall.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get settingsInstall;

  /// No description provided for @settingsAddonHint.
  ///
  /// In en, this message translates to:
  /// **'Paste any Stremio manifest URL to add new content sources.'**
  String get settingsAddonHint;

  /// No description provided for @settingsInstalledAddons.
  ///
  /// In en, this message translates to:
  /// **'INSTALLED ADDONS'**
  String get settingsInstalledAddons;

  /// No description provided for @settingsNoAddons.
  ///
  /// In en, this message translates to:
  /// **'No addons installed yet'**
  String get settingsNoAddons;

  /// No description provided for @settingsAddonSuccess.
  ///
  /// In en, this message translates to:
  /// **'Addon installed successfully'**
  String get settingsAddonSuccess;

  /// No description provided for @settingsAddonInvalid.
  ///
  /// In en, this message translates to:
  /// **'This isn\'t a valid Stremio add-on link.'**
  String get settingsAddonInvalid;

  /// No description provided for @settingsCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'URL copied to clipboard'**
  String get settingsCopiedToClipboard;

  /// No description provided for @settingsCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy URL'**
  String get settingsCopy;

  /// No description provided for @settingsRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get settingsRemove;

  /// No description provided for @settingsNativeIntegrations.
  ///
  /// In en, this message translates to:
  /// **'Native Providers'**
  String get settingsNativeIntegrations;

  /// No description provided for @settingsEnableAnimeTosho.
  ///
  /// In en, this message translates to:
  /// **'Enable AnimeTosho'**
  String get settingsEnableAnimeTosho;

  /// No description provided for @settingsEnableVixSrc.
  ///
  /// In en, this message translates to:
  /// **'Enable VixSrc'**
  String get settingsEnableVixSrc;

  /// No description provided for @settingsEnableAnimeUnity.
  ///
  /// In en, this message translates to:
  /// **'Enable AnimeUnity'**
  String get settingsEnableAnimeUnity;

  /// No description provided for @settingsEnableAnimeUnityDesc.
  ///
  /// In en, this message translates to:
  /// **'Native anime streaming source (No Debrid required)'**
  String get settingsEnableAnimeUnityDesc;

  /// No description provided for @settingsEnableAnimeToshoWarning.
  ///
  /// In en, this message translates to:
  /// **'Requires active Real-Debrid integration'**
  String get settingsEnableAnimeToshoWarning;

  /// No description provided for @settingsDebridServices.
  ///
  /// In en, this message translates to:
  /// **'Debrid Services'**
  String get settingsDebridServices;

  /// No description provided for @settingsRealDebridTitle.
  ///
  /// In en, this message translates to:
  /// **'Real-Debrid (Native)'**
  String get settingsRealDebridTitle;

  /// No description provided for @settingsRealDebridKey.
  ///
  /// In en, this message translates to:
  /// **'Real-Debrid API Key'**
  String get settingsRealDebridKey;

  /// No description provided for @settingsRealDebridKeyDesc.
  ///
  /// In en, this message translates to:
  /// **'Used for native sources like AnimeTosho.'**
  String get settingsRealDebridKeyDesc;

  /// No description provided for @settingsTorBoxTitle.
  ///
  /// In en, this message translates to:
  /// **'TorBox (Native)'**
  String get settingsTorBoxTitle;

  /// No description provided for @settingsTorBoxKey.
  ///
  /// In en, this message translates to:
  /// **'TorBox API Key'**
  String get settingsTorBoxKey;

  /// No description provided for @settingsTorBoxKeyDesc.
  ///
  /// In en, this message translates to:
  /// **'Used for native sources like AnimeTosho.'**
  String get settingsTorBoxKeyDesc;

  /// No description provided for @settingsPreferredDebridTitle.
  ///
  /// In en, this message translates to:
  /// **'Preferred Debrid Provider'**
  String get settingsPreferredDebridTitle;

  /// No description provided for @settingsPreferredDebridDesc.
  ///
  /// In en, this message translates to:
  /// **'Service to prioritize when content is cached on multiple providers.'**
  String get settingsPreferredDebridDesc;

  /// No description provided for @settingsOpenSubtitlesTitle.
  ///
  /// In en, this message translates to:
  /// **'OpenSubtitles.com'**
  String get settingsOpenSubtitlesTitle;

  /// No description provided for @settingsOpenSubtitlesKey.
  ///
  /// In en, this message translates to:
  /// **'OpenSubtitles API Key'**
  String get settingsOpenSubtitlesKey;

  /// No description provided for @settingsOpenSubtitlesKeyDesc.
  ///
  /// In en, this message translates to:
  /// **'Used for external subtitle lookup. Requires a free API key.'**
  String get settingsOpenSubtitlesKeyDesc;

  /// No description provided for @settingsOpenSubtitlesAutoDownloadTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-download missing subtitles'**
  String get settingsOpenSubtitlesAutoDownloadTitle;

  /// No description provided for @settingsOpenSubtitlesAutoDownloadDesc.
  ///
  /// In en, this message translates to:
  /// **'Automatically fetch subtitles when your preferred language is missing from the stream. Consumes daily API quota.'**
  String get settingsOpenSubtitlesAutoDownloadDesc;

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
  /// **'Preferred audio language for movies and series.'**
  String get settingsAudioLanguageDesc;

  /// No description provided for @settingsSubtitleLanguage.
  ///
  /// In en, this message translates to:
  /// **'Subtitle Language'**
  String get settingsSubtitleLanguage;

  /// No description provided for @settingsSubtitleLanguageDesc.
  ///
  /// In en, this message translates to:
  /// **'Preferred subtitle language for movies and series.'**
  String get settingsSubtitleLanguageDesc;

  /// No description provided for @settingsShowSubtitles.
  ///
  /// In en, this message translates to:
  /// **'Show Subtitles'**
  String get settingsShowSubtitles;

  /// No description provided for @settingsJapanese.
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get settingsJapanese;

  /// No description provided for @settingsOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get settingsOriginal;

  /// No description provided for @settingsPlayer.
  ///
  /// In en, this message translates to:
  /// **'Media Preferences'**
  String get settingsPlayer;

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

  /// No description provided for @settingsSplitAnimePreferences.
  ///
  /// In en, this message translates to:
  /// **'Split Anime Preferences'**
  String get settingsSplitAnimePreferences;

  /// No description provided for @settingsSplitAnimePreferencesDesc.
  ///
  /// In en, this message translates to:
  /// **'Use different audio and subtitle settings for anime.'**
  String get settingsSplitAnimePreferencesDesc;

  /// No description provided for @settingsAnimeAudioLanguage.
  ///
  /// In en, this message translates to:
  /// **'Anime Audio Language'**
  String get settingsAnimeAudioLanguage;

  /// No description provided for @settingsAnimeAudioLanguageDesc.
  ///
  /// In en, this message translates to:
  /// **'Preferred audio language for anime.'**
  String get settingsAnimeAudioLanguageDesc;

  /// No description provided for @settingsAnimeShowSubtitles.
  ///
  /// In en, this message translates to:
  /// **'Anime Show Subtitles'**
  String get settingsAnimeShowSubtitles;

  /// No description provided for @settingsAnimeShowSubtitlesDesc.
  ///
  /// In en, this message translates to:
  /// **'Enable or disable subtitles by default for anime.'**
  String get settingsAnimeShowSubtitlesDesc;

  /// No description provided for @settingsAnimeSubtitleLanguage.
  ///
  /// In en, this message translates to:
  /// **'Anime Subtitle Language'**
  String get settingsAnimeSubtitleLanguage;

  /// No description provided for @settingsAnimeSubtitleLanguageDesc.
  ///
  /// In en, this message translates to:
  /// **'Preferred subtitle language for anime.'**
  String get settingsAnimeSubtitleLanguageDesc;

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
  /// **'Clean Stream Results'**
  String get settingsSmartSearch;

  /// No description provided for @settingsSmartSearchDesc.
  ///
  /// In en, this message translates to:
  /// **'Automatically hide items like CAM, Screener, 3D, or junk from addon results.'**
  String get settingsSmartSearchDesc;

  /// No description provided for @settingsMaxResolution.
  ///
  /// In en, this message translates to:
  /// **'Max Resolution'**
  String get settingsMaxResolution;

  /// No description provided for @settingsMaxResolutionDesc.
  ///
  /// In en, this message translates to:
  /// **'Hide streams with a resolution higher than the selected one.'**
  String get settingsMaxResolutionDesc;

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
  /// **'User Library'**
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
  /// **'Library'**
  String get settingsProfile;

  /// No description provided for @profileOverview.
  ///
  /// In en, this message translates to:
  /// **'OVERVIEW'**
  String get profileOverview;

  /// No description provided for @profileCollections.
  ///
  /// In en, this message translates to:
  /// **'COLLECTIONS'**
  String get profileCollections;

  /// No description provided for @profileActivity.
  ///
  /// In en, this message translates to:
  /// **'ACTIVITY'**
  String get profileActivity;

  /// No description provided for @profileActivityComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Activity Coming Soon'**
  String get profileActivityComingSoon;

  /// No description provided for @profileUserDashboard.
  ///
  /// In en, this message translates to:
  /// **'User Library'**
  String get profileUserDashboard;

  /// No description provided for @profileErrorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error loading library'**
  String get profileErrorLoading;

  /// No description provided for @profileMemberSince.
  ///
  /// In en, this message translates to:
  /// **'Member since {year}'**
  String profileMemberSince(Object year);

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
  /// **'Live'**
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

  /// No description provided for @liveTvSearchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search channels...'**
  String get liveTvSearchPlaceholder;

  /// No description provided for @settingsLiveTv.
  ///
  /// In en, this message translates to:
  /// **'Live TV'**
  String get settingsLiveTv;

  /// No description provided for @settingsLiveTvBufferSize.
  ///
  /// In en, this message translates to:
  /// **'DVR Buffer Size'**
  String get settingsLiveTvBufferSize;

  /// No description provided for @settingsLiveTvBufferSizeDesc.
  ///
  /// In en, this message translates to:
  /// **'Maximum amount of history (in MB) to keep in memory/disk for the current channel.'**
  String get settingsLiveTvBufferSizeDesc;

  /// No description provided for @settingsLiveTvDiskCache.
  ///
  /// In en, this message translates to:
  /// **'Enable Disk Caching'**
  String get settingsLiveTvDiskCache;

  /// No description provided for @settingsLiveTvDiskCacheDesc.
  ///
  /// In en, this message translates to:
  /// **'Use local storage instead of RAM for the DVR buffer. Recommended for large buffers.'**
  String get settingsLiveTvDiskCacheDesc;

  /// No description provided for @settingsNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get settingsNone;

  /// No description provided for @liveTvCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get liveTvCategories;

  /// No description provided for @liveTvProviders.
  ///
  /// In en, this message translates to:
  /// **'Providers'**
  String get liveTvProviders;

  /// No description provided for @liveTvBrowse.
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get liveTvBrowse;

  /// No description provided for @liveTvGroupMode.
  ///
  /// In en, this message translates to:
  /// **'Grouping'**
  String get liveTvGroupMode;

  /// No description provided for @agendaTitle.
  ///
  /// In en, this message translates to:
  /// **'Agenda'**
  String get agendaTitle;

  /// No description provided for @agendaSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upcoming releases from your library'**
  String get agendaSubtitle;

  /// No description provided for @agendaLoading.
  ///
  /// In en, this message translates to:
  /// **'Checking for updates...'**
  String get agendaLoading;

  /// No description provided for @agendaNoEvents.
  ///
  /// In en, this message translates to:
  /// **'No upcoming releases found'**
  String get agendaNoEvents;

  /// No description provided for @agendaToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get agendaToday;

  /// No description provided for @agendaTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get agendaTomorrow;

  /// No description provided for @agendaThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get agendaThisWeek;

  /// No description provided for @agendaNextWeek.
  ///
  /// In en, this message translates to:
  /// **'Next Week'**
  String get agendaNextWeek;

  /// No description provided for @agendaLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get agendaLater;

  /// No description provided for @agendaMovie.
  ///
  /// In en, this message translates to:
  /// **'Movie'**
  String get agendaMovie;

  /// No description provided for @agendaSeries.
  ///
  /// In en, this message translates to:
  /// **'Series'**
  String get agendaSeries;

  /// No description provided for @agendaRecentlyReleased.
  ///
  /// In en, this message translates to:
  /// **'Recently Released'**
  String get agendaRecentlyReleased;

  /// No description provided for @agendaTbd.
  ///
  /// In en, this message translates to:
  /// **'TBD / Coming Soon'**
  String get agendaTbd;

  /// No description provided for @agendaTbdLabel.
  ///
  /// In en, this message translates to:
  /// **'TBD'**
  String get agendaTbdLabel;

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Update Available'**
  String get updateAvailable;

  /// No description provided for @updateDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'New version available'**
  String get updateDialogTitle;

  /// No description provided for @updateDialogMessage.
  ///
  /// In en, this message translates to:
  /// **'A new version of Cinemuse is available. Would you like to update now?'**
  String get updateDialogMessage;

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update Now'**
  String get updateNow;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @downloadingUpdate.
  ///
  /// In en, this message translates to:
  /// **'Downloading update {progress}%'**
  String downloadingUpdate(Object progress);

  /// No description provided for @updateReadyToInstall.
  ///
  /// In en, this message translates to:
  /// **'Update ready to install'**
  String get updateReadyToInstall;

  /// No description provided for @updateFailed.
  ///
  /// In en, this message translates to:
  /// **'Update failed. Please try again later.'**
  String get updateFailed;

  /// No description provided for @updateNoCompatibleApk.
  ///
  /// In en, this message translates to:
  /// **'No compatible update found for your device architecture ({abi})'**
  String updateNoCompatibleApk(Object abi);

  /// No description provided for @updateUpToDate.
  ///
  /// In en, this message translates to:
  /// **'App is up to date'**
  String get updateUpToDate;

  /// No description provided for @updateChangelog.
  ///
  /// In en, this message translates to:
  /// **'What\'s New'**
  String get updateChangelog;

  /// No description provided for @updateCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel Update'**
  String get updateCancel;

  /// No description provided for @updateNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Network error during update. Please check your connection.'**
  String get updateNetworkError;

  /// No description provided for @updateStorageError.
  ///
  /// In en, this message translates to:
  /// **'Not enough storage space to download the update.'**
  String get updateStorageError;

  /// No description provided for @updateSourceError.
  ///
  /// In en, this message translates to:
  /// **'The update source is currently unavailable.'**
  String get updateSourceError;

  /// No description provided for @updateIntegrityError.
  ///
  /// In en, this message translates to:
  /// **'The downloaded update could not be verified, so it was not installed.'**
  String get updateIntegrityError;

  /// No description provided for @updateFolderNotWritable.
  ///
  /// In en, this message translates to:
  /// **'Cinemuse can\'t update itself in this folder. Move the Cinemuse folder somewhere you own (for example Documents), or download the update from GitHub.'**
  String get updateFolderNotWritable;

  /// No description provided for @updateAlreadyRunning.
  ///
  /// In en, this message translates to:
  /// **'An update is already in progress.'**
  String get updateAlreadyRunning;

  /// No description provided for @updatePermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Cinemuse needs permission to install apps. Allow it in Settings, then try again.'**
  String get updatePermissionDenied;

  /// No description provided for @menuMoreOptions.
  ///
  /// In en, this message translates to:
  /// **'More Options'**
  String get menuMoreOptions;

  /// No description provided for @menuAddToWatchlist.
  ///
  /// In en, this message translates to:
  /// **'Add to Watchlist'**
  String get menuAddToWatchlist;

  /// No description provided for @menuRemoveFromWatchlist.
  ///
  /// In en, this message translates to:
  /// **'Remove from Watchlist'**
  String get menuRemoveFromWatchlist;

  /// No description provided for @menuRemoveFromList.
  ///
  /// In en, this message translates to:
  /// **'Remove from List'**
  String get menuRemoveFromList;

  /// No description provided for @menuMarkAsWatched.
  ///
  /// In en, this message translates to:
  /// **'Mark as Watched'**
  String get menuMarkAsWatched;

  /// No description provided for @menuMarkAsUnwatched.
  ///
  /// In en, this message translates to:
  /// **'Mark as Unwatched'**
  String get menuMarkAsUnwatched;

  /// No description provided for @menuShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get menuShare;

  /// No description provided for @menuResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get menuResume;

  /// No description provided for @menuRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get menuRestart;

  /// No description provided for @menuClearProgress.
  ///
  /// In en, this message translates to:
  /// **'Clear Progress'**
  String get menuClearProgress;

  /// No description provided for @menuMarkWatchedNow.
  ///
  /// In en, this message translates to:
  /// **'Mark as watched (now)'**
  String get menuMarkWatchedNow;

  /// No description provided for @menuMarkWatchedCustomDate.
  ///
  /// In en, this message translates to:
  /// **'Mark as watched (custom date)'**
  String get menuMarkWatchedCustomDate;

  /// No description provided for @menuPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get menuPlay;

  /// No description provided for @menuStopWatching.
  ///
  /// In en, this message translates to:
  /// **'Stop Watching'**
  String get menuStopWatching;

  /// No description provided for @menuCancelRewatch.
  ///
  /// In en, this message translates to:
  /// **'Cancel Rewatch'**
  String get menuCancelRewatch;

  /// No description provided for @menuRemoveFromContinueWatching.
  ///
  /// In en, this message translates to:
  /// **'Remove from Continue Watching'**
  String get menuRemoveFromContinueWatching;

  /// No description provided for @menuRemoveCachedProvider.
  ///
  /// In en, this message translates to:
  /// **'Remove Cached Stream'**
  String get menuRemoveCachedProvider;

  /// No description provided for @menuManageWatchHistory.
  ///
  /// In en, this message translates to:
  /// **'Manage Watch History'**
  String get menuManageWatchHistory;

  /// No description provided for @liveTvTabAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get liveTvTabAll;

  /// No description provided for @liveTvTabFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get liveTvTabFavorites;

  /// No description provided for @liveTvTabRecents.
  ///
  /// In en, this message translates to:
  /// **'Recents'**
  String get liveTvTabRecents;

  /// No description provided for @liveTvFilterChannels.
  ///
  /// In en, this message translates to:
  /// **'Filter Channels'**
  String get liveTvFilterChannels;

  /// No description provided for @liveTvGroupBy.
  ///
  /// In en, this message translates to:
  /// **'Group by'**
  String get liveTvGroupBy;

  /// No description provided for @liveTvSubProvider.
  ///
  /// In en, this message translates to:
  /// **'Sub-provider'**
  String get liveTvSubProvider;

  /// No description provided for @liveTvApplyFilters.
  ///
  /// In en, this message translates to:
  /// **'Apply Filters'**
  String get liveTvApplyFilters;

  /// No description provided for @liveTvClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear Filters'**
  String get liveTvClearFilters;

  /// No description provided for @liveTvAddedToFavorites.
  ///
  /// In en, this message translates to:
  /// **'Added to favorites'**
  String get liveTvAddedToFavorites;

  /// No description provided for @liveTvRemovedFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Removed from favorites'**
  String get liveTvRemovedFromFavorites;

  /// No description provided for @liveTvNoFavorites.
  ///
  /// In en, this message translates to:
  /// **'No favorite channels yet'**
  String get liveTvNoFavorites;

  /// No description provided for @liveTvNoFavoritesHint.
  ///
  /// In en, this message translates to:
  /// **'Long-press a channel to add it to favorites'**
  String get liveTvNoFavoritesHint;

  /// No description provided for @liveTvNoRecents.
  ///
  /// In en, this message translates to:
  /// **'No recently watched channels'**
  String get liveTvNoRecents;

  /// No description provided for @liveTvCustomPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Custom Playlists'**
  String get liveTvCustomPlaylists;

  /// No description provided for @liveTvCustomPlaylistsDesc.
  ///
  /// In en, this message translates to:
  /// **'Add M3U/JSON playlists from URLs or local files.'**
  String get liveTvCustomPlaylistsDesc;

  /// No description provided for @liveTvNoCustomPlaylists.
  ///
  /// In en, this message translates to:
  /// **'No custom playlists added yet'**
  String get liveTvNoCustomPlaylists;

  /// No description provided for @liveTvAddUrl.
  ///
  /// In en, this message translates to:
  /// **'Add URL'**
  String get liveTvAddUrl;

  /// No description provided for @liveTvAddFile.
  ///
  /// In en, this message translates to:
  /// **'Add File'**
  String get liveTvAddFile;

  /// No description provided for @liveTvAddRemotePlaylist.
  ///
  /// In en, this message translates to:
  /// **'Add Remote Playlist'**
  String get liveTvAddRemotePlaylist;

  /// No description provided for @liveTvPlaylistName.
  ///
  /// In en, this message translates to:
  /// **'Playlist Name'**
  String get liveTvPlaylistName;

  /// No description provided for @liveTvPlaylistUrl.
  ///
  /// In en, this message translates to:
  /// **'Playlist URL'**
  String get liveTvPlaylistUrl;

  /// No description provided for @liveTvPlaylistFormat.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get liveTvPlaylistFormat;

  /// No description provided for @liveTvOpenFileLocation.
  ///
  /// In en, this message translates to:
  /// **'Open File Location'**
  String get liveTvOpenFileLocation;

  /// No description provided for @liveTvOpenLink.
  ///
  /// In en, this message translates to:
  /// **'Open Link'**
  String get liveTvOpenLink;

  /// No description provided for @liveTvManagePlaylists.
  ///
  /// In en, this message translates to:
  /// **'Manage Playlists'**
  String get liveTvManagePlaylists;

  /// No description provided for @liveTvTypeM3uFile.
  ///
  /// In en, this message translates to:
  /// **'M3U File'**
  String get liveTvTypeM3uFile;

  /// No description provided for @liveTvTypeJsonFile.
  ///
  /// In en, this message translates to:
  /// **'JSON File'**
  String get liveTvTypeJsonFile;

  /// No description provided for @liveTvTypeM3uUrl.
  ///
  /// In en, this message translates to:
  /// **'M3U URL'**
  String get liveTvTypeM3uUrl;

  /// No description provided for @liveTvTypeJsonUrl.
  ///
  /// In en, this message translates to:
  /// **'JSON URL'**
  String get liveTvTypeJsonUrl;

  /// No description provided for @liveTvPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get liveTvPlaylists;

  /// No description provided for @liveTvFilterAndPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Filter & Playlists'**
  String get liveTvFilterAndPlaylists;

  /// No description provided for @liveTvEpgSection.
  ///
  /// In en, this message translates to:
  /// **'TV Guide (EPG)'**
  String get liveTvEpgSection;

  /// No description provided for @liveTvEpgSectionDesc.
  ///
  /// In en, this message translates to:
  /// **'Configure an electronic program guide source for channel schedules.'**
  String get liveTvEpgSectionDesc;

  /// No description provided for @liveTvEpgUrl.
  ///
  /// In en, this message translates to:
  /// **'EPG Guide URL'**
  String get liveTvEpgUrl;

  /// No description provided for @liveTvEpgCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get liveTvEpgCustom;

  /// No description provided for @liveTvEpgDefault.
  ///
  /// In en, this message translates to:
  /// **'Cinemuse Unified (Default)'**
  String get liveTvEpgDefault;

  /// No description provided for @liveTvConfigureEpg.
  ///
  /// In en, this message translates to:
  /// **'Configure EPG'**
  String get liveTvConfigureEpg;

  /// No description provided for @liveTvResetEpg.
  ///
  /// In en, this message translates to:
  /// **'Reset to Default'**
  String get liveTvResetEpg;

  /// No description provided for @liveTvRefreshEpg.
  ///
  /// In en, this message translates to:
  /// **'Refresh Guide'**
  String get liveTvRefreshEpg;

  /// No description provided for @liveTvEpgRefreshed.
  ///
  /// In en, this message translates to:
  /// **'EPG guide refreshed successfully'**
  String get liveTvEpgRefreshed;

  /// No description provided for @liveTvEpgDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Configure EPG Guide'**
  String get liveTvEpgDialogTitle;

  /// No description provided for @liveTvEpgDialogHint.
  ///
  /// In en, this message translates to:
  /// **'Enter an XMLTV or JSON EPG URL'**
  String get liveTvEpgDialogHint;

  /// No description provided for @tvTimeComments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get tvTimeComments;

  /// No description provided for @tvTimeNoComments.
  ///
  /// In en, this message translates to:
  /// **'No comments yet.'**
  String get tvTimeNoComments;

  /// No description provided for @tvTimeReplies.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} reply} other{{count} replies}}'**
  String tvTimeReplies(int count);

  /// No description provided for @tvTimeLoadingComments.
  ///
  /// In en, this message translates to:
  /// **'Loading comments...'**
  String get tvTimeLoadingComments;

  /// No description provided for @tvTimeCommentsError.
  ///
  /// In en, this message translates to:
  /// **'Could not load comments.'**
  String get tvTimeCommentsError;

  /// No description provided for @commentsSpoilerWarning.
  ///
  /// In en, this message translates to:
  /// **'Spoiler Warning'**
  String get commentsSpoilerWarning;

  /// No description provided for @commentsTapToReveal.
  ///
  /// In en, this message translates to:
  /// **'Tap to reveal'**
  String get commentsTapToReveal;

  /// No description provided for @commentsSortMostLiked.
  ///
  /// In en, this message translates to:
  /// **'Most Liked'**
  String get commentsSortMostLiked;

  /// No description provided for @commentsSortRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get commentsSortRecent;

  /// No description provided for @commentsSortRating.
  ///
  /// In en, this message translates to:
  /// **'Highest Rating'**
  String get commentsSortRating;

  /// No description provided for @commentsFilterAnyLanguage.
  ///
  /// In en, this message translates to:
  /// **'Any Language'**
  String get commentsFilterAnyLanguage;

  /// No description provided for @commentsFilterEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get commentsFilterEnglish;

  /// No description provided for @commentsFilterItalian.
  ///
  /// In en, this message translates to:
  /// **'Italian'**
  String get commentsFilterItalian;

  /// No description provided for @commentsFilterEnIt.
  ///
  /// In en, this message translates to:
  /// **'English + Italian'**
  String get commentsFilterEnIt;

  /// No description provided for @commentsFilterAllSources.
  ///
  /// In en, this message translates to:
  /// **'All Sources'**
  String get commentsFilterAllSources;

  /// No description provided for @commentsSourceSerializd.
  ///
  /// In en, this message translates to:
  /// **'Serializd'**
  String get commentsSourceSerializd;

  /// No description provided for @commentsSourceLetterboxd.
  ///
  /// In en, this message translates to:
  /// **'Letterboxd'**
  String get commentsSourceLetterboxd;

  /// No description provided for @commentsSourceImdb.
  ///
  /// In en, this message translates to:
  /// **'IMDb'**
  String get commentsSourceImdb;

  /// No description provided for @settingsSearchPreferences.
  ///
  /// In en, this message translates to:
  /// **'Search Preferences'**
  String get settingsSearchPreferences;

  /// No description provided for @settingsAutoSkipProviders.
  ///
  /// In en, this message translates to:
  /// **'Auto-Skip Slow Providers'**
  String get settingsAutoSkipProviders;

  /// No description provided for @settingsAutoSkipProvidersDesc.
  ///
  /// In en, this message translates to:
  /// **'Skip streaming providers that take longer than 30 seconds to respond.'**
  String get settingsAutoSkipProvidersDesc;

  /// No description provided for @profileRecentMovies.
  ///
  /// In en, this message translates to:
  /// **'Recent Movies'**
  String get profileRecentMovies;

  /// No description provided for @profileRecentSeries.
  ///
  /// In en, this message translates to:
  /// **'Recent Series'**
  String get profileRecentSeries;

  /// No description provided for @statsTimeBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Time Breakdown'**
  String get statsTimeBreakdown;

  /// No description provided for @statsAllTime.
  ///
  /// In en, this message translates to:
  /// **'All Time'**
  String get statsAllTime;

  /// No description provided for @statsMovies.
  ///
  /// In en, this message translates to:
  /// **'Movies'**
  String get statsMovies;

  /// No description provided for @statsSeries.
  ///
  /// In en, this message translates to:
  /// **'Series'**
  String get statsSeries;

  /// No description provided for @statsLast7Days.
  ///
  /// In en, this message translates to:
  /// **'Last 7 Days'**
  String get statsLast7Days;

  /// No description provided for @statsLast30Days.
  ///
  /// In en, this message translates to:
  /// **'Last 30 Days'**
  String get statsLast30Days;

  /// No description provided for @statsLastYear.
  ///
  /// In en, this message translates to:
  /// **'Last Year'**
  String get statsLastYear;

  /// No description provided for @statsMoviesStats.
  ///
  /// In en, this message translates to:
  /// **'Movies Stats'**
  String get statsMoviesStats;

  /// No description provided for @statsSeriesStats.
  ///
  /// In en, this message translates to:
  /// **'Series Stats'**
  String get statsSeriesStats;

  /// No description provided for @statsEpisodes.
  ///
  /// In en, this message translates to:
  /// **'Episodes'**
  String get statsEpisodes;

  /// No description provided for @statsSeasons.
  ///
  /// In en, this message translates to:
  /// **'Seasons'**
  String get statsSeasons;

  /// No description provided for @statsTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get statsTime;

  /// No description provided for @detailsCreatorsAndDirectors.
  ///
  /// In en, this message translates to:
  /// **'Creators & Directors'**
  String get detailsCreatorsAndDirectors;

  /// No description provided for @detailsDirector.
  ///
  /// In en, this message translates to:
  /// **'Director'**
  String get detailsDirector;

  /// No description provided for @detailsCreator.
  ///
  /// In en, this message translates to:
  /// **'Creator'**
  String get detailsCreator;

  /// No description provided for @detailsWriter.
  ///
  /// In en, this message translates to:
  /// **'Writer'**
  String get detailsWriter;

  /// No description provided for @detailsWriters.
  ///
  /// In en, this message translates to:
  /// **'Writers'**
  String get detailsWriters;

  /// No description provided for @detailsPeople.
  ///
  /// In en, this message translates to:
  /// **'Cast & Crew'**
  String get detailsPeople;

  /// No description provided for @detailsSectionCrew.
  ///
  /// In en, this message translates to:
  /// **'CREW'**
  String get detailsSectionCrew;

  /// No description provided for @detailsSectionCast.
  ///
  /// In en, this message translates to:
  /// **'CAST'**
  String get detailsSectionCast;

  /// No description provided for @detailsTvTimeComments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get detailsTvTimeComments;

  /// No description provided for @detailsTrack.
  ///
  /// In en, this message translates to:
  /// **'Track'**
  String get detailsTrack;

  /// No description provided for @detailsWatched.
  ///
  /// In en, this message translates to:
  /// **'Watched'**
  String get detailsWatched;

  /// No description provided for @detailsWatchedCount.
  ///
  /// In en, this message translates to:
  /// **'Watched x{count}'**
  String detailsWatchedCount(int count);

  /// No description provided for @detailsUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Up to date'**
  String get detailsUpToDate;

  /// No description provided for @detailsUpToDateCount.
  ///
  /// In en, this message translates to:
  /// **'Up to date x{count}'**
  String detailsUpToDateCount(int count);

  /// No description provided for @detailsFinishSeries.
  ///
  /// In en, this message translates to:
  /// **'Finish Series'**
  String get detailsFinishSeries;

  /// No description provided for @commonNoContent.
  ///
  /// In en, this message translates to:
  /// **'No content available'**
  String get commonNoContent;

  /// No description provided for @commonStopCasting.
  ///
  /// In en, this message translates to:
  /// **'STOP CASTING'**
  String get commonStopCasting;

  /// No description provided for @castConnectDevice.
  ///
  /// In en, this message translates to:
  /// **'Connect to device'**
  String get castConnectDevice;

  /// No description provided for @castNoDevices.
  ///
  /// In en, this message translates to:
  /// **'No devices found'**
  String get castNoDevices;

  /// No description provided for @castRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get castRefresh;

  /// No description provided for @profileNoRecentItems.
  ///
  /// In en, this message translates to:
  /// **'No recently watched items'**
  String get profileNoRecentItems;

  /// No description provided for @detailsEditList.
  ///
  /// In en, this message translates to:
  /// **'Edit List'**
  String get detailsEditList;

  /// No description provided for @detailsDeleteList.
  ///
  /// In en, this message translates to:
  /// **'Delete List'**
  String get detailsDeleteList;

  /// No description provided for @detailsTvTimeCommentsNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Comments not available for this media'**
  String get detailsTvTimeCommentsNotAvailable;

  /// No description provided for @detailsTvTimeCommentsNotAvailableSeries.
  ///
  /// In en, this message translates to:
  /// **'Comments not available for this series'**
  String get detailsTvTimeCommentsNotAvailableSeries;

  /// No description provided for @detailsFailedLoadCollection.
  ///
  /// In en, this message translates to:
  /// **'Failed to load collection details'**
  String get detailsFailedLoadCollection;

  /// No description provided for @detailsFeaturedCritic.
  ///
  /// In en, this message translates to:
  /// **'Featured Critic'**
  String get detailsFeaturedCritic;

  /// No description provided for @offlineBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Offline Mode'**
  String get offlineBannerTitle;

  /// No description provided for @offlineBannerMessage.
  ///
  /// In en, this message translates to:
  /// **'Showing locally cached content only.'**
  String get offlineBannerMessage;

  /// No description provided for @castSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching for devices...'**
  String get castSearching;

  /// No description provided for @castError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String castError(String error);

  /// No description provided for @castCastingTo.
  ///
  /// In en, this message translates to:
  /// **'Casting to {deviceName}'**
  String castCastingTo(String deviceName);

  /// No description provided for @castSeasonEpisode.
  ///
  /// In en, this message translates to:
  /// **'Season {season} • Episode {episode}'**
  String castSeasonEpisode(int season, int episode);

  /// No description provided for @statsDaysHours.
  ///
  /// In en, this message translates to:
  /// **'{days}d {hours}h'**
  String statsDaysHours(int days, int hours);

  /// No description provided for @listWatchLater.
  ///
  /// In en, this message translates to:
  /// **'Watch Later'**
  String get listWatchLater;

  /// No description provided for @listFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get listFavorites;

  /// No description provided for @listYourQueue.
  ///
  /// In en, this message translates to:
  /// **'Your queue'**
  String get listYourQueue;

  /// No description provided for @listCuratedPicks.
  ///
  /// In en, this message translates to:
  /// **'Your curated picks'**
  String get listCuratedPicks;

  /// No description provided for @listDropped.
  ///
  /// In en, this message translates to:
  /// **'Dropped'**
  String get listDropped;

  /// No description provided for @listDroppedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Titles you interrupted.'**
  String get listDroppedSubtitle;

  /// No description provided for @menuRestoreContinueWatching.
  ///
  /// In en, this message translates to:
  /// **'Restore to Continue Watching'**
  String get menuRestoreContinueWatching;

  /// No description provided for @listUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled List'**
  String get listUntitled;

  /// No description provided for @listNameHint.
  ///
  /// In en, this message translates to:
  /// **'List Name'**
  String get listNameHint;

  /// No description provided for @listDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Add a description...'**
  String get listDescriptionHint;

  /// No description provided for @listItemsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} item} other{{count} items}}'**
  String listItemsCount(int count);

  /// No description provided for @listEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'This list is empty'**
  String get listEmptyTitle;

  /// No description provided for @listEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Add media from the details page'**
  String get listEmptyMessage;

  /// No description provided for @collectionTitleFallback.
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get collectionTitleFallback;

  /// No description provided for @collectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Movie Collection'**
  String get collectionSubtitle;

  /// No description provided for @listPinToHome.
  ///
  /// In en, this message translates to:
  /// **'Pin to Home'**
  String get listPinToHome;

  /// No description provided for @listUnpinFromHome.
  ///
  /// In en, this message translates to:
  /// **'Unpin from Home'**
  String get listUnpinFromHome;

  /// No description provided for @listPinnedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Pinned to Home'**
  String get listPinnedSuccess;

  /// No description provided for @listUnpinnedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Unpinned from Home'**
  String get listUnpinnedSuccess;

  /// No description provided for @playerLiveSources.
  ///
  /// In en, this message translates to:
  /// **'Available Streams'**
  String get playerLiveSources;

  /// No description provided for @playerPreferredQuality.
  ///
  /// In en, this message translates to:
  /// **'Preferred Quality (Default)'**
  String get playerPreferredQuality;

  /// No description provided for @playerActiveSource.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get playerActiveSource;

  /// No description provided for @playerSourceFailed.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get playerSourceFailed;

  /// No description provided for @watchHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Watch History'**
  String get watchHistoryTitle;

  /// No description provided for @watchHistorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 title} other{{count} titles}}'**
  String watchHistorySubtitle(int count);

  /// No description provided for @watchHistoryFilteredCount.
  ///
  /// In en, this message translates to:
  /// **'{filtered} of {total, plural, =1{1 title} other{{total} titles}}'**
  String watchHistoryFilteredCount(int filtered, int total);

  /// No description provided for @watchHistoryBreakdown.
  ///
  /// In en, this message translates to:
  /// **'{movies, plural, =1{1 movie} other{{movies} movies}}, {series, plural, =1{1 series} other{{series} series}}'**
  String watchHistoryBreakdown(int movies, int series);

  /// No description provided for @watchHistoryMoviesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 movie} other{{count} movies}}'**
  String watchHistoryMoviesCount(int count);

  /// No description provided for @watchHistoryFilteredMoviesCount.
  ///
  /// In en, this message translates to:
  /// **'{filtered} of {total, plural, =1{1 movie} other{{total} movies}}'**
  String watchHistoryFilteredMoviesCount(int filtered, int total);

  /// No description provided for @watchHistorySeriesBreakdown.
  ///
  /// In en, this message translates to:
  /// **'{series, plural, =1{1 series} other{{series} series}}, {seasons, plural, =1{1 season} other{{seasons} seasons}}, {episodes, plural, =1{1 episode} other{{episodes} episodes}}'**
  String watchHistorySeriesBreakdown(int series, int seasons, int episodes);

  /// No description provided for @watchHistoryFilteredSeriesBreakdown.
  ///
  /// In en, this message translates to:
  /// **'{filteredSeries} of {totalSeries, plural, =1{1 series} other{{totalSeries} series}}, {seasons, plural, =1{1 season} other{{seasons} seasons}}, {episodes, plural, =1{1 episode} other{{episodes} episodes}}'**
  String watchHistoryFilteredSeriesBreakdown(
    int filteredSeries,
    int totalSeries,
    int seasons,
    int episodes,
  );

  /// No description provided for @watchHistorySearchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search watched titles...'**
  String get watchHistorySearchPlaceholder;

  /// No description provided for @watchHistoryAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get watchHistoryAll;

  /// No description provided for @watchHistoryStatusAll.
  ///
  /// In en, this message translates to:
  /// **'All Statuses'**
  String get watchHistoryStatusAll;

  /// No description provided for @watchHistoryStatusWatching.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get watchHistoryStatusWatching;

  /// No description provided for @watchHistoryStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get watchHistoryStatusCompleted;

  /// No description provided for @watchHistoryStatusDropped.
  ///
  /// In en, this message translates to:
  /// **'Dropped'**
  String get watchHistoryStatusDropped;

  /// No description provided for @watchHistorySortRecent.
  ///
  /// In en, this message translates to:
  /// **'Recently Watched'**
  String get watchHistorySortRecent;

  /// No description provided for @watchHistorySortTitle.
  ///
  /// In en, this message translates to:
  /// **'Title (A-Z)'**
  String get watchHistorySortTitle;

  /// No description provided for @watchHistoryViewGrid.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get watchHistoryViewGrid;

  /// No description provided for @watchHistoryViewTimeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get watchHistoryViewTimeline;

  /// No description provided for @watchHistoryDateToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get watchHistoryDateToday;

  /// No description provided for @watchHistoryDateYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get watchHistoryDateYesterday;

  /// No description provided for @watchHistoryDateThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get watchHistoryDateThisWeek;

  /// No description provided for @watchHistoryDateThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get watchHistoryDateThisMonth;

  /// No description provided for @watchHistoryResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get watchHistoryResume;

  /// No description provided for @watchHistoryWatchAgain.
  ///
  /// In en, this message translates to:
  /// **'Watch Again'**
  String get watchHistoryWatchAgain;

  /// No description provided for @watchHistoryReplay.
  ///
  /// In en, this message translates to:
  /// **'Replay'**
  String get watchHistoryReplay;

  /// No description provided for @watchHistorySeasonEpisode.
  ///
  /// In en, this message translates to:
  /// **'Season {season} • Episode {episode}'**
  String watchHistorySeasonEpisode(int season, int episode);

  /// No description provided for @watchHistoryHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours, plural, =1{1 hour ago} other{{hours} hours ago}}'**
  String watchHistoryHoursAgo(int hours);

  /// No description provided for @watchHistoryMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1{1 minute ago} other{{minutes} minutes ago}}'**
  String watchHistoryMinutesAgo(int minutes);

  /// No description provided for @watchHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No watch history found'**
  String get watchHistoryEmpty;

  /// No description provided for @watchHistoryGranularityDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get watchHistoryGranularityDaily;

  /// No description provided for @watchHistoryGranularityMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get watchHistoryGranularityMonthly;

  /// No description provided for @watchHistoryGranularityYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get watchHistoryGranularityYearly;

  /// No description provided for @watchHistoryStackedEpisodes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 episode} other{{count} episodes}}'**
  String watchHistoryStackedEpisodes(int count);

  /// No description provided for @watchHistoryEpisodeRange.
  ///
  /// In en, this message translates to:
  /// **'S{season} E{start}–E{end}'**
  String watchHistoryEpisodeRange(int season, int start, int end);

  /// No description provided for @watchHistoryMultiSeasonRange.
  ///
  /// In en, this message translates to:
  /// **'S{startSeason} E{startEpisode}–S{endSeason} E{endEpisode}'**
  String watchHistoryMultiSeasonRange(
    int startSeason,
    int startEpisode,
    int endSeason,
    int endEpisode,
  );

  /// No description provided for @watchHistorySeasonRange.
  ///
  /// In en, this message translates to:
  /// **'S{startSeason}–S{endSeason}'**
  String watchHistorySeasonRange(int startSeason, int endSeason);

  /// No description provided for @watchHistoryFiltersTitle.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get watchHistoryFiltersTitle;

  /// No description provided for @watchHistoryResetFilters.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get watchHistoryResetFilters;

  /// No description provided for @watchHistoryApplyFilters.
  ///
  /// In en, this message translates to:
  /// **'Apply Filters'**
  String get watchHistoryApplyFilters;

  /// No description provided for @watchHistoryFilterType.
  ///
  /// In en, this message translates to:
  /// **'Media Type'**
  String get watchHistoryFilterType;

  /// No description provided for @watchHistoryFilterStatus.
  ///
  /// In en, this message translates to:
  /// **'Watch Status'**
  String get watchHistoryFilterStatus;

  /// No description provided for @watchHistoryFilterSort.
  ///
  /// In en, this message translates to:
  /// **'Sort By'**
  String get watchHistoryFilterSort;

  /// No description provided for @watchHistoryFilterGranularity.
  ///
  /// In en, this message translates to:
  /// **'Timeline Grouping'**
  String get watchHistoryFilterGranularity;

  /// No description provided for @watchHistoryActiveFilterCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 filter} other{{count} filters}}'**
  String watchHistoryActiveFilterCount(int count);

  /// No description provided for @liveTvFullWindow.
  ///
  /// In en, this message translates to:
  /// **'Full Window'**
  String get liveTvFullWindow;

  /// No description provided for @liveTvSplitView.
  ///
  /// In en, this message translates to:
  /// **'Split View'**
  String get liveTvSplitView;

  /// No description provided for @liveTvChannels.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get liveTvChannels;

  /// No description provided for @liveTvCloseOverlay.
  ///
  /// In en, this message translates to:
  /// **'Close channel list'**
  String get liveTvCloseOverlay;

  /// No description provided for @liveTvGoToLive.
  ///
  /// In en, this message translates to:
  /// **'Go to Live'**
  String get liveTvGoToLive;

  /// No description provided for @playerFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Fullscreen'**
  String get playerFullscreen;

  /// No description provided for @playerExitFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Exit fullscreen'**
  String get playerExitFullscreen;

  /// No description provided for @seriesStatusOngoing.
  ///
  /// In en, this message translates to:
  /// **'Ongoing'**
  String get seriesStatusOngoing;

  /// No description provided for @menuViewWatchHistory.
  ///
  /// In en, this message translates to:
  /// **'View Watch History'**
  String get menuViewWatchHistory;

  /// No description provided for @liveTvWatchChannel.
  ///
  /// In en, this message translates to:
  /// **'Watch Channel'**
  String get liveTvWatchChannel;

  /// No description provided for @liveTvJumpToNow.
  ///
  /// In en, this message translates to:
  /// **'Jump to Live'**
  String get liveTvJumpToNow;

  /// No description provided for @liveTvTvGuide.
  ///
  /// In en, this message translates to:
  /// **'TV Guide'**
  String get liveTvTvGuide;

  /// No description provided for @liveTvNoProgramDetails.
  ///
  /// In en, this message translates to:
  /// **'No synopsis available for this program.'**
  String get liveTvNoProgramDetails;

  /// No description provided for @liveTvMinutesRemaining.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m remaining'**
  String liveTvMinutesRemaining(int minutes);

  /// No description provided for @playerCached.
  ///
  /// In en, this message translates to:
  /// **'CACHED'**
  String get playerCached;

  /// No description provided for @castDefaultDevice.
  ///
  /// In en, this message translates to:
  /// **'Chromecast'**
  String get castDefaultDevice;

  /// Error prefix message
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String playerErrorPrefix(String error);
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
