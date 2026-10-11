class SportTvEvent {
  final DateTime? dateTime;
  final String sportName;
  final String description;
  final List<String> channels;

  SportTvEvent({
    required this.dateTime,
    required this.sportName,
    required this.description,
    required this.channels,
  });

  static const _sportRules = <String, List<String>>{
    'sport_football': ['calcio'],
    'sport_basketball': ['basket', 'pallacanestro'],
    'sport_motorcycling': ['motociclismo', 'motogp', 'moto gp'],
    'sport_volleyball': ['pallavolo'],
    'sport_athletics': ['atletica'],
    'sport_tennis': ['tennis'],
    'sport_cycling': ['ciclismo'],
    'sport_rugby': ['rugby'],
    'sport_f1': ['formula 1', 'f1', 'automobilismo'],
  };

  /// Translates Italian sport names into predefined localization keys.
  String get sportTranslationKey {
    final clean = sportName.toLowerCase().trim();

    return _sportRules.entries
        .firstWhere(
          (entry) => entry.value.any(clean.contains),
          orElse: () => const MapEntry('sport_generic', []),
        )
        .key;
  }
}
