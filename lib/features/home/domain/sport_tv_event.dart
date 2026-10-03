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

  @override
  String toString() {
    return 'SportTvEvent(dateTime: $dateTime, sportName: $sportName, description: $description, channels: $channels)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SportTvEvent) return false;

    if (dateTime != other.dateTime) return false;
    if (sportName != other.sportName) return false;
    if (description != other.description) return false;

    if (channels.length != other.channels.length) return false;
    for (int i = 0; i < channels.length; i++) {
      if (channels[i] != other.channels[i]) return false;
    }

    return true;
  }

  @override
  int get hashCode {
    return dateTime.hashCode ^
        sportName.hashCode ^
        description.hashCode ^
        channels.hashCode;
  }
}
