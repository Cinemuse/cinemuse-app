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
  String get commonUndo => 'Annulla';

  @override
  String get commonFeatured => 'IN PRIMA PIANO';

  @override
  String get commonUnexpectedError => 'Si è verificato un errore inaspettato';

  @override
  String get commonOk => 'OK';

  @override
  String get commonUnknown => 'Sconosciuto';

  @override
  String get filterMax => 'Max';

  @override
  String get searchPlaceholder => 'Cerca film, serie, persone...';

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
  String get searchYearRange => 'Intervallo Anni';

  @override
  String get searchVoteCount => 'Conteggio Voti';

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
  String get searchMatchAny => 'Corrispondenza Qualsiasi';

  @override
  String get searchMatchAll => 'Corrispondenza Tutte';

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
  String get detailsDeleteListTitle => 'Elimina Lista?';

  @override
  String detailsDeleteListConfirm(Object name) {
    return 'Sei sicuro di voler eliminare \'$name\'?';
  }

  @override
  String get detailsCollectionsTitle => 'Collezioni';

  @override
  String get detailsCollectionsDesc => 'Le tue liste personalizzate a tema.';

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
  String detailsMarkPreviousDesc(Object count, Object episode) {
    return 'Hai segnato l\'Episodio $episode. Vuoi segnare anche i $count episodi precedenti non visti come visti?';
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
  String get homeTrendingNow => 'Tendenze';

  @override
  String get homePopularMovies => 'Film Popolari';

  @override
  String get homePopularSeries => 'Serie Popolari';

  @override
  String get homeContinueWatching => 'Continua a guardare';

  @override
  String homeRemovedFromContinueWatching(Object title) {
    return '$title rimosso';
  }

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
  String get authWelcomeBackDesc =>
      'Accedi per visualizzare la tua libreria e le impostazioni';

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
  String get detailsRemoveAll => 'Rimuovi Tutto';

  @override
  String get detailsBudget => 'Budget';

  @override
  String get detailsRevenue => 'Incassi';

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
      'Segna come Visto (Pressione prolungata per la data)';

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
  String get playerSettings => 'Impostazioni';

  @override
  String get playerQuality => 'Qualità';

  @override
  String get playerAudio => 'Audio';

  @override
  String get playerSelectQuality => 'Seleziona Qualità';

  @override
  String get playerSubtitleSize => 'Dimensione Sottotitoli';

  @override
  String get playerSubtitleDelay => 'Sincronizzazione';

  @override
  String get playerSubtitleDelayReset => 'Ripristina';

  @override
  String get playerSelectAudio => 'Seleziona Traccia Audio';

  @override
  String get playerResolving => 'Risoluzione stream in corso...';

  @override
  String get playerResolvingYoutube => 'Caricamento video YouTube...';

  @override
  String playerErrorResolving(Object error) {
    return 'Errore risoluzione stream:\n$error';
  }

  @override
  String playerErrorResolvingYoutube(Object error) {
    return 'Errore caricamento video YouTube:\n$error';
  }

  @override
  String get playerNoAudioFound => 'Nessuna traccia audio trovata';

  @override
  String get playerNoQualityOptions =>
      'Nessuna opzione di qualità disponibile per questo stream.';

  @override
  String get streamingErrorNoProviders =>
      'Nessun addon di streaming abilitato. Controlla le impostazioni.';

  @override
  String streamingErrorCapabilityMissing(Object category) {
    return 'Nessun addon abilitato supporta $category. Controlla le impostazioni.';
  }

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
  String get streamingErrorImdbId => 'Impossibile risolvere l\'ID IMDB.';

  @override
  String streamingErrorProviderSearchFailed(Object providerName) {
    return 'Ricerca fallita per l\'addon: $providerName.';
  }

  @override
  String get playerFiles => 'File';

  @override
  String get playerSelectFile => 'Seleziona File';

  @override
  String get playerSubtitles => 'Sottotitoli';

  @override
  String get playerSelectSubtitle => 'Seleziona Sottotitolo';

  @override
  String get commonGoBack => 'Torna Indietro';

  @override
  String get playerNextEpisode => 'Prossimo Episodio';

  @override
  String get playerSubtitleAppearance => 'Aspetto Sottotitoli';

  @override
  String get playerAppearanceFontSize => 'Dimensione Carattere';

  @override
  String get playerAppearanceTextColor => 'Colore Testo';

  @override
  String get playerAppearanceBackground => 'Opacità Sfondo';

  @override
  String get playerAppearanceBottomPadding => 'Margine Inferiore';

  @override
  String get playerAppearanceSaveDefault => 'Salva come Predefinito';

  @override
  String get playerAppearanceReset => 'Ripristina Predefiniti';

  @override
  String get playerAppearanceSampleText => 'Esempio Testo Sottotitoli';

  @override
  String get settingsTitle => 'Impostazioni';

  @override
  String get settingsIdentity => 'Identità e Accesso';

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
      'Gestisci gli addon di Stremio e le integrazioni native.';

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
  String get settingsCopiedToClipboard => 'URL copiato negli appunti';

  @override
  String get settingsCopy => 'Copia URL';

  @override
  String get settingsRemove => 'Rimuovi';

  @override
  String get settingsNativeIntegrations => 'Provider Nativi';

  @override
  String get settingsEnableAnimeTosho => 'Abilita AnimeTosho';

  @override
  String get settingsEnableVixSrc => 'Abilita VixSrc';

  @override
  String get settingsEnableAnimeToshoWarning =>
      'Richiede un\'integrazione Real-Debrid attiva';

  @override
  String get settingsDebridServices => 'Servizi Debrid';

  @override
  String get settingsRealDebridTitle => 'Real-Debrid (Nativo)';

  @override
  String get settingsRealDebridKey => 'Chiave API Real-Debrid';

  @override
  String get settingsRealDebridKeyDesc =>
      'Usato per sorgenti native come AnimeTosho.';

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
      'Nasconde automaticamente CAM, Screener, versioni 3D o link spazzatura dai risultati degli addon.';

  @override
  String get settingsTotalDocSize => 'Dimensione Totale Documenti';

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
  String get settingsAggregatedStats => 'Statistiche Aggregate';

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
  String get profileActivity => 'ATTIVITÀ';

  @override
  String get profileActivityComingSoon => 'Attività disponibile a breve';

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
  String get liveTvNow => 'ORA';

  @override
  String get liveTvNext => 'DOPO';

  @override
  String get liveTvLive => 'LIVE';

  @override
  String get liveTvNoEpg => 'Nessuna informazione sul programma';

  @override
  String get liveTvLoading => 'Caricamento canali...';

  @override
  String get liveTvError => 'Errore caricamento canali';

  @override
  String get liveTvAllChannels => 'Tutti';

  @override
  String get liveTvHd => 'HD';

  @override
  String get liveTvNoChannels => 'Nessun canale trovato';

  @override
  String get liveTvSearchPlaceholder => 'Cerca canali...';

  @override
  String get settingsLiveTvRegion => 'Regione Live TV';

  @override
  String get settingsLiveTvRegionDesc =>
      'Seleziona la tua regione per i canali regionali.';

  @override
  String get settingsLiveTv => 'Live TV';

  @override
  String get settingsLiveTvBufferSize => 'Dimensione Buffer DVR';

  @override
  String get settingsLiveTvBufferSizeDesc =>
      'Quantità massima di cronologia (in MB) da mantenere in memoria/disco per il canale corrente.';

  @override
  String get settingsLiveTvDiskCache => 'Abilita Cache su Disco';

  @override
  String get settingsLiveTvDiskCacheDesc =>
      'Usa lo spazio di archiviazione locale invece della RAM per il buffer DVR. Consigliato per buffer di grandi dimensioni.';

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
  String get agendaLater => 'In Futuro';

  @override
  String get agendaMovie => 'Film';

  @override
  String get agendaSeries => 'Serie TV';

  @override
  String get agendaRecentlyReleased => 'Usciti di Recente';

  @override
  String get agendaTbd => 'TBD / In Arrivo';

  @override
  String get agendaTbdLabel => 'TBD';

  @override
  String get updateAvailable => 'Aggiornamento Disponibile';

  @override
  String get updateDialogTitle => 'Nuova versione disponibile';

  @override
  String get updateDialogMessage =>
      'Una nuova versione di Cinemuse è disponibile. Vuoi aggiornare ora?';

  @override
  String get updateNow => 'Aggiorna Ora';

  @override
  String get later => 'Dopo';

  @override
  String downloadingUpdate(Object progress) {
    return 'Scaricamento aggiornamento $progress%';
  }

  @override
  String get updateReadyToInstall =>
      'Aggiornamento pronto per l\'installazione';

  @override
  String get updateFailed => 'Aggiornamento fallito. Riprova più tardi.';

  @override
  String updateNoCompatibleApk(Object abi) {
    return 'Nessun aggiornamento compatibile trovato per l\'architettura del tuo dispositivo ($abi)';
  }

  @override
  String get updateUpToDate => 'L\'app è aggiornata';

  @override
  String get updateChangelog => 'Novità';

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
  String get menuMoreOptions => 'Altre Opzioni';

  @override
  String get menuAddToWatchlist => 'Aggiungi alla Watchlist';

  @override
  String get menuRemoveFromWatchlist => 'Rimuovi dalla Watchlist';

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
  String get menuPlay => 'Riproduci';

  @override
  String get menuRemoveFromContinueWatching => 'Rimuovi da Continua a Guardare';
}
