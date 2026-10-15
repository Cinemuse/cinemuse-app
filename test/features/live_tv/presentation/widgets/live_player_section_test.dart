import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit_video/media_kit_video.dart' as mkv;
import 'package:mocktail/mocktail.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/live_player_section.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

class _MockVideoController extends Mock implements mkv.VideoController {}

void main() {
  for (final (locale, title, hint) in [
    (
      const Locale('en'),
      'Stream unavailable',
      'This channel may be offline or not available in your country.',
    ),
    (
      const Locale('it'),
      'Stream non disponibile',
      'Questo canale potrebbe essere offline o non disponibile nel tuo paese.',
    ),
  ]) {
    testWidgets('a failed channel says "$title" with a hint, no spinner '
        '(REV-139)', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: LivePlayerSection(
                channel: const Channel(lcn: 1, name: 'Rai 1', logo: ''),
                // Failed before any stream was picked.
                playerState: AsyncData(
                  CinemaPlayerState(
                    controller: _MockVideoController(),
                    availableStreams: const [],
                    currentStream: null,
                    title: 'Rai 1',
                    error: 'Failed to open http://example.com/live.m3u8',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(title), findsOneWidget);
      expect(find.text(hint), findsOneWidget);
      expect(find.textContaining('Failed to open'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  }
}
