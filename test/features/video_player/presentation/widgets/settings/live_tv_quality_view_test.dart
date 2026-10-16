import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit_video/media_kit_video.dart' as mkv;
import 'package:mocktail/mocktail.dart';
import 'package:cinemuse_app/features/live_tv/domain/stream_link.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/settings/domain/user_settings.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/settings/live_tv_quality_view.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

import '../../../../../helpers/focus_helpers.dart';

class _MockVideoController extends Mock implements mkv.VideoController {}

class _FakeSettingsNotifier extends SettingsNotifier {
  _FakeSettingsNotifier(this.initial);

  final UserSettings initial;

  @override
  UserSettings build() => initial;
}

void main() {
  testWidgets('focus starts on the current quality, not on 4K (REV-171)', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            () => _FakeSettingsNotifier(
              const UserSettings(liveTvQuality: StreamQuality.fhd),
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: LiveTvQualityView(
              onBack: () {},
              // No channel links: only the preferred-quality list shows.
              state: CinemaPlayerState(
                controller: _MockVideoController(),
                availableStreams: const [],
                currentStream: null,
                title: 'Rai 1',
              ),
              params: const PlayerParams('livetv_session', 'livetv'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(isFocused(find.text('FHD')), isTrue);
    expect(isFocused(find.text('4K')), isFalse);
  });
}
