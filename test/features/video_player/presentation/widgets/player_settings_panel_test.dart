import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/presentation/theme/breakpoints.dart';
import 'package:cinemuse_app/features/settings/application/local_settings_service.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/settings/domain/subtitle_style.dart';
import 'package:cinemuse_app/features/settings/domain/user_settings.dart';
import 'package:cinemuse_app/features/streaming/models/resolved_stream.dart';
import 'package:cinemuse_app/features/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/features/streaming/subtitles/subtitle_service.dart';
import 'package:cinemuse_app/features/video_player/application/language_mapper.dart';
import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/player_settings_panel.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/settings/live_tv_quality_view.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:cinemuse_app/shared/widgets/app_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/app_font.dart';
import '../../../../helpers/focus_helpers.dart';
import 'package:cinemuse_app/core/application/provider_retry.dart';

class _MockPlayer extends Mock implements Player {}

class _MockVideoController extends Mock implements VideoController {}

class _FakeSettingsNotifier extends SettingsNotifier {
  @override
  UserSettings build() => const UserSettings();
}

class _FakePlayerController extends Notifier<AsyncValue<CinemaPlayerState>>
    implements PlayerController {
  _FakePlayerController(this.initial);
  final CinemaPlayerState initial;
  final picked = <Object>[];

  @override
  AsyncValue<CinemaPlayerState> build() => AsyncValue.data(initial);

  @override
  Future<void> selectTrack(Object track) async => picked.add(track);

  @override
  void updateSubtitleDelay(double delaySeconds) => state = AsyncValue.data(
    state.value!.copyWith(subtitleDelay: delaySeconds),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _english = AudioTrack('1', 'English', 'eng');
final _italian = AudioTrack('2', 'Italiano', 'ita');
final _source = StreamCandidate(
  kind: StreamSourceKind.vod,
  title: 'Movie 1080p',
  infoHash: 'a',
  provider: 'Torrentio',
);

// REV-333: the settings were a menu with sub-pages, and each subtitle look
// control opened its own small panel; now they are one panel with tabs.
void main() {
  const params = PlayerParams('550', 'movie');
  late _FakePlayerController player;
  late List<PlayerSettingsTab> tabChanges;

  setUpAll(loadAppFont);

  Future<void> openPanel(
    WidgetTester tester, {
    PlayerSettingsKind kind = PlayerSettingsKind.tracks,
    PlayerSettingsTab tab = PlayerSettingsTab.audio,
    bool isLive = false,
    Size size = const Size(1280, 720),
    Locale? locale,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // The look saved on the device before (REV-170: the player's menu
    // showed the defaults instead).
    SharedPreferences.setMockInitialValues({'subtitle_font_size': 32.0});

    final mediaPlayer = _MockPlayer();
    final video = _MockVideoController();
    when(() => video.player).thenReturn(mediaPlayer);
    when(() => mediaPlayer.state).thenReturn(
      PlayerState(
        tracks: Tracks(
          audio: [AudioTrack.auto(), AudioTrack.no(), _english, _italian],
          subtitle: [SubtitleTrack.auto(), SubtitleTrack.no()],
        ),
        track: Track(audio: _english, subtitle: SubtitleTrack.no()),
      ),
    );
    final state = CinemaPlayerState(
      controller: video,
      availableStreams: [_source],
      currentStream: ResolvedStream(
        url: 'https://example.com/movie.mkv',
        provider: 'Torrentio',
        candidate: _source,
      ),
      title: 'Movie',
      isLive: isLive,
    );
    player = _FakePlayerController(state);
    tabChanges = [];

    await tester.pumpWidget(
      ProviderScope(
        retry: noProviderRetry,
        overrides: [
          // A new one each time the panel opens: a closed panel drops it.
          playerControllerProvider.overrideWith2(
            (_) => player = _FakePlayerController(state),
          ),
          settingsProvider.overrideWith(_FakeSettingsNotifier.new),
          subtitleServiceProvider.overrideWithValue(SubtitleService(const [])),
        ],
        child: MaterialApp(
          locale: locale,
          theme: AppTheme.darkTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => PlayerSettingsPanel.show(
                  context,
                  state,
                  params,
                  kind: kind,
                  initialTab: tab,
                  onTabChanged: tabChanges.add,
                ),
                child: const Text('Settings'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  Finder tabLabel(String text) => find.text(text.toUpperCase());

  group('tabs and keys', () {
    testWidgets('opens on the given tab, on the option that is on', (
      tester,
    ) async {
      await openPanel(tester, tab: PlayerSettingsTab.audio);

      expect(
        isFocused(
          find.text(LanguageMapper.trackLabel(_english, AppLocalizationsEn())),
        ),
        isTrue,
      );
    });

    testWidgets('Up from the first row goes to the selected tab', (
      tester,
    ) async {
      await openPanel(tester, tab: PlayerSettingsTab.subtitles);
      // The subtitles are off: their row is the first one.
      expect(isFocused(find.text('Off / Disable')), isTrue);

      await press(tester, LogicalKeyboardKey.arrowUp);

      expect(isFocused(tabLabel('Subtitles')), isTrue);
    });

    testWidgets('Left / Right on the tabs switch tab at once; Down enters '
        'the list', (tester) async {
      await openPanel(tester, tab: PlayerSettingsTab.audio);
      await press(tester, LogicalKeyboardKey.arrowUp);
      await press(tester, LogicalKeyboardKey.arrowUp);
      expect(isFocused(tabLabel('Audio')), isTrue);

      await press(tester, LogicalKeyboardKey.arrowRight);
      expect(isFocused(tabLabel('Subtitles')), isTrue);
      expect(find.text('Off / Disable'), findsOneWidget);
      await press(tester, LogicalKeyboardKey.arrowRight);
      expect(isFocused(tabLabel('Look')), isTrue);
      // The row ends at Look: the focus stays in the panel.
      await press(tester, LogicalKeyboardKey.arrowRight);
      expect(isFocused(tabLabel('Look')), isTrue);
      await press(tester, LogicalKeyboardKey.arrowLeft);
      await press(tester, LogicalKeyboardKey.arrowLeft);
      await press(tester, LogicalKeyboardKey.arrowLeft);
      expect(isFocused(tabLabel('Audio')), isTrue);
      expect(tabLabel('Source'), findsNothing);
      expect(tabChanges, [
        PlayerSettingsTab.subtitles,
        PlayerSettingsTab.look,
        PlayerSettingsTab.subtitles,
        PlayerSettingsTab.audio,
      ]);

      await press(tester, LogicalKeyboardKey.arrowDown);
      expect(isFocused(find.text('No Audio / Mute')), isTrue);
    });

    testWidgets('Left / Right in a list do nothing', (tester) async {
      await openPanel(tester, tab: PlayerSettingsTab.audio);
      final english = find.text(
        LanguageMapper.trackLabel(_english, AppLocalizationsEn()),
      );

      await press(tester, LogicalKeyboardKey.arrowRight);
      await press(tester, LogicalKeyboardKey.arrowLeft);

      expect(isFocused(english), isTrue);
      expect(tabChanges, isEmpty);
    });

    testWidgets('Back closes the panel from a list and from the tabs', (
      tester,
    ) async {
      await openPanel(tester, tab: PlayerSettingsTab.audio);
      await press(tester, LogicalKeyboardKey.escape);
      expect(find.byType(PlayerSettingsPanel), findsNothing);

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await press(tester, LogicalKeyboardKey.arrowUp);
      await press(tester, LogicalKeyboardKey.arrowUp);
      await press(tester, LogicalKeyboardKey.escape);
      expect(find.byType(PlayerSettingsPanel), findsNothing);
    });

    testWidgets('an audio pick keeps the panel open', (tester) async {
      await openPanel(tester, tab: PlayerSettingsTab.audio);

      await tester.tap(
        find.text(LanguageMapper.trackLabel(_italian, AppLocalizationsEn())),
      );
      await tester.pumpAndSettle();

      expect(player.picked, [_italian]);
      expect(find.byType(PlayerSettingsPanel), findsOneWidget);
    });
  });

  group('layout', () {
    // REV-333: a column on the right edge, full height, became the app's
    // sheet rising in the bottom-right corner.
    for (final (name, size, width) in const [
      ('a big window', Size(1920, 1080), 640.0),
      ('a TV', Size(960, 540), Breakpoints.sideSheetMin),
      ('a phone sideways', Size(800, 360), Breakpoints.sideSheetMin),
    ]) {
      testWidgets('$name: the sheet rises in the bottom-right corner, a third '
          'wide, almost to the top', (tester) async {
        await openPanel(tester, size: size);

        final sheet = tester.getRect(find.byType(AppBottomSheet));
        expect(sheet.width, closeTo(width, 0.01));
        expect(sheet.right, size.width - 16);
        expect(sheet.bottom, size.height);
        expect(sheet.top, 16);
      });
    }

    testWidgets('the video beside it stays bright, and a tap on it closes '
        'the sheet', (tester) async {
      await openPanel(tester);

      // No barrier darkens the video (the app's other sheets do).
      final shades = tester
          .widgetList<ModalBarrier>(find.byType(ModalBarrier))
          .map((barrier) => barrier.color?.a ?? 0);
      expect(shades, everyElement(0));

      await tester.tapAt(const Offset(200, 360));
      await tester.pumpAndSettle();
      expect(find.byType(PlayerSettingsPanel), findsNothing);
    });

    testWidgets('a tap inside the sheet keeps it open', (tester) async {
      await openPanel(tester);

      await tester.tapAt(
        tester.getBottomLeft(find.byType(AppBottomSheet)) + const Offset(8, -8),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PlayerSettingsPanel), findsOneWidget);
    });

    testWidgets('phone upright: full width from the bottom, under the video', (
      tester,
    ) async {
      await openPanel(tester, size: const Size(400, 800));

      final sheet = tester.getRect(find.byType(AppBottomSheet));
      expect(sheet.width, 400);
      expect(sheet.top, greaterThanOrEqualTo(800 * 0.4));
      expect(sheet.bottom, 800);
      expect(tabLabel('Look'), findsOneWidget);
    });

    testWidgets('Source: the sources, no tabs, on the one playing', (
      tester,
    ) async {
      await openPanel(tester, kind: PlayerSettingsKind.source);

      expect(find.text('SELECT SOURCE'), findsOneWidget);
      expect(tabLabel('Audio'), findsNothing);
      expect(isFocused(find.text('Movie 1080p')), isTrue);
    });

    testWidgets('live TV Source: its quality list, no tabs', (tester) async {
      await openPanel(tester, kind: PlayerSettingsKind.source, isLive: true);

      expect(find.byType(LiveTvQualityView), findsOneWidget);
      expect(tabLabel('Audio'), findsNothing);
      expect(find.text('SELECT SOURCE'), findsOneWidget);
    });
  });

  group('Look tab', () {
    bool sliderFocused() =>
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<Slider>() !=
        null;

    LocalSettings looks(WidgetTester tester) => ProviderScope.containerOf(
      tester.element(find.byType(PlayerSettingsPanel)),
    ).read(localSettingsProvider);

    testWidgets('shows the look saved on the device', (tester) async {
      await openPanel(tester, tab: PlayerSettingsTab.look);

      expect(find.text('32 px'), findsOneWidget);
    });

    testWidgets('Right on the size slider changes and saves it, the panel '
        'stays open; Up / Down leave the slider', (tester) async {
      await openPanel(tester, tab: PlayerSettingsTab.look);
      expect(isFocused(find.text('-.1')), isTrue);
      await press(tester, LogicalKeyboardKey.arrowDown);
      expect(sliderFocused(), isTrue);

      await press(tester, LogicalKeyboardKey.arrowRight);

      expect(looks(tester).subtitleStyle.fontSize, greaterThan(32));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('subtitle_font_size'), greaterThan(32));
      expect(find.byType(PlayerSettingsPanel), findsOneWidget);

      // REV-282: ↑ / ↓ move to the next control, not the value.
      final size = looks(tester).subtitleStyle.fontSize;
      await press(tester, LogicalKeyboardKey.arrowDown);
      expect(sliderFocused(), isTrue);
      expect(looks(tester).subtitleStyle.fontSize, size);
    });

    testWidgets('a sync step changes the sync for this video', (tester) async {
      await openPanel(tester, tab: PlayerSettingsTab.look);

      await press(tester, LogicalKeyboardKey.enter);

      expect(player.state.value!.subtitleDelay, -0.1);
      expect(find.text('-0.1s'), findsOneWidget);
    });

    testWidgets('Reset puts the standard look and no sync back', (
      tester,
    ) async {
      await openPanel(tester, tab: PlayerSettingsTab.look);
      await press(tester, LogicalKeyboardKey.enter);

      await tester.ensureVisible(find.text('Reset to Default'));
      await tester.tap(find.text('Reset to Default'));
      await tester.pumpAndSettle();

      expect(
        looks(tester).subtitleStyle.fontSize,
        const SubtitleStyle().fontSize,
      );
      expect(player.state.value!.subtitleDelay, 0);
      expect(find.byType(PlayerSettingsPanel), findsOneWidget);
    });

    // REV-166, REV-176: long Italian names and a phone's width.
    for (final (name, size) in const [
      ('phone sideways', Size(740, 360)),
      ('phone upright', Size(360, 740)),
    ]) {
      testWidgets('Italian, $name: everything fits, the six sync buttons '
          'are in the panel', (tester) async {
        await openPanel(
          tester,
          tab: PlayerSettingsTab.look,
          size: size,
          locale: const Locale('it'),
        );

        expect(tester.takeException(), isNull);
        final panel = tester.getRect(find.byType(PlayerSettingsPanel));
        for (final label in ['-5', '-1', '-.1', '+.1', '+1', '+5']) {
          final button = tester.getRect(find.text(label));
          expect(panel.contains(button.topLeft), isTrue, reason: label);
          expect(panel.contains(button.bottomRight), isTrue, reason: label);
        }
      });
    }
  });
}
