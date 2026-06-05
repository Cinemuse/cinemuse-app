import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:cinemuse_app/features/home/application/sport_schedule_scraper.dart';

void main() {
  group('SportScheduleScraper', () {
    late SportScheduleScraper scraper;
    late Dio dio;

    setUp(() {
      dio = Dio();
      scraper = SportScheduleScraper(dio);
    });

    test(
      'parseHtml correctly extracts events from Virgilio HTML structure with dateTime and translationKeys',
      () {
        const sampleHtml = '''
      <html>
        <body>
          <div class="entry-content">
            <h2>Oggi – 17 maggio 2026 – Le partite e gli eventi sportivi in tv e streaming</h2>
            <table>
              <tbody>
                <tr>
                  <td>12:30</td>
                  <td><strong>Ciclismo</strong>, Giro d’Italia – 9a tappa</td>
                  <td>Eurosport, Rai 2</td>
                </tr>
                <tr>
                  <td>15:00</td>
                  <td><strong>Calcio</strong>: Serie A: Inter-Verona</td>
                  <td>Dazn</td>
                </tr>
              </tbody>
            </table>
            <h2>Domani – 18 maggio 2026 – Le partite</h2>
            <table>
              <tbody>
                <tr>
                  <td>20:00</td>
                  <td><strong>Basket</strong>, Serie A: Brescia-Trieste</td>
                  <td>Sky Sport Basket</td>
                </tr>
              </tbody>
            </table>
          </div>
        </body>
      </html>
      ''';

        final events = scraper.parseHtml(sampleHtml);

        expect(events.length, 3);

        // Verify the first event
        expect(events[0].dateTime, DateTime(2026, 5, 17, 12, 30));
        expect(events[0].sportName, 'Ciclismo');
        expect(events[0].sportTranslationKey, 'sport_cycling');
        expect(events[0].description, 'Giro d’Italia – 9a tappa');
        expect(events[0].channels, ['Eurosport', 'Rai 2']);

        // Verify the second event
        expect(events[1].dateTime, DateTime(2026, 5, 17, 15, 0));
        expect(events[1].sportName, 'Calcio');
        expect(events[1].sportTranslationKey, 'sport_football');
        expect(events[1].description, 'Serie A: Inter-Verona');
        expect(events[1].channels, ['Dazn']);

        // Verify the third event
        expect(events[2].dateTime, DateTime(2026, 5, 18, 20, 0));
        expect(events[2].sportName, 'Basket');
        expect(events[2].sportTranslationKey, 'sport_basketball');
        expect(events[2].description, 'Serie A: Brescia-Trieste');
        expect(events[2].channels, ['Sky Sport Basket']);
      },
    );

    test('parseHtml handles malformed or empty content gracefully', () {
      const emptyHtml = '<html><body></body></html>';
      final eventsEmpty = scraper.parseHtml(emptyHtml);
      expect(eventsEmpty, isEmpty);

      const missingTableHtml = '''
        <div class="entry-content">
          <h2>Oggi – 17 maggio 2026 – Le partite</h2>
        </div>
      ''';
      final eventsMissing = scraper.parseHtml(missingTableHtml);
      expect(eventsMissing, isEmpty);
    });
  });
}
