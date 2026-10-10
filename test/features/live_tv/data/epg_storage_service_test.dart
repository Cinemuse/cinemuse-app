import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/features/live_tv/data/epg_parser.dart';
import 'package:cinemuse_app/features/live_tv/data/epg_storage_service.dart';

const _url = 'https://example.com/epg.xml';

const _xml = '''<tv>
  <programme start="20261010120000 +0000" stop="20261010130000 +0000" channel="Rai1.it">
    <title>TG1</title>
  </programme>
</tv>''';

void main() {
  late Directory dir;
  late EpgStorageService storage;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('epg_cache_test');
    storage = EpgStorageService(cacheDirectory: () async => dir);
  });

  tearDown(() => dir.delete(recursive: true));

  Future<Map<String, dynamic>> readSavedData() async {
    final file = File('${dir.path}/${EpgStorageService.cacheFileName}');
    final saved = json.decode(await file.readAsString()) as Map;
    return saved['data'] as Map<String, dynamic>;
  }

  test('saves each program list once, not once per alias (REV-119)', () async {
    final epg = EpgParser.parseXmltv(_xml);
    // The parser adds two aliases that point to the same list.
    expect(epg.keys, ['Rai1.it', 'rai1.it', 'rai1']);

    await storage.saveCachedEpg(_url, epg);

    expect((await readSavedData()).keys, ['Rai1.it']);
  });

  test('rebuilds the aliases on load, sharing one list', () async {
    await storage.saveCachedEpg(_url, EpgParser.parseXmltv(_xml));

    final loaded = await storage.loadCachedEpg(expectedUrl: _url);

    expect(loaded!.keys, ['Rai1.it', 'rai1.it', 'rai1']);
    expect(loaded['rai1']!.single.name, 'TG1');
    expect(identical(loaded['rai1'], loaded['Rai1.it']), isTrue);
  });

  test('ignores a cache saved for another URL', () async {
    await storage.saveCachedEpg(_url, EpgParser.parseXmltv(_xml));

    final loaded = await storage.loadCachedEpg(
      expectedUrl: 'https://example.com/other.xml',
    );

    expect(loaded, isNull);
  });

  test('returns null when there is no cache file', () async {
    expect(await storage.loadCachedEpg(expectedUrl: _url), isNull);
  });
}
