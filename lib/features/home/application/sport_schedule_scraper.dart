import 'package:dio/dio.dart';
import 'package:html/parser.dart' show parse;

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

  /// Translates Italian sport names into predefined localization keys.
  String get sportTranslationKey {
    final clean = sportName.toLowerCase().trim();
    if (clean.contains('calcio')) return 'sport_football';
    if (clean.contains('basket') || clean.contains('pallacanestro')) {
      return 'sport_basketball';
    }
    if (clean.contains('motociclismo') ||
        clean.contains('motogp') ||
        clean.contains('moto gp')) {
      return 'sport_motorcycling';
    }
    if (clean.contains('pallavolo')) return 'sport_volleyball';
    if (clean.contains('atletica')) return 'sport_athletics';
    if (clean.contains('tennis')) return 'sport_tennis';
    if (clean.contains('ciclismo')) return 'sport_cycling';
    if (clean.contains('rugby')) return 'sport_rugby';
    if (clean.contains('formula 1') ||
        clean.contains('f1') ||
        clean.contains('automobilismo')) {
      return 'sport_f1';
    }
    return 'sport_generic';
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

class SportScheduleScraper {
  final Dio _dio;

  SportScheduleScraper(this._dio);

  /// Fetches the live TV guide schedule from Virgilio Sport.
  Future<List<SportTvEvent>> fetchSchedule() async {
    try {
      final response = await _dio.get('https://sport.virgilio.it/guida-tv/');
      return parseHtml(response.data.toString());
    } catch (e) {
      throw Exception('Failed to fetch sports schedule: $e');
    }
  }

  /// Parses the raw HTML string into a list of SportTvEvent objects.
  List<SportTvEvent> parseHtml(String html) {
    final doc = parse(html);
    final entryContent = doc.querySelector('.entry-content');
    if (entryContent == null) return [];

    final List<SportTvEvent> events = [];
    String? currentDate;

    for (var el in entryContent.children) {
      if ((el.localName == 'h2' || el.localName == 'h3') &&
          el.text.contains('–')) {
        currentDate = el.text.trim();
        final parts = currentDate.split('–');
        if (parts.length >= 2) {
          currentDate = parts[1].trim();
        }
      } else if (el.localName == 'table') {
        for (var row in el.querySelectorAll('tr')) {
          final cells = row.querySelectorAll('td');
          if (cells.isNotEmpty) {
            final time = cells.isNotEmpty ? cells[0].text.trim() : '';
            final descRaw = cells.length > 1
                ? cells[1].text
                      .trim()
                      .replaceAll('\n', ' ')
                      .replaceAll(RegExp(r'\s+'), ' ')
                : '';
            final channelsRaw = cells.length > 2
                ? cells[2].text
                      .trim()
                      .replaceAll('\n', ' ')
                      .replaceAll(RegExp(r'\s+'), ' ')
                : '';

            final sportName = cells.length > 1
                ? (cells[1].querySelector('strong')?.text.trim() ?? '')
                : '';

            String description = descRaw;
            if (sportName.isNotEmpty && description.startsWith(sportName)) {
              description = description.substring(sportName.length).trim();
              if (description.startsWith(',')) {
                description = description.substring(1).trim();
              }
              if (description.startsWith(':')) {
                description = description.substring(1).trim();
              }
            }

            final channels = channelsRaw
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();

            final parsedDateTime = _tryParseDateTime(currentDate ?? '', time);

            events.add(
              SportTvEvent(
                dateTime: parsedDateTime,
                sportName: sportName,
                description: description,
                channels: channels,
              ),
            );
          }
        }
      }
    }
    return events;
  }

  /// Tries to parse date and time strings into a standard Dart DateTime object.
  DateTime? _tryParseDateTime(String dateStr, String timeStr) {
    try {
      final dateParts = dateStr.trim().split(' ');
      if (dateParts.length < 3) return null;

      final day = int.tryParse(dateParts[0]) ?? 1;
      final monthStr = dateParts[1].toLowerCase();
      final year = int.tryParse(dateParts[2]) ?? DateTime.now().year;

      int month = 1;
      switch (monthStr) {
        case 'gennaio':
          month = 1;
          break;
        case 'febbraio':
          month = 2;
          break;
        case 'marzo':
          month = 3;
          break;
        case 'aprile':
          month = 4;
          break;
        case 'maggio':
          month = 5;
          break;
        case 'giugno':
          month = 6;
          break;
        case 'luglio':
          month = 7;
          break;
        case 'agosto':
          month = 8;
          break;
        case 'settembre':
          month = 9;
          break;
        case 'ottobre':
          month = 10;
          break;
        case 'novembre':
          month = 11;
          break;
        case 'dicembre':
          month = 12;
          break;
      }

      final timeParts = timeStr.trim().split(':');
      final hour = timeParts.isNotEmpty ? (int.tryParse(timeParts[0]) ?? 0) : 0;
      final minute = timeParts.length > 1
          ? (int.tryParse(timeParts[1]) ?? 0)
          : 0;

      return DateTime(year, month, day, hour, minute);
    } catch (_) {
      return null;
    }
  }
}
