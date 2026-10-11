import 'package:cinemuse_app/core/data/database.dart';
import 'package:cinemuse_app/features/streaming/anime/anime_mapping_sync_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockDio extends Mock implements Dio {}

class _MockAppDatabase extends Mock implements AppDatabase {}

const _lastSyncKey = 'last_anime_mapping_sync';

const _mappingsFile = '''
{
  "16498": {"anidb_id": 9541, "tmdb_show_id": 1429,
            "tmdb_mappings": {"s1": "e1-e25"}},
  "999": {"anidb_id": 1},
  "not-a-number": {"tmdb_show_id": 1}
}
''';

void main() {
  late _MockDio dio;
  late _MockAppDatabase db;
  late AnimeMappingSyncService service;

  setUpAll(() {
    registerFallbackValue(Options());
    registerFallbackValue(<AnimeExternalMappingsCompanion>[]);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    dio = _MockDio();
    db = _MockAppDatabase();
    service = AnimeMappingSyncService(dio, db);
    when(() => db.getAnimeExternalMappingsCount()).thenAnswer((_) async => 0);
    when(() => db.replaceAnimeExternalMappings(any())).thenAnswer((_) async {});
  });

  void answerWith(String body) {
    when(
      () => dio.get<String>(any(), options: any(named: 'options')),
    ).thenAnswer(
      (inv) async => Response<String>(
        requestOptions: RequestOptions(path: inv.positionalArguments.first),
        statusCode: 200,
        data: body,
      ),
    );
  }

  test('a failed sync does not save the sync time (REV-34)', () async {
    when(
      () => dio.get<String>(any(), options: any(named: 'options')),
    ).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/mappings.json'),
        type: DioExceptionType.connectionError,
      ),
    );

    await service.checkAndSync();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_lastSyncKey), isNull);
  });

  test('a good sync stores the rows and saves the sync time', () async {
    answerWith(_mappingsFile);

    await service.checkAndSync();

    final rows =
        verify(
              () => db.replaceAnimeExternalMappings(captureAny()),
            ).captured.single
            as List<AnimeExternalMappingsCompanion>;
    expect(rows.map((r) => r.anilistId.value), [16498]);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_lastSyncKey), isNotNull);
  });

  test('parseMappings keeps only rows with a TMDB or TVDB id', () {
    final rows = AnimeMappingSyncService.parseMappings(_mappingsFile);

    expect(rows, hasLength(1));
    expect(rows.single.tmdbShowId.value, 1429);
    expect(rows.single.mappingsData.value, '{"s1":"e1-e25"}');
  });
}
