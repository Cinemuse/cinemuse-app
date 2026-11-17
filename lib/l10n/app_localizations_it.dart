// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get navHome => 'Home';

  @override
  String get navSearch => 'Cerca';

  @override
  String get navExplore => 'Esplora';

  @override
  String get navSettings => 'Impostazioni';

  @override
  String get navLibrary => 'Libreria';

  @override
  String get commonLoading => 'Caricamento...';

  @override
  String get commonError => 'Errore';

  @override
  String get commonRetry => 'Riprova';

  @override
  String get commonCancel => 'Annulla';

  @override
  String get commonClose => 'Chiudi';

  @override
  String get commonConfirm => 'Conferma';

  @override
  String get commonCreate => 'Crea';

  @override
  String get commonDelete => 'Elimina';

  @override
  String get commonClearAll => 'Cancella tutto';

  @override
  String get commonUndo => 'Annulla';

  @override
  String get commonFeatured => 'IN PRIMO PIANO';

  @override
  String get commonUnexpectedError => 'Si è verificato un errore inaspettato';

  @override
  String get commonOk => 'OK';

  @override
  String get commonUnknown => 'Sconosciuto';

  @override
  String get commonAnonymous => 'Anonimo';

  @override
  String get commonScrollLeft => 'Scorri a sinistra';

  @override
  String get commonScrollRight => 'Scorri a destra';

  @override
  String get carouselSeeAll => 'Vedi tutti';

  @override
  String get commonShowPassword => 'Mostra password';

  @override
  String get commonHidePassword => 'Nascondi password';

  @override
  String get commonClearSearch => 'Cancella ricerca';

  @override
  String get commonRemoveFilter => 'Rimuovi filtro';

  @override
  String get commonShow => 'Mostra';

  @override
  String get windowMinimize => 'Riduci a icona';

  @override
  String get windowMaximize => 'Ingrandisci';

  @override
  String get windowRestore => 'Ripristina';

  @override
  String get liveTvAddToFavorites => 'Aggiungi ai preferiti';

  @override
  String get liveTvRemoveFromFavorites => 'Rimuovi dai preferiti';

  @override
  String get filterMax => 'Max';

  @override
  String get offlineScreenTitle => 'Connessione Richiesta';

  @override
  String get offlineScreenMessage =>
      'Questa funzione richiede una connessione internet per sfogliare i contenuti e avviare lo streaming.';

  @override
  String get searchPlaceholder => 'Cerca film, serie, persone...';

  @override
  String get searchRecentSearches => 'Ricerche Recenti';

  @override
  String get searchHoldToDelete => 'Tieni premuto per eliminare';

  @override
  String searchNoResults(Object query) {
    return 'Nessun risultato trovato per \"$query\"';
  }

  @override
  String get searchEmptyStateTitle => 'Trova la tua prossima storia preferita';

  @override
  String searchItemYear(Object year) {
    return '$year';
  }

  @override
  String get searchMovies => 'Film';

  @override
  String get searchSeries => 'Serie TV';

  @override
  String get searchPersons => 'Persone';

  @override
  String get searchAdvancedFilters => 'Filtri Avanzati';

  @override
  String get searchFilterAction => 'Filtri';

  @override
  String get searchFilteredResults => 'Risultati';

  @override
  String get searchSortBy => 'Ordina per';

  @override
  String get searchMostPopular => 'Più Popolari';

  @override
  String get searchHighestRated => 'Più Votati';

  @override
  String get searchNewestReleases => 'Ultime Uscite';

  @override
  String get searchLanguages => 'Lingue';

  @override
  String get searchGenres => 'Generi';

  @override
  String get searchRating => 'Valutazione';

  @override
  String get searchYearRange => 'Anno';

  @override
  String get searchVoteCount => 'Numero di voti';

  @override
  String get searchRuntime => 'Durata';

  @override
  String get searchWatchProviders => 'Piattaforme';

  @override
  String get searchClearAll => 'Cancella Tutto';

  @override
  String get searchNoResultsTitle => 'Nessun risultato trovato';

  @override
  String get searchTryAdjusting => 'Prova a modificare i filtri';

  @override
  String get searchMatchAny => 'Qualsiasi';

  @override
  String get searchMatchAll => 'Tutte';

  @override
  String get searchLanguagePlaceholder => 'Aggiungi una lingua...';

  @override
  String get searchNoLanguagesFound => 'Nessuna lingua trovata';

  @override
  String get searchFilteredByPerson => 'Filtrato per persona';

  @override
  String get searchFilteredByStudio => 'Filtrato per studio';

  @override
  String detailsErrorLoadingSeason(Object error) {
    return 'Errore caricamento stagione: $error';
  }

  @override
  String get detailsSeasonNotFound => 'Dettagli stagione non trovati';

  @override
  String detailsListDeleted(Object name) {
    return 'Lista \'$name\' eliminata.';
  }

  @override
  String listTitleRemoved(Object title) {
    return '$title rimosso';
  }

  @override
  String watchHistoryRemoved(Object title) {
    return '$title: cronologia rimossa';
  }

  @override
  String oneWatchRemoved(Object title) {
    return '$title: una visione rimossa';
  }

  @override
  String progressCleared(Object title) {
    return '$title: avanzamento azzerato';
  }

  @override
  String rewatchCancelled(Object title) {
    return '$title: rewatch annullato';
  }

  @override
  String get detailsCollectionsTitle => 'Collezioni';

  @override
  String get detailsCollectionsDesc => 'Le tue liste personalizzate a tema.';

  @override
  String get detailsCollection => 'Collezione';

  @override
  String get detailsMoreLikeThis => 'Altri simili';

  @override
  String get detailsNewCollection => 'Nuova Collezione';

  @override
  String get detailsNoCollections =>
      'Nessuna Collezione presente. Creane una per iniziare a organizzare!';

  @override
  String get detailsAddToList => 'Aggiungi alla Lista';

  @override
  String get detailsNoCustomLists => 'Nessuna lista personalizzata';

  @override
  String get detailsCreateNewList => 'Crea Nuova Lista';

  @override
  String get detailsMarkPreviousTitle => 'Segna precedenti?';

  @override
  String detailsMarkPreviousDesc(Object count) {
    return 'Vuoi segnare anche i $count episodi precedenti non visti come visti?';
  }

  @override
  String get detailsOnlyThisOne => 'Solo questo';

  @override
  String get detailsCollectionNameHint =>
      'Nome Collezione (es., \'Gemme Sci-Fi\')';

  @override
  String get homeErrorLoadingFeatures => 'Errore caricamento contenuti';

  @override
  String get homeMoreInfo => 'Più Info';

  @override
  String get homeHeroPauseCarousel => 'Metti in pausa carosello';

  @override
  String get homeHeroResumeCarousel => 'Riprendi carosello';

  @override
  String get homeTrendingNow => 'Di tendenza';

  @override
  String get homeMoviesInTheaters => 'Film in sala';

  @override
  String get homeNewMoviesOnStreaming => 'Nuovi film in streaming';

  @override
  String get homeNewSeries => 'Nuove serie TV';

  @override
  String get homeTopRatedRecentSeries => 'Serie TV recenti più votate';

  @override
  String homeMoviesLike(String title) {
    return 'Film simili a $title';
  }

  @override
  String homeSeriesLike(String title) {
    return 'Serie TV simili a $title';
  }

  @override
  String get homeContinueWatching => 'Continua a guardare';

  @override
  String homeTimeLeftMinutes(int minutes) {
    return '$minutes min rimanenti';
  }

  @override
  String homeTimeLeftHours(int hours) {
    return '$hours h rimanenti';
  }

  @override
  String homeTimeLeftHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min rimanenti';
  }

  @override
  String get homeSportSchedule => 'Sport in programma';

  @override
  String get sportFootball => 'Calcio';

  @override
  String get sportBasketball => 'Pallacanestro';

  @override
  String get sportMotorcycling => 'Motociclismo';

  @override
  String get sportVolleyball => 'Pallavolo';

  @override
  String get sportAthletics => 'Atletica';

  @override
  String get sportTennis => 'Tennis';

  @override
  String get sportCycling => 'Ciclismo';

  @override
  String get sportRugby => 'Rugby';

  @override
  String get sportF1 => 'Formula 1';

  @override
  String get sportGeneric => 'Evento Sportivo';

  @override
  String sportWatchOnChannel(String channel) {
    return 'Guarda su $channel';
  }

  @override
  String get sportChannelsTitle => 'Canali';

  @override
  String homeRemovedFromContinueWatching(Object title) {
    return '$title rimosso';
  }

  @override
  String get authWelcomeBack => 'Bentornato';

  @override
  String get authEnterCredentials =>
      'Inserisci le tue credenziali per accedere';

  @override
  String get authWelcomeBackDesc =>
      'Accedi per visualizzare la tua libreria e le impostazioni';

  @override
  String get authEmail => 'EMAIL';

  @override
  String get authPassword => 'PASSWORD';

  @override
  String get authInvalidEmail => 'Inserisci un\'email valida';

  @override
  String get authPasswordTooShort =>
      'La password deve avere almeno 6 caratteri';

  @override
  String get authSignIn => 'Accedi';

  @override
  String settingsErrorSaving(Object error) {
    return 'Errore salvataggio: $error';
  }

  @override
  String get detailsEpisodes => 'Episodi';

  @override
  String get detailsCast => 'Cast';

  @override
  String get detailsPlay => 'Riproduci';

  @override
  String get detailsMyList => 'La Mia Lista';

  @override
  String detailsErrorLoading(Object error) {
    return 'Errore caricamento dettagli: $error';
  }

  @override
  String get detailsDecryptingMetadata => 'Decrittazione metadati...';

  @override
  String get detailsEpisodesRegistry => 'Registro Episodi';

  @override
  String detailsEpisodeFallback(int number) {
    return 'Episodio $number';
  }

  @override
  String detailsEpisodeWithSeason(int season, int episode, String name) {
    return 'S$season E$episode • $name';
  }

  @override
  String get detailsMarkSeasonWatched => 'Segna stagione come vista';

  @override
  String get detailsSeasonLabel => 'Stagione';

  @override
  String detailsSeasonsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Stagioni',
      one: '1 Stagione',
    );
    return '$_temp0';
  }

  @override
  String detailsEpisodesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Episodi',
      one: '1 Episodio',
    );
    return '$_temp0';
  }

  @override
  String detailsEpisodeRuntime(int minutes) {
    return '${minutes}m/ep';
  }

  @override
  String detailsPlaySeasonEpisode(int season, int episode) {
    return 'Riproduci S$season E$episode';
  }

  @override
  String detailsSeasonNumber(int num) {
    String _temp0 = intl.Intl.pluralLogic(
      num,
      locale: localeName,
      other: 'Stagione $num',
      zero: 'Speciali',
    );
    return '$_temp0';
  }

  @override
  String get detailsSynopsis => 'Sinossi';

  @override
  String detailsResumeEpisode(int season, int episode) {
    return 'Riprendi S$season E$episode';
  }

  @override
  String get detailsResume => 'Riprendi';

  @override
  String get detailsPlayNow => 'Riproduci Ora';

  @override
  String get detailsSeriesProgress => 'Progresso Serie';

  @override
  String get detailsCreativeVision => 'Visione Creativa';

  @override
  String get detailsVerdict => 'Verdetto';

  @override
  String get detailsVerdictExcellent => 'Sublime';

  @override
  String get detailsVerdictGood => 'Consigliato';

  @override
  String get detailsVerdictAverage => 'Guardabile';

  @override
  String get detailsVerdictPoor => 'Dimenticabile';

  @override
  String get detailsReviews => 'Recensioni';

  @override
  String get detailsReviewsAll => 'Leggi tutte le recensioni';

  @override
  String get detailsNoReviews => 'Nessuna recensione trovata.';

  @override
  String get detailsFinances => 'Finanze';

  @override
  String get detailsProductionDNA => 'DNA Produzione';

  @override
  String get detailsRate => 'VOTA';

  @override
  String get detailsMarkRemaining => 'Segna Rimanenti';

  @override
  String get detailsMarkAll => 'Segna Tutto';

  @override
  String get detailsRewatchSeries => 'Riguarda Serie';

  @override
  String get detailsRemoveAll => 'Cancella cronologia visualizzazioni';

  @override
  String get detailsSelectDate => 'Seleziona data';

  @override
  String get detailsMarkEntireSeriesPrompt =>
      'Segnare l\'intera serie come vista?';

  @override
  String get detailsManageHistorySeriesPrompt =>
      'Gestisci la cronologia per questa serie.';

  @override
  String get detailsClearAllSeriesLogsSubtitle =>
      'Cancella tutti i registri per tutte le stagioni';

  @override
  String get detailsTrackEpisodeProgress =>
      'Tieni traccia dei tuoi progressi per questo episodio.';

  @override
  String get detailsMarkRewatch => 'Segna come rivisto';

  @override
  String get detailsMarkAsWatched => 'Segna come visto';

  @override
  String get detailsSeeAllDatesWatched =>
      'Visualizza tutte le date in cui l\'hai visto';

  @override
  String get detailsRemoveOneWatch => 'Rimuovi una visione';

  @override
  String get detailsDeleteLatestEntry => 'Elimina l\'ultima voce';

  @override
  String get detailsClearAllEpisodeLogs =>
      'Cancella tutti i registri per questo episodio';

  @override
  String get detailsTrackMovieProgress =>
      'Tieni traccia dei tuoi progressi per questo film.';

  @override
  String get detailsClearAllMovieLogs =>
      'Cancella tutti i registri per questo film';

  @override
  String detailsWatchedOnDate(String date) {
    return 'Visto il $date';
  }

  @override
  String get detailsWatchHistoryLogs => 'Registri cronologia visualizzazioni';

  @override
  String get detailsErrorLoadingHistory =>
      'Errore durante il caricamento della cronologia';

  @override
  String get detailsBudget => 'Budget';

  @override
  String get detailsRevenue => 'Incassi';

  @override
  String get detailsOfficialWebsite => 'Sito Ufficiale';

  @override
  String get detailsMedia => 'Media';

  @override
  String get detailsLinks => 'Link';

  @override
  String get detailsLinkOpenFailed => 'Impossibile aprire il link.';

  @override
  String get detailsMore => 'Altro';

  @override
  String seasonLabel(Object number) {
    return 'Stagione $number';
  }

  @override
  String detailsEpisodeNumber(Object num) {
    return 'EP $num';
  }

  @override
  String get detailsReadMore => 'Leggi di più';

  @override
  String get detailsShowLess => 'Mostra meno';

  @override
  String get detailsTooltipWatched => 'Visto';

  @override
  String get detailsTooltipMarkWatched =>
      'Segna come Visto (Pressione prolungata per la data)';

  @override
  String get detailsGallery => 'Galleria';

  @override
  String get detailsGallerySubtitle => 'Sfondi, poster e loghi';

  @override
  String detailsBackdropsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Sfondi',
      one: '1 Sfondo',
    );
    return '$_temp0';
  }

  @override
  String detailsPostersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Poster',
      one: '1 Poster',
    );
    return '$_temp0';
  }

  @override
  String detailsLogosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Loghi',
      one: '1 Logo',
    );
    return '$_temp0';
  }

  @override
  String get detailsNoImages => 'Nessuna immagine disponibile';

  @override
  String get detailsBackdrops => 'Sfondi';

  @override
  String get detailsPosters => 'Poster';

  @override
  String get detailsLogos => 'Loghi';

  @override
  String get detailsGalleryPrevious => 'Immagine precedente';

  @override
  String get detailsGalleryNext => 'Immagine successiva';

  @override
  String get detailsGalleryDownload => 'Scarica immagine';

  @override
  String get detailsGalleryDownloadSuccess => 'Immagine salvata con successo';

  @override
  String get personBiography => 'Biografia';

  @override
  String get personKnownFor => 'Conosciuto per';

  @override
  String get personFilmography => 'Filmografia';

  @override
  String get personSeen => 'Visto';

  @override
  String get personYearsOld => 'anni';

  @override
  String get personNoImage => 'Nessuna immagine disponibile';

  @override
  String get personShowMore => 'Mostra Altro';

  @override
  String get personShowLess => 'Mostra Meno';

  @override
  String get personShowHidden => 'Mostra Nascosti';

  @override
  String personShowingCredits(Object total, Object visible) {
    return 'Visualizzati $visible di $total crediti';
  }

  @override
  String get personNoImg => 'Nessuna img';

  @override
  String get personSeries => 'Serie';

  @override
  String get personMovie => 'Film';

  @override
  String get playerTracks => 'Audio e sottotitoli';

  @override
  String get playerQuality => 'Sorgente';

  @override
  String get playerAudio => 'Audio';

  @override
  String get playerSelectQuality => 'Seleziona Sorgente';

  @override
  String get playerSubtitleSize => 'Dimensione Sottotitoli';

  @override
  String get playerSubtitleDelay => 'Sincronizzazione';

  @override
  String get playerSubtitleDelayReset => 'Ripristina';

  @override
  String get playerTrackOff => 'Disattiva';

  @override
  String get playerTrackNoAudio => 'Nessun audio / Muto';

  @override
  String get playerInternalTracks => 'TRACCE INTERNE';

  @override
  String get playerAudioTracks => 'TRACCE AUDIO';

  @override
  String get playerExternalTracks => 'TRACCE ESTERNE';

  @override
  String get playerNoExternalSubtitles => 'Nessun sottotitolo esterno trovato.';

  @override
  String get playerFailedLoadSubtitle =>
      'Impossibile caricare il sottotitolo esterno.';

  @override
  String get playerTrackSwitchFailed => 'Impossibile passare a questa traccia.';

  @override
  String playerSubtitlesCount(int count) {
    return '$count sottotitoli';
  }

  @override
  String get playerResolving => 'Risoluzione stream in corso...';

  @override
  String get playerSkipResolution => 'Salta';

  @override
  String get playerTryingNextSource =>
      'Stream non disponibile, provo la prossima sorgente...';

  @override
  String playerSoundLanguageMissingTryingNext(String language) {
    return 'Questa sorgente non ha l\'audio in $language: provo la prossima';
  }

  @override
  String playerNoSourceWithSoundLanguage(String language) {
    return 'Nessuna sorgente con l\'audio in $language';
  }

  @override
  String playerSourceWithoutSoundLanguage(String language) {
    return 'Questa sorgente non ha l\'audio in $language';
  }

  @override
  String playerProgressNotSaved(String reason) {
    return 'Avanzamento non salvato. $reason';
  }

  @override
  String playerEpisodeNotMarkedWatched(String reason) {
    return 'Episodio non segnato come visto. $reason';
  }

  @override
  String get playerAllSourcesExhausted =>
      'Tutte le sorgenti hanno fallito. Torna indietro e riprova.';

  @override
  String get playerResolvingYoutube => 'Caricamento video YouTube...';

  @override
  String playerErrorResolving(Object error) {
    return 'Errore risoluzione stream:\n$error';
  }

  @override
  String get playerYoutubeBlocked =>
      'Questo trailer non si può riprodurre nell\'app.\nA volte YouTube blocca le app come questa. Puoi guardarlo su YouTube.';

  @override
  String get playerOpenOnYoutube => 'Apri su YouTube';

  @override
  String get playerOpenOnYoutubeFailed =>
      'Impossibile aprire YouTube su questo dispositivo.';

  @override
  String get playerNoAudioFound => 'Nessuna traccia audio trovata';

  @override
  String get playerNoQualityOptions =>
      'Nessuna opzione di qualità disponibile per questo stream.';

  @override
  String get youtubeDefaultTitle => 'Video YouTube';

  @override
  String get youtubeStreamLabel => 'Stream YouTube';

  @override
  String get playerResolvingStream => 'Risoluzione stream in corso...';

  @override
  String get playerCheckingDebridCache => 'Verifica cache debrid';

  @override
  String get sectionVisualArchives => 'Archivio Video';

  @override
  String get failureNetwork =>
      'Impossibile raggiungere il server. Controlla la connessione.';

  @override
  String get failureAuth => 'Accedi di nuovo.';

  @override
  String get failureServer =>
      'Il server ha avuto un problema. Riprova più tardi.';

  @override
  String get failureNotFound => 'Elemento non trovato.';

  @override
  String get failureStreaming => 'Impossibile riprodurre questo video.';

  @override
  String get failureValidation => 'Alcuni dati non sono validi.';

  @override
  String get failureUnknown => 'Qualcosa è andato storto.';

  @override
  String get debridFileDownloading =>
      'Il tuo servizio debrid lo sta ancora scaricando. Riprova più tardi.';

  @override
  String get debridFileCopyright =>
      'Il tuo servizio debrid rifiuta questo file (copyright).';

  @override
  String get debridFileLimit =>
      'Il tuo servizio debrid ha troppi download in corso, o l\'account ha raggiunto un limite.';

  @override
  String get debridFileOther =>
      'La fonte ha inviato un video di errore al posto del video.';

  @override
  String get shellPressBackAgainToExit => 'Premi di nuovo Indietro per uscire';

  @override
  String get errorTimeout => 'Connessione scaduta. Controlla la connessione.';

  @override
  String errorServerStatus(Object statusCode) {
    return 'Il server ha restituito un errore ($statusCode).';
  }

  @override
  String get errorCertificateHint =>
      'Al sistema potrebbero mancare alcuni certificati radice. Prova ad aggiornare Windows o controlla firewall/DNS.';

  @override
  String get authErrorInvalidCredentials => 'Email o password non validi.';

  @override
  String get authErrorEmailNotConfirmed => 'Conferma il tuo indirizzo email.';

  @override
  String get authErrorUserExists => 'Esiste già un account con questa email.';

  @override
  String get authErrorGeneric => 'Accesso non riuscito. Riprova.';

  @override
  String get updatePreparingInstaller =>
      'Avvio del programma di installazione...';

  @override
  String get updateRestarting => 'File sostituiti. Riavvio tra un momento...';

  @override
  String get genreAction => 'Azione';

  @override
  String get genreAdventure => 'Avventura';

  @override
  String get genreAnimation => 'Animazione';

  @override
  String get genreComedy => 'Commedia';

  @override
  String get genreCrime => 'Crime';

  @override
  String get genreDocumentary => 'Documentario';

  @override
  String get genreDrama => 'Dramma';

  @override
  String get genreFamily => 'Famiglia';

  @override
  String get genreFantasy => 'Fantasy';

  @override
  String get genreHistory => 'Storia';

  @override
  String get genreHorror => 'Horror';

  @override
  String get genreMusic => 'Musica';

  @override
  String get genreMystery => 'Mistero';

  @override
  String get genreRomance => 'Romance';

  @override
  String get genreSciFi => 'Fantascienza';

  @override
  String get genreTVMovie => 'Film TV';

  @override
  String get genreThriller => 'Thriller';

  @override
  String get genreWar => 'Guerra';

  @override
  String get genreWestern => 'Western';

  @override
  String get genreActionAdventure => 'Azione e avventura';

  @override
  String get genreKids => 'Bambini';

  @override
  String get genreNews => 'Notiziari';

  @override
  String get genreReality => 'Reality';

  @override
  String get genreSciFiFantasy => 'Fantascienza e fantasy';

  @override
  String get genreSoap => 'Soap opera';

  @override
  String get genreTalk => 'Talk show';

  @override
  String get genreWarPolitics => 'Guerra e politica';

  @override
  String get languageEnglish => 'Inglese';

  @override
  String get languageSpanish => 'Spagnolo';

  @override
  String get languageFrench => 'Francese';

  @override
  String get languageGerman => 'Tedesco';

  @override
  String get languageItalian => 'Italiano';

  @override
  String get languagePortuguese => 'Portoghese';

  @override
  String get languageRussian => 'Russo';

  @override
  String get languageJapanese => 'Giapponese';

  @override
  String get languageKorean => 'Coreano';

  @override
  String get languageChinese => 'Cinese';

  @override
  String get languageHindi => 'Hindi';

  @override
  String get languageDutch => 'Olandese';

  @override
  String get languageSwedish => 'Svedese';

  @override
  String get languageDanish => 'Danese';

  @override
  String get languagePolish => 'Polacco';

  @override
  String get languageTurkish => 'Turco';

  @override
  String get languageThai => 'Thailandese';

  @override
  String get languageIndonesian => 'Indonesiano';

  @override
  String get languageArabic => 'Arabo';

  @override
  String get languageCzech => 'Ceco';

  @override
  String get languageGreek => 'Greco';

  @override
  String get languageFinnish => 'Finlandese';

  @override
  String get languageHebrew => 'Ebraico';

  @override
  String get languageHungarian => 'Ungherese';

  @override
  String get languageNorwegian => 'Norvegese';

  @override
  String get languageRomanian => 'Rumeno';

  @override
  String get languageUkrainian => 'Ucraino';

  @override
  String get languageVietnamese => 'Vietnamita';

  @override
  String get languageBulgarian => 'Bulgaro';

  @override
  String get languageCroatian => 'Croato';

  @override
  String get languageSerbian => 'Serbo';

  @override
  String get languageSlovak => 'Slovacco';

  @override
  String get languageSlovenian => 'Sloveno';

  @override
  String get languageEstonian => 'Estone';

  @override
  String get languageLatvian => 'Lettone';

  @override
  String get languageLithuanian => 'Lituano';

  @override
  String get languageIcelandic => 'Islandese';

  @override
  String get languageCatalan => 'Catalano';

  @override
  String get languageBasque => 'Basco';

  @override
  String get languageGalician => 'Galiziano';

  @override
  String get languageMalay => 'Malese';

  @override
  String get languagePersian => 'Persiano';

  @override
  String get languageTamil => 'Tamil';

  @override
  String get languageTelugu => 'Telugu';

  @override
  String get languageFilipino => 'Filippino';

  @override
  String get languageBengali => 'Bengalese';

  @override
  String get streamingErrorNoProviders =>
      'Nessun addon di streaming abilitato. Controlla le impostazioni.';

  @override
  String get streamingErrorNoResults =>
      'Nessun risultato trovato tra gli addon.';

  @override
  String get streamingErrorResolutionFailed =>
      'Impossibile risolvere lo stream selezionato. Il link potrebbe non essere disponibile in cache.';

  @override
  String get streamingErrorMediaDetails =>
      'Impossibile recuperare i dettagli multimediali.';

  @override
  String get playerFiles => 'File';

  @override
  String playerFilesCount(int count) {
    return '$count file disponibili';
  }

  @override
  String playerProviderFailed(String time) {
    return 'Fallito ($time)';
  }

  @override
  String playerProviderResults(int count, String time) {
    return '$count risultati ($time)';
  }

  @override
  String get playerSkipToPlayback => 'Passa alla riproduzione';

  @override
  String get playerSelectFile => 'Seleziona File';

  @override
  String get playerSubtitles => 'Sottotitoli';

  @override
  String get commonGoBack => 'Torna Indietro';

  @override
  String get playerNextEpisode => 'Prossimo Episodio';

  @override
  String get playerPreviousChannel => 'Canale precedente';

  @override
  String get playerNextChannel => 'Canale successivo';

  @override
  String get playerChannelList => 'Lista canali';

  @override
  String get playerPlay => 'Riproduci';

  @override
  String get playerPause => 'Pausa';

  @override
  String get playerStop => 'Interrompi';

  @override
  String get playerSkipBackward => 'Riavvolgi 10 secondi';

  @override
  String get playerSkipForward => 'Avanti 10 secondi';

  @override
  String get playerSubtitleAppearance => 'Aspetto Sottotitoli';

  @override
  String get playerLookTab => 'Aspetto';

  @override
  String get playerAppearanceFontSize => 'Dimensione Carattere';

  @override
  String get playerAppearanceTextColor => 'Colore Testo';

  @override
  String get playerAppearanceBackground => 'Opacità Sfondo';

  @override
  String get playerAppearanceBottomPadding => 'Margine Inferiore';

  @override
  String get playerAppearancePositionBottom => 'Basso';

  @override
  String get playerAppearancePositionMiddle => 'Centro';

  @override
  String get playerAppearancePositionTop => 'Alto';

  @override
  String get playerAppearanceSaveDefault => 'Salva come Predefinito';

  @override
  String get playerAppearanceReset => 'Ripristina Predefiniti';

  @override
  String get playerAppearanceSave => 'Salva';

  @override
  String get playerAppearanceSampleText => 'Esempio Testo Sottotitoli';

  @override
  String get playerSubtitleSync => 'Sincronizzazione';

  @override
  String get settingsTitle => 'Impostazioni';

  @override
  String get settingsIdentity => 'Account e accesso';

  @override
  String get settingsIdentityDesc =>
      'Gestisci i tuoi dettagli personali e le preferenze di accesso.';

  @override
  String get settingsCustomization => 'Personalizzazione App';

  @override
  String get settingsCustomizationDesc =>
      'Personalizza la tua esperienza di visione e l\'aspetto dell\'app.';

  @override
  String get settingsIntegrations => 'Addon ed Estensioni';

  @override
  String get settingsIntegrationsDesc =>
      'Gestisci i provider di streaming, gli addon e le integrazioni esterne.';

  @override
  String get settingsInfoUpdates => 'Info e aggiornamenti';

  @override
  String get settingsInfoUpdatesDesc =>
      'La versione dell\'app e i suoi aggiornamenti.';

  @override
  String get settingsData => 'Dati e Archiviazione';

  @override
  String get settingsDataDesc => 'Gestisci i tuoi dati locali e la cache.';

  @override
  String get settingsProvidersTitle => 'Addon di Streaming';

  @override
  String get settingsProvidersDesc =>
      'Gestisci i tuoi addon compatibili con Stremio.';

  @override
  String get settingsAddNewAddon => 'AGGIUNGI NUOVO ADDON';

  @override
  String get settingsInstall => 'Installa';

  @override
  String get settingsAddonHint =>
      'Incolla l\'URL del manifest di Stremio per aggiungere nuove sorgenti.';

  @override
  String get settingsInstalledAddons => 'ADDON INSTALLATI';

  @override
  String get settingsNoAddons => 'Nessun addon installato';

  @override
  String get settingsAddonSuccess => 'Addon installato con successo';

  @override
  String get settingsAddonInvalid =>
      'Questo non è un link valido per un addon Stremio.';

  @override
  String get settingsCopiedToClipboard => 'URL copiato negli appunti';

  @override
  String get settingsCopy => 'Copia URL';

  @override
  String get settingsRemove => 'Rimuovi';

  @override
  String settingsAddonRemoved(Object name) {
    return '$name rimosso';
  }

  @override
  String get settingsNativeIntegrations => 'Provider Nativi';

  @override
  String settingsEnableSource(String name) {
    return 'Abilita $name';
  }

  @override
  String get settingsEnableBuiltInAnimeDesc =>
      'Sorgente di streaming anime nativa (nessun Debrid necessario)';

  @override
  String settingsAnimeTorrentsNeedDebrid(String name) {
    return '$name richiede Real-Debrid o TorBox con una chiave API';
  }

  @override
  String get settingsDebridServices => 'Servizi Debrid';

  @override
  String get settingsRealDebridTitle => 'Real-Debrid (Nativo)';

  @override
  String get settingsRealDebridKey => 'Chiave API Real-Debrid';

  @override
  String get settingsTorBoxTitle => 'TorBox (Nativo)';

  @override
  String get settingsTorBoxKey => 'Chiave API TorBox';

  @override
  String get settingsPreferredDebridTitle => 'Provider Debrid Preferito';

  @override
  String get settingsPreferredDebridDesc =>
      'Servizio a cui dare priorità quando i contenuti sono in cache su entrambi.';

  @override
  String get settingsOpenSubtitlesTitle => 'OpenSubtitles.com';

  @override
  String get settingsOpenSubtitlesKey => 'Chiave API OpenSubtitles';

  @override
  String get settingsOpenSubtitlesKeyDesc =>
      'Usato per la ricerca di sottotitoli esterni. Richiede una chiave API gratuita.';

  @override
  String get settingsOpenSubtitlesAutoDownloadTitle =>
      'Download automatico sottotitoli';

  @override
  String get settingsOpenSubtitlesAutoDownloadDesc =>
      'Scarica automaticamente i sottotitoli se la tua lingua preferita è assente. Consuma la quota API giornaliera.';

  @override
  String get settingsDisplayName => 'Nome Visualizzato';

  @override
  String get settingsDisplayNameDesc => 'Il tuo nome pubblico.';

  @override
  String get settingsEnterName => 'Inserisci il tuo nome';

  @override
  String get settingsLanguage => 'Lingua';

  @override
  String get settingsAppLanguage => 'Lingua App';

  @override
  String get settingsAppLanguageDesc => 'Cambia la lingua dell\'interfaccia.';

  @override
  String get settingsWatchRegion => 'Paese Streaming';

  @override
  String get settingsWatchRegionDesc =>
      'Esplora mostra i servizi di streaming di questo paese.';

  @override
  String get settingsUndoTime => 'Tempo per Annullare';

  @override
  String get settingsUndoTimeDesc =>
      'Quanto resta il messaggio Annulla dopo una rimozione. Disattivato: le rimozioni sono subito definitive.';

  @override
  String get settingsUndoTimeOff => 'Disattivato';

  @override
  String settingsUndoTimeSeconds(int seconds) {
    return '$seconds secondi';
  }

  @override
  String get settingsScreenSize => 'Dimensione Schermo';

  @override
  String get settingsScreenSizeDesc =>
      'Quanto sono grandi testi e pulsanti su questo dispositivo. Più piccolo, più cose sullo schermo.';

  @override
  String get settingsStartFullScreen => 'Avvia a Schermo Intero';

  @override
  String get settingsStartFullScreenDesc =>
      'Cinemuse si apre a schermo intero su questo computer. F11 lo cambia in ogni momento.';

  @override
  String get settingsCloseApp => 'Chiudi Cinemuse';

  @override
  String get settingsCloseAppDesc => 'Chiude l\'app su questo computer.';

  @override
  String get settingsAudioLanguage => 'Lingua Audio';

  @override
  String get settingsAudioLanguageDesc =>
      'Lingua audio preferita per film e serie.';

  @override
  String get settingsSubtitleLanguage => 'Lingua Sottotitoli';

  @override
  String get settingsSubtitleLanguageDesc =>
      'Lingua sottotitoli preferita per film e serie.';

  @override
  String get settingsShowSubtitles => 'Mostra Sottotitoli';

  @override
  String get settingsShowSubtitlesDesc =>
      'Attiva i sottotitoli quando parte un video';

  @override
  String get settingsJapanese => 'Giapponese';

  @override
  String get settingsOriginal => 'Originale';

  @override
  String get settingsPlayer => 'Preferenze Media';

  @override
  String get settingsEnglish => 'Inglese';

  @override
  String get settingsItalian => 'Italiano';

  @override
  String get settingsSplitAnimePreferences => 'Separa Preferenze Anime';

  @override
  String get settingsSplitAnimePreferencesDesc =>
      'Usa impostazioni audio e sottotitoli diverse per gli anime.';

  @override
  String get settingsAnimeAudioLanguage => 'Lingua Audio Anime';

  @override
  String get settingsAnimeAudioLanguageDesc =>
      'Lingua audio preferita per gli anime.';

  @override
  String get settingsAnimeShowSubtitles => 'Mostra Sottotitoli Anime';

  @override
  String get settingsAnimeShowSubtitlesDesc =>
      'Abilita o disabilita i sottotitoli di default per gli anime.';

  @override
  String get settingsAnimeSubtitleLanguage => 'Lingua Sottotitoli Anime';

  @override
  String get settingsAnimeSubtitleLanguageDesc =>
      'Lingua sottotitoli preferita per gli anime.';

  @override
  String get settingsPrimaryColor => 'Colore Primario';

  @override
  String get settingsPrimaryColorDesc =>
      'Colore accento principale per il player.';

  @override
  String get settingsSecondaryColor => 'Colore Secondario';

  @override
  String get settingsSecondaryColorDesc =>
      'Colore accento secondario per il player.';

  @override
  String get settingsOther => 'Altro';

  @override
  String get settingsShowDebugPanel => 'Mostra Pannello Debug';

  @override
  String get settingsShowDebugPanelDesc =>
      'Visualizza informazioni tecniche in sovrimpressione.';

  @override
  String get settingsSmartSearch => 'Pulizia Risultati Streaming';

  @override
  String get settingsSmartSearchDesc =>
      'Nascondi automaticamente i risultati CAM, Screener, 3D o spazzatura dai risultati degli addon.';

  @override
  String get settingsMaxResolution => 'Risoluzione Massima';

  @override
  String get settingsMaxResolutionDesc =>
      'Nascondi i link con una risoluzione superiore a quella selezionata.';

  @override
  String get settingsTotalDocSize => 'Spazio occupato';

  @override
  String get settingsTotalDocSizeDesc =>
      'Dimensione totale di tutti i tuoi dati salvati.';

  @override
  String get settingsUserProfile => 'Libreria Utente';

  @override
  String get settingsWatchedMovies => 'Film Visti';

  @override
  String get settingsWatchedSeries => 'Serie Viste';

  @override
  String get settingsLists => 'Liste';

  @override
  String get settingsAggregatedStats => 'Riepilogo statistiche';

  @override
  String get settingsSave => 'Salva';

  @override
  String get settingsSaved => 'Salvato';

  @override
  String get settingsBack => 'Torna alle Impostazioni';

  @override
  String get settingsLogout => 'Disconnetti';

  @override
  String get settingsProfile => 'Libreria';

  @override
  String get profileOverview => 'PANORAMICA';

  @override
  String get profileCollections => 'COLLEZIONI';

  @override
  String get profileUserDashboard => 'Libreria Utente';

  @override
  String get profileErrorLoading => 'Errore caricamento libreria';

  @override
  String profileMemberSince(Object year) {
    return 'Membro dal $year';
  }

  @override
  String get navLiveTV => 'Live TV';

  @override
  String get liveTvTitle => 'Live TV';

  @override
  String get liveTvSelectChannel =>
      'Seleziona un canale per iniziare a guardare';

  @override
  String get liveTvNoEpg => 'Nessuna informazione sul programma';

  @override
  String get liveTvLoading => 'Caricamento canali...';

  @override
  String get liveTvError => 'Errore caricamento canali';

  @override
  String get liveTvStreamUnavailable => 'Stream non disponibile';

  @override
  String get liveTvStreamUnavailableHint =>
      'Questo canale potrebbe essere offline o non disponibile nel tuo paese.';

  @override
  String get liveTvAllChannels => 'Tutti';

  @override
  String get liveTvHd => 'HD';

  @override
  String get liveTvNoChannels => 'Nessun canale trovato';

  @override
  String get liveTvSearchPlaceholder => 'Cerca canali...';

  @override
  String get settingsLiveTv => 'Live TV';

  @override
  String get settingsLiveTvRewind => 'Durata del riavvolgimento';

  @override
  String get settingsLiveTvRewindDesc =>
      'Quanto puoi tornare indietro in un canale live. Un dispositivo con poca memoria libera ne tiene meno.';

  @override
  String settingsLiveTvRewindMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get settingsNone => 'Nessuna';

  @override
  String get liveTvCategories => 'Categorie';

  @override
  String get liveTvProviders => 'Provider';

  @override
  String get liveTvBrowse => 'Sfoglia';

  @override
  String get liveTvGroupMode => 'Raggruppamento';

  @override
  String get agendaTitle => 'Agenda';

  @override
  String get agendaSubtitle => 'Prossime uscite dalla tua libreria';

  @override
  String get agendaLoading => 'Controllo aggiornamenti...';

  @override
  String get agendaNoEvents => 'Nessuna prossima uscita trovata';

  @override
  String get agendaToday => 'Oggi';

  @override
  String get agendaTomorrow => 'Domani';

  @override
  String get agendaThisWeek => 'Questa Settimana';

  @override
  String get agendaNextWeek => 'Prossima Settimana';

  @override
  String get agendaLater => 'Più avanti';

  @override
  String get agendaMovie => 'Film';

  @override
  String get agendaSeries => 'Serie TV';

  @override
  String get agendaRecentlyReleased => 'Usciti di Recente';

  @override
  String get agendaTbd => 'TBD / In Arrivo';

  @override
  String get agendaTbdLabel => 'Da definire';

  @override
  String updateAvailableMessage(Object version) {
    return 'Versione $version disponibile: Impostazioni → Info e aggiornamenti';
  }

  @override
  String get updateInstalledVersion => 'Versione installata';

  @override
  String get updateNewVersion => 'Nuova versione';

  @override
  String get updateCheck => 'Controlla aggiornamenti';

  @override
  String get updateChecking => 'Controllo degli aggiornamenti...';

  @override
  String get updateWhatsNew => 'Novità';

  @override
  String get updateNow => 'Aggiorna Ora';

  @override
  String downloadingUpdate(Object progress) {
    return 'Scaricamento aggiornamento $progress%';
  }

  @override
  String get updateFailed => 'Aggiornamento fallito. Riprova più tardi.';

  @override
  String updateNoCompatibleApk(Object abi) {
    return 'Nessun aggiornamento compatibile trovato per l\'architettura del tuo dispositivo ($abi)';
  }

  @override
  String get updateUpToDate => 'L\'app è aggiornata';

  @override
  String get updateCancel => 'Annulla Aggiornamento';

  @override
  String get updateNetworkError =>
      'Errore di rete durante l\'aggiornamento. Controlla la tua connessione.';

  @override
  String get updateStorageError =>
      'Spazio di archiviazione insufficiente per scaricare l\'aggiornamento.';

  @override
  String get updateSourceError =>
      'La sorgente dell\'aggiornamento non è al momento disponibile.';

  @override
  String get updateIntegrityError =>
      'Non è stato possibile verificare l\'aggiornamento scaricato, quindi non è stato installato.';

  @override
  String get updateFolderNotWritable =>
      'Cinemuse non può aggiornarsi in questa cartella. Sposta la cartella di Cinemuse in una posizione tua (ad esempio Documenti) oppure scarica l\'aggiornamento da GitHub.';

  @override
  String get updateAlreadyRunning => 'Un aggiornamento è già in corso.';

  @override
  String get updatePermissionDenied =>
      'Cinemuse ha bisogno del permesso di installare app. Concedilo nelle Impostazioni, poi riprova.';

  @override
  String get updateRequiredTitle => 'Aggiornamento necessario';

  @override
  String get updateRequiredMessage =>
      'Questa versione di Cinemuse è troppo vecchia per funzionare con il tuo account. Aggiorna l\'app per continuare a usarla.';

  @override
  String get menuMoreOptions => 'Altre Opzioni';

  @override
  String get menuAddToWatchlist => 'Aggiungi alla Watchlist';

  @override
  String get menuRemoveFromWatchlist => 'Rimuovi dalla Watchlist';

  @override
  String get watchlistAdded => 'Aggiunto alla Watchlist';

  @override
  String get watchlistRemoved => 'Rimosso dalla Watchlist';

  @override
  String get cardInWatchlist => 'Nella Watchlist';

  @override
  String get cardInFavorites => 'Nei Preferiti';

  @override
  String get menuAddToFavorites => 'Aggiungi ai Preferiti';

  @override
  String get menuRemoveFromFavorites => 'Rimuovi dai Preferiti';

  @override
  String get menuRemoveFromList => 'Rimuovi dalla Lista';

  @override
  String get menuMarkAsWatched => 'Segna come Visto';

  @override
  String get menuMarkAsUnwatched => 'Segna come Non Visto';

  @override
  String get menuShare => 'Condividi';

  @override
  String get menuResume => 'Riprendi';

  @override
  String get menuRestart => 'Ricomincia';

  @override
  String get menuClearProgress => 'Azzera Avanzamento';

  @override
  String get menuMarkWatchedNow => 'Segna come visto (ora)';

  @override
  String get menuMarkWatchedCustomDate =>
      'Segna come visto (data personalizzata)';

  @override
  String get menuPlay => 'Riproduci';

  @override
  String get menuStopWatching => 'Interrompi Visione';

  @override
  String get menuCancelRewatch => 'Annulla Rewatch';

  @override
  String get menuRemoveCachedProvider => 'Rimuovi Stream in Cache';

  @override
  String get menuManageWatchHistory => 'Modifica visione';

  @override
  String get liveTvTabAll => 'Tutti';

  @override
  String get liveTvTabFavorites => 'Preferiti';

  @override
  String get liveTvTabRecents => 'Recenti';

  @override
  String get liveTvFilterChannels => 'Filtra Canali';

  @override
  String get liveTvGroupBy => 'Raggruppa per';

  @override
  String get liveTvSubProvider => 'Sub-provider';

  @override
  String get liveTvApplyFilters => 'Applica Filtri';

  @override
  String get liveTvClearFilters => 'Rimuovi Filtri';

  @override
  String get liveTvAddedToFavorites => 'Aggiunto ai preferiti';

  @override
  String get liveTvRemovedFromFavorites => 'Rimosso dai preferiti';

  @override
  String get liveTvNoFavorites => 'Nessun canale preferito';

  @override
  String get liveTvNoFavoritesHint =>
      'Tieni premuto su un canale per aggiungerlo ai preferiti';

  @override
  String get liveTvNoRecents => 'Nessun canale guardato di recente';

  @override
  String get liveTvPlaylistsDesc =>
      'I canali Cinemuse, più le tue playlist M3U/JSON da link o file.';

  @override
  String get liveTvCinemuseChannels => 'Canali in chiaro';

  @override
  String get liveTvTypeBuiltIn => 'Integrata';

  @override
  String get liveTvAddUrl => 'Aggiungi URL';

  @override
  String get liveTvAddFile => 'Aggiungi File';

  @override
  String get liveTvAddRemotePlaylist => 'Aggiungi Playlist Remota';

  @override
  String get liveTvPlaylistName => 'Nome Playlist';

  @override
  String get liveTvPlaylistUrl => 'URL Playlist';

  @override
  String get liveTvPlaylistFormat => 'Formato';

  @override
  String get liveTvOpenFileLocation => 'Apri Cartella';

  @override
  String get liveTvOpenLink => 'Apri Link';

  @override
  String get liveTvManagePlaylists => 'Gestisci Playlist';

  @override
  String get liveTvTypeM3uFile => 'File M3U';

  @override
  String get liveTvTypeJsonFile => 'File JSON';

  @override
  String get liveTvTypeM3uUrl => 'URL M3U';

  @override
  String get liveTvTypeJsonUrl => 'URL JSON';

  @override
  String get liveTvPlaylists => 'Playlist ed EPG';

  @override
  String get liveTvFilterAndPlaylists => 'Filtri e Playlist';

  @override
  String get liveTvEpgSection => 'Guida TV (EPG)';

  @override
  String get liveTvCinemuseGuide => 'Guida dei canali in chiaro';

  @override
  String get liveTvAddRemoteGuide => 'Aggiungi Guida Remota';

  @override
  String get liveTvGuideName => 'Nome Guida';

  @override
  String get liveTvGuideUrl => 'URL Guida';

  @override
  String get liveTvTypeXmltvFile => 'File XMLTV';

  @override
  String get liveTvTypeXmltvUrl => 'URL XMLTV';

  @override
  String get liveTvPlaylistsTitle => 'Playlist';

  @override
  String get liveTvRefreshAll => 'Aggiorna';

  @override
  String get liveTvRefreshed => 'Playlist e guide aggiornate';

  @override
  String liveTvSourceRemoved(Object name) {
    return '$name rimossa';
  }

  @override
  String liveTvCouldNotLoad(Object details) {
    return 'Impossibile caricare: $details';
  }

  @override
  String liveTvFailedPlaylist(Object name) {
    return '$name (playlist)';
  }

  @override
  String liveTvFailedGuide(Object name) {
    return '$name (EPG)';
  }

  @override
  String liveTvSavedGuideShown(Object details) {
    return 'Mostro la guida salvata. Impossibile aggiornare: $details';
  }

  @override
  String liveTvSavedChannelsShown(Object details) {
    return 'Mostro i canali salvati. Impossibile aggiornare: $details';
  }

  @override
  String get liveTvNoChannelsInIt => 'Non contiene canali.';

  @override
  String get liveTvNoProgrammesInIt => 'Non contiene programmi.';

  @override
  String get liveTvFileNotFound => 'Il file non è stato trovato.';

  @override
  String get tvTimeComments => 'Commenti';

  @override
  String get tvTimeNoComments => 'Ancora nessun commento.';

  @override
  String get commentsLoadMore => 'Carica altri commenti';

  @override
  String tvTimeReplies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count risposte',
      one: '$count risposta',
    );
    return '$_temp0';
  }

  @override
  String get tvTimeLoadingComments => 'Caricamento commenti...';

  @override
  String get tvTimeCommentsError => 'Impossibile caricare i commenti.';

  @override
  String get commentsSpoilerWarning => 'Avviso spoiler';

  @override
  String get commentsTapToReveal => 'Tocca per mostrare';

  @override
  String get commentsSortMostLiked => 'Più popolari';

  @override
  String get commentsSortRecent => 'Recenti';

  @override
  String get commentsSortRating => 'Voto più alto';

  @override
  String get commentsFilterAnyLanguage => 'Qualsiasi lingua';

  @override
  String get commentsFilterEnglish => 'Inglese';

  @override
  String get commentsFilterItalian => 'Italiano';

  @override
  String get commentsFilterEnIt => 'Inglese + Italiano';

  @override
  String get commentsFilterAllSources => 'Tutte le fonti';

  @override
  String get commentsSourceLetterboxd => 'Letterboxd';

  @override
  String get commentsSourceImdb => 'IMDb';

  @override
  String get ownReviewAdd => 'Aggiungi una recensione';

  @override
  String get ownReviewEdit => 'Modifica recensione';

  @override
  String get ownReviewNotWatched => 'Segna come visto per recensire';

  @override
  String get ownReviewEditorTitle => 'La tua recensione';

  @override
  String get ownReviewScoreField => 'Il tuo voto';

  @override
  String ownReviewScoreLabel(int score) {
    return 'Voto $score su 10';
  }

  @override
  String get ownReviewTextField => 'Recensione (facoltativa)';

  @override
  String get ownReviewFormattingHint =>
      '**grassetto**, *corsivo*, - elenchi e > citazioni funzionano';

  @override
  String get ownReviewSave => 'Salva';

  @override
  String get ownReviewRemove => 'Rimuovi recensione';

  @override
  String get ownReviewRemoved => 'Recensione rimossa';

  @override
  String get ownReviewChangesDiscarded => 'Modifiche scartate';

  @override
  String get ownReviewLoadError => 'Impossibile caricare la tua recensione';

  @override
  String get settingsSearchPreferences => 'Preferenze di Ricerca';

  @override
  String get settingsAutoSkipProviders =>
      'Salta Automaticamente Provider Lenti';

  @override
  String get settingsAutoSkipProvidersDesc =>
      'Salta i provider di streaming che impiegano più di 10 secondi a rispondere.';

  @override
  String get profileRecentMovies => 'Film recenti';

  @override
  String get profileRecentSeries => 'Serie recenti';

  @override
  String get statsTimeBreakdown => 'Suddivisione tempo';

  @override
  String get statsAllTime => 'Totale';

  @override
  String get statsMovies => 'Film';

  @override
  String get statsSeries => 'Serie';

  @override
  String get statsLast7Days => 'Ultimi 7 giorni';

  @override
  String get statsLast30Days => 'Ultimi 30 giorni';

  @override
  String get statsLastYear => 'Ultimo anno';

  @override
  String get statsMoviesStats => 'Statistiche film';

  @override
  String get statsSeriesStats => 'Statistiche serie';

  @override
  String get statsEpisodes => 'Episodi';

  @override
  String get statsSeasons => 'Stagioni';

  @override
  String get statsTime => 'Tempo';

  @override
  String get detailsCreatorsAndDirectors => 'Creatori e registi';

  @override
  String get detailsDirector => 'Regista';

  @override
  String get detailsCreator => 'Creatore';

  @override
  String get detailsWriter => 'Sceneggiatore';

  @override
  String get detailsWriters => 'Sceneggiatori';

  @override
  String get detailsPeople => 'Cast e Troupe';

  @override
  String get detailsSectionCrew => 'CREW';

  @override
  String get detailsSectionCast => 'CAST';

  @override
  String get detailsTvTimeComments => 'Commenti';

  @override
  String get detailsExternalLinks => 'Link esterni';

  @override
  String get detailsTrack => 'Segna';

  @override
  String get detailsWatched => 'Visto';

  @override
  String detailsWatchedCount(int count) {
    return 'Visto x$count';
  }

  @override
  String get detailsUpToDate => 'In pari';

  @override
  String detailsUpToDateCount(int count) {
    return 'In pari x$count';
  }

  @override
  String get detailsFinishSeries => 'Finisci serie';

  @override
  String get commonNoContent => 'Nessun contenuto disponibile';

  @override
  String get commonStopCasting => 'INTERROMPI TRASMISSIONE';

  @override
  String get castConnectDevice => 'Connetti al dispositivo';

  @override
  String get castNoDevices => 'Nessun dispositivo trovato';

  @override
  String get castRefresh => 'Aggiorna';

  @override
  String get profileNoRecentItems => 'Nessun elemento guardato di recente';

  @override
  String get detailsEditList => 'Modifica lista';

  @override
  String get detailsDeleteList => 'Elimina lista';

  @override
  String get detailsTvTimeCommentsNotAvailable =>
      'Commenti non disponibili per questo contenuto';

  @override
  String get detailsTvTimeCommentsNotAvailableSeries =>
      'Commenti non disponibili per questa serie';

  @override
  String get detailsFailedLoadCollection =>
      'Impossibile caricare i dettagli della collezione';

  @override
  String get detailsFeaturedCritic => 'Critico in evidenza';

  @override
  String get offlineBannerTitle => 'Modalità offline';

  @override
  String get offlineBannerMessage =>
      'Mostrati solo i contenuti salvati in cache.';

  @override
  String get castSearching => 'Ricerca dispositivi in corso...';

  @override
  String castError(String error) {
    return 'Errore: $error';
  }

  @override
  String castCastingTo(String deviceName) {
    return 'Trasmissione su $deviceName';
  }

  @override
  String castSeasonEpisode(int season, int episode) {
    return 'Stagione $season • Episodio $episode';
  }

  @override
  String statsDaysHours(int days, int hours) {
    return '${days}g ${hours}o';
  }

  @override
  String get listWatchLater => 'Guarda più tardi';

  @override
  String get listFavorites => 'Preferiti';

  @override
  String get listYourQueue => 'La tua coda';

  @override
  String get listCuratedPicks => 'I tuoi elementi selezionati';

  @override
  String get listDropped => 'Interrotti';

  @override
  String get listDroppedSubtitle => 'Titoli che hai interrotto.';

  @override
  String get menuRestoreContinueWatching => 'Ripristina in Continua a Guardare';

  @override
  String get listUntitled => 'Lista senza nome';

  @override
  String get listNameHint => 'Nome lista';

  @override
  String get listDescriptionHint => 'Aggiungi una descrizione...';

  @override
  String listItemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementi',
      one: '$count elemento',
    );
    return '$_temp0';
  }

  @override
  String get listEmptyTitle => 'Questa lista è vuota';

  @override
  String get listEmptyMessage => 'Aggiungi contenuti dalla pagina dei dettagli';

  @override
  String get collectionTitleFallback => 'Collezione';

  @override
  String get collectionSubtitle => 'Collezione di film';

  @override
  String get menuOpenList => 'Apri lista';

  @override
  String get listPinToHome => 'Fissa nella Home';

  @override
  String get listUnpinFromHome => 'Rimuovi dalla Home';

  @override
  String get listPinnedSuccess => 'Aggiunto alla Home';

  @override
  String get listUnpinnedSuccess => 'Rimosso dalla Home';

  @override
  String get playerLiveSources => 'Sorgente';

  @override
  String get playerPictureSize => 'Qualità';

  @override
  String get playerPictureSizeSuggestLower =>
      'Il flusso continua a fermarsi. Prova una qualità più bassa nel menu Qualità.';

  @override
  String get playerActiveSource => 'Attiva';

  @override
  String get playerSourceFailed => 'Non disponibile';

  @override
  String get watchHistoryTitle => 'Cronologia';

  @override
  String watchHistorySubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count titoli',
      one: '1 titolo',
    );
    return '$_temp0';
  }

  @override
  String watchHistoryFilteredCount(int filtered, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total titoli',
      one: '1 titolo',
    );
    return '$filtered di $_temp0';
  }

  @override
  String watchHistoryBreakdown(int movies, int series) {
    String _temp0 = intl.Intl.pluralLogic(
      movies,
      locale: localeName,
      other: '$movies film',
      one: '1 film',
    );
    String _temp1 = intl.Intl.pluralLogic(
      series,
      locale: localeName,
      other: '$series serie',
      one: '1 serie',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String watchHistoryMoviesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count film',
      one: '1 film',
    );
    return '$_temp0';
  }

  @override
  String watchHistoryFilteredMoviesCount(int filtered, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total film',
      one: '1 film',
    );
    return '$filtered di $_temp0';
  }

  @override
  String watchHistorySeriesBreakdown(int series, int seasons, int episodes) {
    String _temp0 = intl.Intl.pluralLogic(
      series,
      locale: localeName,
      other: '$series serie TV',
      one: '1 serie TV',
    );
    String _temp1 = intl.Intl.pluralLogic(
      seasons,
      locale: localeName,
      other: '$seasons stagioni',
      one: '1 stagione',
    );
    String _temp2 = intl.Intl.pluralLogic(
      episodes,
      locale: localeName,
      other: '$episodes episodi',
      one: '1 episodio',
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
      other: '$totalSeries serie TV',
      one: '1 serie TV',
    );
    String _temp1 = intl.Intl.pluralLogic(
      seasons,
      locale: localeName,
      other: '$seasons stagioni',
      one: '1 stagione',
    );
    String _temp2 = intl.Intl.pluralLogic(
      episodes,
      locale: localeName,
      other: '$episodes episodi',
      one: '1 episodio',
    );
    return '$filteredSeries di $_temp0, $_temp1, $_temp2';
  }

  @override
  String get watchHistorySearchPlaceholder => 'Cerca titoli visti...';

  @override
  String get watchHistoryAll => 'Tutti';

  @override
  String get watchHistoryStatusAll => 'Tutti gli stati';

  @override
  String get watchHistoryStatusWatching => 'In corso';

  @override
  String get watchHistoryStatusCompleted => 'Completati';

  @override
  String get watchHistoryStatusDropped => 'Abbandonati';

  @override
  String get watchHistorySortRecent => 'Visti di recente';

  @override
  String get watchHistorySortTitle => 'Titolo (A-Z)';

  @override
  String get watchHistoryViewGrid => 'Griglia';

  @override
  String get watchHistoryViewTimeline => 'Cronologia';

  @override
  String get watchHistoryViewRatings => 'Voti';

  @override
  String watchHistoryRatedCount(int rated, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total titoli',
      one: '1 titolo',
    );
    return '$rated votati su $_temp0';
  }

  @override
  String get watchHistoryRatingsEmpty => 'Ancora nessun voto';

  @override
  String get watchHistoryDateToday => 'Oggi';

  @override
  String get watchHistoryDateYesterday => 'Ieri';

  @override
  String get watchHistoryDateThisWeek => 'Questa settimana';

  @override
  String get watchHistoryDateThisMonth => 'Questo mese';

  @override
  String get watchHistoryReplay => 'Rivedi';

  @override
  String seasonEpisodeShort(int season, int episode) {
    return 'S$season E$episode';
  }

  @override
  String get watchHistoryEmpty => 'Nessuna cronologia trovata';

  @override
  String get watchHistoryGranularityDaily => 'Giornaliero';

  @override
  String get watchHistoryGranularityMonthly => 'Mensile';

  @override
  String get watchHistoryGranularityYearly => 'Annuale';

  @override
  String watchHistoryStackedEpisodes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count episodi',
      one: '1 episodio',
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
  String get watchHistoryFiltersTitle => 'Filtri';

  @override
  String get watchHistoryResetFilters => 'Reimposta';

  @override
  String get watchHistoryApplyFilters => 'Applica filtri';

  @override
  String get watchHistoryFilterType => 'Tipo';

  @override
  String get watchHistoryFilterStatus => 'Stato';

  @override
  String get watchHistoryFilterSort => 'Ordina per';

  @override
  String get watchHistoryFilterGranularity => 'Raggruppa per';

  @override
  String watchHistoryActiveFilterCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count filtri',
      one: '1 filtro',
    );
    return '$_temp0';
  }

  @override
  String get liveTvFullWindow => 'A tutto schermo';

  @override
  String get liveTvSplitView => 'Vista divisa';

  @override
  String get liveTvChannels => 'Canali';

  @override
  String get liveTvCloseOverlay => 'Chiudi lista canali';

  @override
  String get liveTvLive => 'Diretta';

  @override
  String get liveTvGoToLive => 'Vai alla diretta';

  @override
  String get playerFullscreen => 'Schermo intero';

  @override
  String get playerExitFullscreen => 'Esci da schermo intero';

  @override
  String get seriesStatusOngoing => 'In corso';

  @override
  String get seriesStatusEnded => 'Conclusa';

  @override
  String get seriesStatusCanceled => 'Cancellata';

  @override
  String get seriesStatusInProduction => 'In produzione';

  @override
  String get seriesStatusPlanned => 'Pianificata';

  @override
  String get seriesStatusPilot => 'Pilota';

  @override
  String get settingsAnimeTorrentsDesc =>
      'Sorgente anime integrata di alta qualità (torrent)';

  @override
  String get settingsMovieSiteDesc =>
      'Sorgente integrata in streaming diretto (non serve il debrid)';

  @override
  String get listCardEmpty => 'Ancora nessun titolo';

  @override
  String get listCardOpenAll => 'Apri per vedere tutti i titoli';

  @override
  String get settingsResolutionAny => 'Qualsiasi';

  @override
  String get playerTrackForced => 'Forzati';

  @override
  String get playerTrackCc => 'CC';

  @override
  String playerTrackNumber(String number) {
    return 'Traccia $number';
  }

  @override
  String get menuViewWatchHistory => 'Visualizza cronologia';

  @override
  String get liveTvJumpToNow => 'Vai alla diretta';

  @override
  String get liveTvTvGuide => 'Guida TV';

  @override
  String get liveTvNoProgramDetails =>
      'Nessuna sinossi disponibile per questo programma.';

  @override
  String liveTvMinutesRemaining(int minutes) {
    return '${minutes}m rimanenti';
  }

  @override
  String get playerCached => 'IN CACHE';

  @override
  String get castDefaultDevice => 'Chromecast';

  @override
  String playerErrorPrefix(String error) {
    return 'Errore: $error';
  }
}
