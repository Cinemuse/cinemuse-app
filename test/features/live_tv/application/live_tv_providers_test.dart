import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/application/custom_epg_url_notifier.dart';
import 'package:cinemuse_app/features/live_tv/data/live_tv_repository.dart';
import 'package:cinemuse_app/features/live_tv/domain/epg_program.dart';

/// Records which EPG URLs were requested; never calls a server.
class _RecordingRepository extends LiveTvRepository {
  _RecordingRepository() : super(Dio());

  final requestedUrls = <String?>[];

  @override
  Future<Map<String, List<EpgProgram>>> fetchEpg({
    String? url,
    bool forceRefresh = false,
  }) async {
    requestedUrls.add(url);
    return {};
  }
}

Future<void> _settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingRepository repo;
  late ProviderContainer container;

  void createContainer() {
    repo = _RecordingRepository();
    container = ProviderContainer(
      overrides: [liveTvRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    container.listen(epgDataProvider, (previous, next) {});
  }

  test('downloads only the saved custom EPG URL at start (REV-115)', () async {
    SharedPreferences.setMockInitialValues({
      'live_tv_custom_epg_url': 'https://example.com/custom.xml',
    });
    createContainer();

    await container.read(epgDataProvider.future);
    await _settle();

    expect(repo.requestedUrls, ['https://example.com/custom.xml']);
  });

  test('downloads the default EPG once when no URL is saved', () async {
    SharedPreferences.setMockInitialValues({});
    createContainer();

    await container.read(epgDataProvider.future);
    await _settle();

    expect(repo.requestedUrls, hasLength(1));
    expect(
      container.read(activeEpgUrlProvider),
      LiveTvRepository.defaultEpgUrl,
    );
  });

  test('changing the URL loads the guide again with the new URL', () async {
    SharedPreferences.setMockInitialValues({});
    createContainer();
    await container.read(epgDataProvider.future);

    await container
        .read(customEpgUrlProvider.notifier)
        .setUrl(' https://example.com/new.xml ');
    await container.read(epgDataProvider.future);
    await _settle();

    expect(repo.requestedUrls.last, 'https://example.com/new.xml');
    expect(repo.requestedUrls, hasLength(2));
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('live_tv_custom_epg_url'),
      'https://example.com/new.xml',
    );
  });
}
