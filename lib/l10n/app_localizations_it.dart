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
  String get navLibrary => 'Profilo';

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
  String get detailsReviewsAll => 'Leggi tutte le recensioni';

  @override
  String get detailsFinances => 'Finanze';

  @override
  String get detailsProductionDNA => 'DNA di Produzione';

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
  String get detailsRevenue => 'Incasso';

  @override
  String get detailsExternalLinks => 'Link Esterni';

  @override
  String seasonLabel(Object number) {
    return 'Stagione $number';
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
  String get playerSettings => 'Impostazioni';

  @override
  String get playerQuality => 'Qualità';

  @override
  String get playerAudio => 'Audio';

  @override
  String get playerSelectQuality => 'Seleziona Qualità';

  @override
  String get playerSelectAudio => 'Seleziona Traccia Audio';

  @override
  String get playerResolving => 'Risoluzione stream con Real-Debrid...';

  @override
  String playerErrorResolving(Object error) {
    return 'Errore nella risoluzione dello stream:\n$error';
  }

  @override
  String get playerNoAudioFound => 'Nessuna traccia audio trovata';

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
  String get settingsUserProfile => 'Profilo Utente';

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
  String get settingsProfile => 'Profilo';
}
