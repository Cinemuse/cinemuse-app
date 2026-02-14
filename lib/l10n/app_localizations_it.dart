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
  String seasonLabel(Object number) {
    return 'Stagione $number';
  }

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
}
