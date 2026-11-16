import 'dart:async';

import 'package:cinemuse_app/core/application/locale_service.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/settings/domain/user_settings.dart';
import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/features/video_player/presentation/video_player_screen.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:cinemuse_app/l10n/app_localizations_it.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/focus_helpers.dart';
import 'package:cinemuse_app/core/application/provider_retry.dart';

class FakeSettingsNotifier extends SettingsNotifier {
  @override
  UserSettings build() => const UserSettings();
}

/// A player whose every load (Retry loads again) returns what [load] says.
class FakePlayerController extends Notifier<AsyncValue<CinemaPlayerState>>
    implements PlayerController {
  FakePlayerController(this.load);
  final AsyncValue<CinemaPlayerState> Function() load;

  @override
  AsyncValue<CinemaPlayerState> build() => load();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockVideoController extends Mock implements VideoController {}

/// A live player that stays on its loading screen and records each channel
/// it is asked to tune to.
class _OpeningLivePlayerController extends FakePlayerController {
  _OpeningLivePlayerController(this.tuned)
    : super(
        () => AsyncValue.data(
          CinemaPlayerState(
            controller: MockVideoController(),
            availableStreams: const [],
            currentStream: null,
            title: 'Rai 1',
            isResolving: true,
            isLive: true,
          ),
        ),
      );

  final List<String> tuned;

  @override
  Future<void> changeChannel(
    Channel channel, {
    bool isFailover = false,
  }) async => tuned.add(channel.name);
}

void main() {
  testWidgets('live TV: while a channel opens, Down and a typed number still '
      'change the channel', (tester) async {
    SharedPreferences.setMockInitialValues({});
    const rai1 = Channel(lcn: 1, name: 'Rai 1', logo: '');
    const rai2 = Channel(lcn: 2, name: 'Rai 2', logo: '');
    const rai3 = Channel(lcn: 3, name: 'Rai 3', logo: '');
    final tuned = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        retry: noProviderRetry,
        overrides: [
          settingsProvider.overrideWith(FakeSettingsNotifier.new),
          channelsProvider.overrideWith((ref) async => [rai1, rai2, rai3]),
          playerControllerProvider.overrideWith2(
            (_) => _OpeningLivePlayerController(tuned),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const VideoPlayerScreen(
            queryId: 'Rai 1',
            type: 'livetv',
            channel: rai1,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    tuned.clear(); // The screen opening on Rai 1.

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(tuned, ['Rai 2']);

    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.pump();
    expect(find.text('3'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(tuned, ['Rai 2', 'Rai 3']);
    await tester.pump(const Duration(seconds: 5));
  });

  // The round ← is hidden on the keys: these are the only way out.
  for (final (type, channel) in [
    ('movie', null),
    ('livetv', const Channel(lcn: 1, name: 'Rai 1', logo: '')),
  ]) {
    group('$type loading screen', () {
      Future<void> pumpOpen(WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          ProviderScope(
            retry: noProviderRetry,
            overrides: [
              settingsProvider.overrideWith(FakeSettingsNotifier.new),
              channelsProvider.overrideWith((ref) async => const <Channel>[]),
              playerControllerProvider.overrideWith2(
                (_) => _OpeningLivePlayerController([]),
              ),
            ],
            child: MaterialApp(
              navigatorKey: navigator,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Text('Page below'),
            ),
          ),
        );
        unawaited(
          navigator.currentState!.push(
            MaterialPageRoute<void>(
              builder: (_) => VideoPlayerScreen(
                queryId: 'Rai 1',
                type: type,
                channel: channel,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(VideoPlayerScreen), findsOneWidget);
      }

      Future<void> expectLeft(WidgetTester tester) async {
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(VideoPlayerScreen), findsNothing);
        expect(find.text('Page below'), findsOneWidget);
      }

      testWidgets('Esc leaves it', (tester) async {
        await pumpOpen(tester);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);

        await expectLeft(tester);
      });

      testWidgets("the remote's Back leaves it", (tester) async {
        await pumpOpen(tester);

        // Nothing takes the key, so Android turns it into its own Back.
        // (Flutter's test keys have no Android scan code for it: sent as the
        // web names it, the app sees the same Back key.)
        final used = await simulateKeyDownEvent(
          LogicalKeyboardKey.goBack,
          physicalKey: PhysicalKeyboardKey.browserBack,
          platform: 'web',
        );
        expect(used, isFalse);
        await tester.binding.handlePopRoute();

        await expectLeft(tester);
      });
    });
  }

  // REV-164: offline, the error screen said "All sources failed".
  for (final (locale, l10n) in [
    (const Locale('en'), AppLocalizationsEn()),
    (const Locale('it'), AppLocalizationsIt()),
  ]) {
    testWidgets('offline (${locale.languageCode}): "can\'t reach the server", '
        'Retry focused; Enter loads again', (tester) async {
      var isOnline = false;
      var loads = 0;
      await tester.pumpWidget(
        ProviderScope(
          retry: noProviderRetry,
          overrides: [
            settingsProvider.overrideWith(FakeSettingsNotifier.new),
            localeProvider.overrideWithBuild(
              (ref, notifier) => Locale(locale.languageCode),
            ),
            playerControllerProvider.overrideWith2(
              (_) => FakePlayerController(() {
                loads++;
                return isOnline
                    ? const AsyncValue.loading()
                    : AsyncValue.error(
                        const NetworkFailure('offline'),
                        StackTrace.empty,
                      );
              }),
            ),
          ],
          child: MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const VideoPlayerScreen(queryId: '550', type: 'movie'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(l10n.failureNetwork), findsOneWidget);
      expect(find.text(l10n.playerAllSourcesExhausted), findsNothing);
      expect(isFocused(find.text(l10n.commonRetry)), isTrue);

      isOnline = true;
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(loads, 2);
      expect(find.text(l10n.failureNetwork), findsNothing);
    });
  }
}
