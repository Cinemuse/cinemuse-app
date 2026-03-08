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
  String get commonConfirm => 'Conferma';

  @override
  String get commonCreate => 'Crea';

  @override
  String get commonDelete => 'Elimina';

  @override
  String get commonFeatured => 'IN PRIMO PIANO';

  @override
  String get commonUnexpectedError => 'Si è verificato un errore imprevisto';

  @override
  String get commonOk => 'OK';

  @override
  String get searchPlaceholder => 'Cerca film, serie...';

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
  String get searchSeries => 'Serie';

  @override
  String get searchPersons => 'Persone';

  @override
  String get searchAdvancedFilters => 'Filtri Avanzati';

  @override
  String get searchFilterAction => 'Filtri';

  @override
  String get searchFilteredResults => 'Risultati';

  @override
  String get searchSortBy => 'Ordina Per';

  @override
  String get searchMostPopular => 'Più Popolari';

  @override
  String get searchHighestRated => 'Voto Più Alto';

  @override
  String get searchNewestReleases => 'Ultime Uscite';

  @override
  String get searchLanguages => 'Lingue';

  @override
  String get searchGenres => 'Generi';

  @override
  String get searchRating => 'Voto';

  @override
  String get searchYearRange => 'Intervallo Anni';

  @override
  String get searchVoteCount => 'Numero Voti';

  @override
  String get searchRuntime => 'Durata';

  @override
  String get searchClearAll => 'Cancella Tutto';

  @override
  String get searchNoResultsTitle => 'Nessun risultato trovato';

  @override
  String get searchTryAdjusting => 'Prova a regolare i filtri';

  @override
  String get searchMatchAny => 'Corrisponde a qualsiasi';

  @override
  String get searchMatchAll => 'Corrisponde a tutti';

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
    return 'Errore nel caricamento della stagione: $error';
  }

  @override
  String get detailsSeasonNotFound => 'Dettagli stagione non trovati';

  @override
  String get detailsDeleteListTitle => 'Eliminare la lista?';

  @override
  String detailsDeleteListConfirm(Object name) {
    return 'Sei sicuro di voler eliminare \'$name\'?';
  }

  @override
  String get detailsCollectionsTitle => 'Collezioni';

  @override
  String get detailsCollectionsDesc => 'Le tue liste personalizzate.';

  @override
  String get detailsNewCollection => 'Nuova Collezione';

  @override
  String get detailsNoCollections =>
      'Nessuna Collezione ancora. Creane una per iniziare a organizzare!';

  @override
  String get detailsAddToList => 'Aggiungi alla lista';

  @override
  String get detailsNoCustomLists => 'Nessuna lista personalizzata ancora';

  @override
  String get detailsCreateNewList => 'Crea Nuova Lista';

  @override
  String get detailsMarkPreviousTitle => 'Segna precedenti?';

  @override
  String detailsMarkPreviousDesc(Object count, Object episode) {
    return 'Hai segnato l\'Episodio $episode. Vuoi segnare anche i $count episodi precedenti non visti come visti?';
  }

  @override
  String get detailsOnlyThisOne => 'Solo questo';

  @override
  String get detailsCollectionNameHint =>
      'Nome Collezione (es., \'Gemme Sci-Fi\')';

  @override
  String get homeErrorLoadingFeatures => 'Errore nel caricamento dei contenuti';

  @override
  String get homeMoreInfo => 'Più Info';

  @override
  String get homeTrendingNow => 'Di Tendenza';

  @override
  String get homePopularMovies => 'Film Popolari';

  @override
  String get homePopularSeries => 'Serie Popolari';

  @override
  String get authContinueGuest => 'Continua come Ospite';

  @override
  String get authWelcomeBack => 'Bentornato';

  @override
  String get authJoinCineMuse => 'Unisciti a CineMuse';

  @override
  String get authEnterCredentials =>
      'Inserisci le tue credenziali per accedere';

  @override
  String get authCreateAccount => 'Crea un account per iniziare a guardare';

  @override
  String get authEmail => 'EMAIL';

  @override
  String get authPassword => 'PASSWORD';

  @override
  String get authSignIn => 'Accedi';

  @override
  String get authCreateAccountAction => 'Crea Account';

  @override
  String get authNoAccount => 'Non hai un account?';

  @override
  String get authHaveAccount => 'Hai già un account?';

  @override
  String get authOr => 'OPPURE';

  @override
  String get authDebugLogin => 'Accesso Debug';

  @override
  String settingsErrorSaving(Object error) {
    return 'Errore nel salvataggio: $error';
  }

  @override
  String get detailsEpisodes => 'EPISODI';

  @override
  String get detailsCast => 'CAST';

  @override
  String get detailsPlay => 'Riproduci';

  @override
  String get detailsMyList => 'La mia lista';

  @override
  String detailsErrorLoading(Object error) {
    return 'Errore nel caricamento dei dettagli: $error';
  }

  @override
  String get detailsDecryptingMetadata => 'Decriptazione metadati...';

  @override
  String get detailsEpisodesRegistry => 'Registro Episodi';

  @override
  String get detailsMarkSeasonWatched => 'Segna stagione come vista';

  @override
  String get detailsSeasonLabel => 'Stagione';

  @override
  String detailsSeasonNumber(Object num) {
    return 'Stagione $num';
  }

  @override
  String get detailsSynopsis => 'Sinossi';

  @override
  String detailsResumeEpisode(Object episode, Object season) {
    return 'Riprendi S$season E$episode';
  }

  @override
  String get detailsResume => 'Riprendi';

  @override
  String get detailsPlayNow => 'Riproduci ora';

  @override
  String get detailsSeriesProgress => 'Progresso Serie';

  @override
  String get detailsCreativeVision => 'Visione Creativa';

  @override
  String get detailsVerdict => 'Verdetto';

  @override
  String get detailsReviews => 'Recensioni';

  @override
  String get detailsReviewsAll => 'Leggi tutte le recensioni';

  @override
  String get detailsFinances => 'Finanze';

  @override
  String get detailsProductionDNA => 'DNA di Produzione';

  @override
  String get detailsRate => 'VALUTA';

  @override
  String get detailsMarkRemaining => 'Segna Rimanenti';

  @override
  String get detailsMarkAll => 'Segna Tutti';

  @override
  String get detailsRewatchSeries => 'Riguarda Serie';

  @override
  String get detailsRemoveAll => 'Rimuovi Tutti';

  @override
  String get detailsBudget => 'Budget';

  @override
  String get detailsRevenue => 'Incasso';

  @override
  String get detailsExternalLinks => 'Link Esterni';

  @override
  String get detailsVideos => 'Video';

  @override
  String get detailsLinks => 'Link';

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
      'Segna come visto (Tieni premuto per la data)';

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
  String get personShowMore => 'Mostra altro';

  @override
  String get personShowLess => 'Mostra meno';

  @override
  String get personShowHidden => 'Mostra nascosti';

  @override
  String personShowingCredits(Object total, Object visible) {
    return 'Visualizzati $visible di $total crediti';
  }

  @override
  String get personNoImg => 'Nessuna immagine';

  @override
  String get personSeries => 'Serie';

  @override
  String get personMovie => 'Film';

  @override
  String get playerSettings => 'Impostazioni';

  @override
  String get playerQuality => 'Sorgente';

  @override
  String get playerAudio => 'Audio';

  @override
  String get playerSelectQuality => 'Seleziona Sorgente';

  @override
  String get playerSelectAudio => 'Seleziona Traccia Audio';

  @override
  String get playerResolving => 'Risoluzione stream con Real-Debrid...';

  @override
  String get playerResolvingYoutube => 'Caricamento video YouTube...';

  @override
  String playerErrorResolving(Object error) {
    return 'Errore nella risoluzione dello stream:\n$error';
  }

  @override
  String playerErrorResolvingYoutube(Object error) {
    return 'Errore nel caricamento del video YouTube:\n$error';
  }

  @override
  String get playerNoAudioFound => 'Nessuna traccia audio trovata';

  @override
  String get playerFiles => 'File';

  @override
  String get playerSelectFile => 'Seleziona File';

  @override
  String get playerSubtitles => 'Sottotitoli';

  @override
  String get playerSelectSubtitle => 'Seleziona Sottotitoli';

  @override
  String get commonGoBack => 'Indietro';

  @override
  String get settingsTitle => 'Impostazioni';

  @override
  String get settingsIdentity => 'Identità e Accesso';

  @override
  String get settingsIdentityDesc =>
      'Gestisci i tuoi dati personali e le preferenze di accesso.';

  @override
  String get settingsCustomization => 'Personalizzazione App';

  @override
  String get settingsCustomizationDesc =>
      'Personalizza la tua esperienza di visione e l\'aspetto dell\'app.';

  @override
  String get settingsIntegrations => 'Integrazioni';

  @override
  String get settingsIntegrationsDesc =>
      'Collega servizi di terze parti per migliorare la tua esperienza.';

  @override
  String get settingsData => 'Dati e Archiviazione';

  @override
  String get settingsDataDesc => 'Gestisci i tuoi dati locali e la cache.';

  @override
  String get settingsImport => 'Importa ed Esporta';

  @override
  String get settingsImportDesc =>
      'Trasferisci i tuoi dati da e verso altri servizi.';

  @override
  String get settingsProvidersTitle => 'Provider Streaming';

  @override
  String get settingsProvidersDesc =>
      'Gestisci e riordina le tue sorgenti di contenuto.';

  @override
  String get settingsProvidersReorder =>
      'Tieni premuto e trascina per riordinare i provider.';

  @override
  String get settingsDisplayName => 'Nome Visualizzato';

  @override
  String get settingsDisplayNameDesc => 'Il tuo nome visualizzato pubblico.';

  @override
  String get settingsEnterName => 'Inserisci il tuo nome';

  @override
  String get settingsEnableRealDebrid => 'Abilita Real-Debrid';

  @override
  String get settingsEnableRealDebridDesc =>
      'Abilita lo streaming ad alta velocità tramite Real-Debrid.';

  @override
  String get settingsRealDebridKey => 'Chiave API Real-Debrid';

  @override
  String get settingsMediafusionUrl => 'URL Mediafusion';

  @override
  String get settingsMediafusionUrlDesc =>
      'URL per il provider Mediafusion (si trova nella configurazione del manifest).';

  @override
  String get settingsMediafusionHint => 'https://.../manifest.json';

  @override
  String get settingsMediafusionInvalidFormat =>
      'Formato URL non valido. Deve iniziare con http:// o https://';

  @override
  String get settingsMediafusionUnreachable =>
      'Impossibile raggiungere il server Mediafusion. Controlla la connessione o l\'URL.';

  @override
  String get settingsMediafusionInvalidManifest =>
      'L\'URL non punta a un manifest Stremio valido.';

  @override
  String get settingsLanguage => 'Lingua';

  @override
  String get settingsAppLanguage => 'Lingua App';

  @override
  String get settingsAppLanguageDesc => 'Cambia la lingua dell\'interfaccia.';

  @override
  String get settingsAudioLanguage => 'Lingua Audio';

  @override
  String get settingsAudioLanguageDesc =>
      'Lingua audio preferita per la riproduzione.';

  @override
  String get settingsEnglish => 'Inglese';

  @override
  String get settingsItalian => 'Italiano';

  @override
  String get settingsPlayer => 'Player';

  @override
  String get settingsPrimaryColor => 'Colore Primario';

  @override
  String get settingsPrimaryColorDesc => 'Colore principale del player.';

  @override
  String get settingsSecondaryColor => 'Colore Secondario';

  @override
  String get settingsSecondaryColorDesc => 'Colore secondario del player.';

  @override
  String get settingsOther => 'Altro';

  @override
  String get settingsShowDebugPanel => 'Mostra Pannello Debug';

  @override
  String get settingsShowDebugPanelDesc =>
      'Visualizza i dettagli tecnici in sovrimpressione.';

  @override
  String get settingsSmartSearch => 'Filtro Ricerca Intelligente';

  @override
  String get settingsSmartSearchDesc =>
      'Filtra i risultati di ricerca in modo intelligente.';

  @override
  String get settingsTotalDocSize => 'Dimensione Totale Documenti';

  @override
  String get settingsTotalDocSizeDesc =>
      'Dimensione totale di tutti i dati memorizzati.';

  @override
  String get settingsUserProfile => 'Libreria Utente';

  @override
  String get settingsWatchedMovies => 'Film Guardati';

  @override
  String get settingsWatchedSeries => 'Serie Guardate';

  @override
  String get settingsLists => 'Liste';

  @override
  String get settingsAggregatedStats => 'Statistiche Aggregate';

  @override
  String get settingsSave => 'Salva';

  @override
  String get settingsSaved => 'Salvato';

  @override
  String get settingsBack => 'Torna alle Impostazioni';

  @override
  String get settingsLogout => 'Esci';

  @override
  String get settingsProfile => 'Libreria';

  @override
  String get profileOverview => 'PANORAMICA';

  @override
  String get profileCollections => 'COLLEZIONI';

  @override
  String get profileActivity => 'ATTIVITÀ';

  @override
  String get profileActivityComingSoon => 'Attività in arrivo';

  @override
  String get profileUserDashboard => 'Libreria Utente';

  @override
  String get profileErrorLoading => 'Errore nel caricamento della libreria';

  @override
  String profileMemberSince(Object year) {
    return 'Membro dal $year';
  }

  @override
  String get navLiveTV => 'TV in Diretta';

  @override
  String get liveTvTitle => 'TV in Diretta';

  @override
  String get liveTvSelectChannel =>
      'Seleziona un canale per iniziare a guardare';

  @override
  String get liveTvNow => 'ORA';

  @override
  String get liveTvNext => 'DOPO';

  @override
  String get liveTvLive => 'IN DIRETTA';

  @override
  String get liveTvNoEpg => 'Nessun dato programma disponibile';

  @override
  String get liveTvLoading => 'Caricamento canali...';

  @override
  String get liveTvError => 'Errore nel caricamento dei canali';

  @override
  String get liveTvAllChannels => 'Tutti';

  @override
  String get liveTvHd => 'HD';

  @override
  String get liveTvNoChannels => 'Nessun canale trovato';

  @override
  String get settingsLiveTvRegion => 'Regione Live TV';

  @override
  String get settingsLiveTvRegionDesc =>
      'Seleziona la tua regione per i canali locali.';

  @override
  String get settingsNone => 'Nessuna';

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
  String get agendaThisWeek => 'Questa settimana';

  @override
  String get agendaNextWeek => 'Settimana prossima';

  @override
  String get agendaLater => 'In seguito';

  @override
  String get agendaMovie => 'Film';

  @override
  String get agendaSeries => 'Serie';

  @override
  String get agendaRecentlyReleased => 'Rilasciati di recente';

  @override
  String get agendaTbd => 'TBD / Prossimamente';

  @override
  String get agendaTbdLabel => 'TBD';

  @override
  String get updateAvailable => 'Aggiornamento disponibile';

  @override
  String get updateDialogTitle => 'Nuova versione disponibile';

  @override
  String get updateDialogMessage =>
      'Una nuova versione di Cinemuse è disponibile. Vuoi aggiornare ora?';

  @override
  String get updateNow => 'Aggiorna ora';

  @override
  String get later => 'Più tardi';

  @override
  String downloadingUpdate(Object progress) {
    return 'Download aggiornamento $progress%';
  }

  @override
  String get updateFailed => 'Aggiornamento fallito. Riprova più tardi.';
}
