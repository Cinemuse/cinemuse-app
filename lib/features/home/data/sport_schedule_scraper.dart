import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:cinemuse_app/features/home/domain/sport_tv_event.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' show parse;

class SportScheduleScraper {
  final Dio _dio;

  SportScheduleScraper(this._dio);

  /// Fetches the live TV guide schedule from Virgilio Sport.
  Future<List<SportTvEvent>> fetchSchedule() async {
    try {
      final response = await _dio.get('https://sport.virgilio.it/guida-tv/');
      return parseHtml(response.data.toString());
    } catch (e, st) {
      AppLogger.warn(
        'SportScheduleScraper',
        'Failed to fetch sports schedule from Virgilio Sport',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Parses the raw HTML string into a list of SportTvEvent objects.
  List<SportTvEvent> parseHtml(String html) {
    final doc = parse(html);
    final entryContent = doc.querySelector('.entry-content');
    if (entryContent == null) return [];

    final List<SportTvEvent> events = [];
    String? currentDate;

    String cleanText(String text) =>
        text.replaceAll(RegExp(r'\s+'), ' ').trim();

    for (var el in entryContent.children) {
      if ((el.localName == 'h2' || el.localName == 'h3') &&
          el.text.contains('–')) {
        final parts = el.text.trim().split('–');
        currentDate = (parts.length >= 2 ? parts[1] : parts[0]).trim();
      } else if (el.localName == 'table') {
        for (var row in el.querySelectorAll('tr')) {
          final cells = row.querySelectorAll('td');
          if (cells.isNotEmpty) {
            final time = cells[0].text.trim();
            final descRaw = cells.length > 1 ? cleanText(cells[1].text) : '';
            final channelsRaw = cells.length > 2
                ? cleanText(cells[2].text)
                : '';
            final sportName = cells.length > 1
                ? (cells[1].querySelector('strong')?.text.trim() ?? '')
                : '';

            var description = descRaw;
            if (sportName.isNotEmpty && description.startsWith(sportName)) {
              description = description
                  .substring(sportName.length)
                  .replaceFirst(RegExp(r'^[,:\s]+'), '')
                  .trim();
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

  static const _italianMonths = <String, int>{
    'gennaio': 1,
    'febbraio': 2,
    'marzo': 3,
    'aprile': 4,
    'maggio': 5,
    'giugno': 6,
    'luglio': 7,
    'agosto': 8,
    'settembre': 9,
    'ottobre': 10,
    'novembre': 11,
    'dicembre': 12,
  };

  /// Parses "17 maggio 2026" + "12:30" into a local [DateTime], or `null`
  /// when the day, month or hour can't be read (better no date than a wrong
  /// one).
  DateTime? _tryParseDateTime(String dateStr, String timeStr) {
    final dateParts = dateStr.trim().split(' ');
    if (dateParts.length < 3) return null;

    final day = int.tryParse(dateParts[0]);
    final month = _italianMonths[dateParts[1].toLowerCase()];
    final year = int.tryParse(dateParts[2]) ?? DateTime.now().year;

    final timeParts = timeStr.trim().split(':');
    final hour = int.tryParse(timeParts[0]);
    final minute = timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0;

    if (day == null || month == null || hour == null) return null;
    return DateTime(year, month, day, hour, minute);
  }
}
