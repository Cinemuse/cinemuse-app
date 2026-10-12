import 'package:cinemuse_app/features/settings/application/local_settings_service.dart';
import 'package:cinemuse_app/features/settings/domain/subtitle_style.dart';
import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:cinemuse_app/features/video_player/application/subtitle_style_provider.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:mocktail/mocktail.dart';

class _MockVideoController extends Mock implements VideoController {}

class _FakePlayerController extends StateNotifier<AsyncValue<CinemaPlayerState>>
    implements PlayerController {
  _FakePlayerController(SubtitleStyle? custom)
    : super(
        AsyncValue.data(
          CinemaPlayerState(
            controller: _MockVideoController(),
            availableStreams: const [],
            currentStream: null,
            title: 'Test',
            customSubtitleStyle: custom,
          ),
        ),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SavedSettings extends LocalSettingsNotifier {
  @override
  LocalSettings build() =>
      const LocalSettings(subtitleStyle: SubtitleStyle(fontSize: 32));
}

// REV-170: the appearance menu showed 24 px while the user's saved size
// was on screen.
void main() {
  const params = PlayerParams('550', 'movie');

  SubtitleStyle read({SubtitleStyle? custom}) {
    final container = ProviderContainer(
      overrides: [
        localSettingsProvider.overrideWith(_SavedSettings.new),
        playerControllerProvider.overrideWith(
          (ref, params) => _FakePlayerController(custom),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container.read(effectiveSubtitleStyleProvider(params));
  }

  test('nothing changed in the player: the saved style', () {
    expect(read().fontSize, 32);
  });

  test('changed in the player: that change', () {
    expect(read(custom: const SubtitleStyle(fontSize: 40)).fontSize, 40);
  });
}
