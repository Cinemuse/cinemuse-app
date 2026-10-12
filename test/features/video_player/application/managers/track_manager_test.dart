import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/streaming/subtitles/external_subtitle.dart';
import 'package:cinemuse_app/features/streaming/subtitles/subtitle_service.dart';
import 'package:cinemuse_app/features/video_player/application/managers/track_manager.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mocktail/mocktail.dart';

class _MockPlayer extends Mock implements Player {}

class _MockPlayerStream extends Mock implements PlayerStream {}

class _FakeSettingsNotifier extends SettingsNotifier {
  @override
  UserSettings build() => const UserSettings();
}

class _FakeSubtitleService extends Fake implements SubtitleService {
  @override
  bool get hasActiveProviders => true;

  @override
  Future<List<ExternalSubtitle>> search({
    String? imdbId,
    String? tmdbId,
    int? season,
    int? episode,
    String? query,
    required String language,
  }) async => const [_subtitle];
}

const _subtitle = ExternalSubtitle(
  id: '1',
  language: 'en',
  format: 'srt',
  providerName: 'test',
  title: 'English',
);

void main() {
  // The screen opens the player without a start position; the controller
  // fills it in, so the resolved params differ from the screen's.
  const screenParams = PlayerParams('550', 'movie');
  const resolvedParams = PlayerParams('550', 'movie', startPosition: 0);

  late ProviderContainer container;
  late AutoDisposeProvider<TrackManager> managerProvider;

  setUp(() {
    final player = _MockPlayer();
    final stream = _MockPlayerStream();
    when(() => player.stream).thenReturn(stream);
    when(() => stream.tracks).thenAnswer((_) => const Stream.empty());
    when(() => player.state).thenReturn(const PlayerState());

    managerProvider = Provider.autoDispose((ref) {
      final manager = TrackManager(
        ref: ref,
        player: player,
        params: resolvedParams,
        subtitlesKey: screenParams,
      );
      ref.onDispose(manager.dispose);
      return manager;
    });

    container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(_FakeSettingsNotifier.new),
        subtitleServiceProvider.overrideWithValue(_FakeSubtitleService()),
      ],
    );
  });

  tearDown(() => container.dispose());

  test('external subtitles reach the key the screen reads (REV-142)', () async {
    container.listen(managerProvider, (_, _) {});
    await container.read(managerProvider).ensurePreferredTrack();
    await pumpEventQueue();

    final results = container.read(externalSubtitlesProvider(screenParams));
    expect(results, isA<AsyncData<List<ExternalSubtitle>>>());
    expect(results.value, [_subtitle]);
  });

  test('results are dropped when the player closes (REV-142)', () async {
    final subscription = container.listen(managerProvider, (_, _) {});
    await container.read(managerProvider).ensurePreferredTrack();
    await pumpEventQueue();

    subscription.close();
    await container.pump();

    expect(
      container.read(externalSubtitlesProvider(screenParams)),
      isA<AsyncLoading<List<ExternalSubtitle>>>(),
    );
  });
}
