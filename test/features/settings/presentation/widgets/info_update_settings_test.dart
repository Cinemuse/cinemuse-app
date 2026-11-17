import 'package:cinemuse_app/core/application/provider_retry.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/services/system/app_full_screen.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/info_update_settings.dart';
import 'package:cinemuse_app/features/updates/application/update_service.dart';
import 'package:cinemuse_app/features/updates/domain/release_notes.dart';
import 'package:cinemuse_app/features/updates/domain/update_state.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:cinemuse_app/l10n/app_localizations_it.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/focus_helpers.dart';
import '../../../../helpers/fake_app_window.dart';

/// Holds a fixed update state and records the buttons' calls. A check
/// moves to [afterCheck].
class _FakeUpdateNotifier extends UpdateNotifier {
  final UpdateState initial;
  final UpdateState? afterCheck;
  int startCalls = 0;
  int checkCalls = 0;
  int cancelCalls = 0;

  _FakeUpdateNotifier(this.initial, {this.afterCheck});

  @override
  UpdateState build() => initial;

  @override
  Future<void> startUpdate() async => startCalls++;

  @override
  Future<void> checkForUpdates() async {
    checkCalls++;
    state = afterCheck ?? state;
  }

  @override
  void cancelUpdate() => cancelCalls++;
}

const _notes193 = ReleaseNotes('1.9.3', {
  'en': '- Faster Live TV',
  'it': '- TV in diretta più veloce',
});

UpdateState _state(
  UpdateStatus status, {
  String? latest,
  List<ReleaseNotes> notes = const [],
  double progress = 0,
  String? errorKey,
}) => UpdateState(
  status: status,
  currentVersion: '1.9.2',
  latestVersion: latest,
  releaseNotes: notes,
  progress: progress,
  errorKey: errorKey,
);

void main() {
  final en = AppLocalizationsEn();

  Future<_FakeUpdateNotifier> pumpPage(
    WidgetTester tester,
    UpdateState state, {
    UpdateState? afterCheck,
    bool isReleaseBuild = true,
    Locale locale = const Locale('en'),
    AppWindow window = const AppWindow(),
  }) async {
    final notifier = _FakeUpdateNotifier(state, afterCheck: afterCheck);
    await tester.pumpWidget(
      ProviderScope(
        retry: noProviderRetry,
        overrides: [
          updateProvider.overrideWith(() => notifier),
          updatesShownProvider.overrideWithValue(isReleaseBuild),
          appWindowProvider.overrideWithValue(window),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: SingleChildScrollView(child: InfoUpdateSettings()),
          ),
        ),
      ),
    );
    await tester.pump();
    return notifier;
  }

  testWidgets(
    'Windows and Linux: Close Cinemuse closes the app',
    (tester) async {
      final window = FakeAppWindow();
      await pumpPage(tester, _state(UpdateStatus.upToDate), window: window);

      await tester.tap(find.text(en.settingsCloseApp));
      await tester.pump();

      expect(window.closeCalls, 1);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets(
    'Android: no Close Cinemuse (Android closes apps itself)',
    (tester) async {
      await pumpPage(tester, _state(UpdateStatus.upToDate));

      expect(find.text(en.settingsCloseApp), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('up to date: the version, "up to date" and Check for updates', (
    tester,
  ) async {
    await pumpPage(tester, _state(UpdateStatus.upToDate));

    expect(find.text(en.updateInstalledVersion), findsOneWidget);
    expect(find.text('1.9.2'), findsOneWidget);
    expect(find.text(en.updateUpToDate), findsOneWidget);
    expect(find.text(en.updateCheck), findsOneWidget);
    expect(find.text(en.updateNow), findsNothing);
  });

  testWidgets('a new version: its number, its notes and Update now', (
    tester,
  ) async {
    final notifier = await pumpPage(
      tester,
      _state(UpdateStatus.available, latest: 'v1.9.3', notes: [_notes193]),
    );

    expect(find.text(en.updateNewVersion), findsOneWidget);
    // The new version's row and its notes' title.
    expect(find.text('1.9.3'), findsNWidgets(2));
    expect(find.text(en.updateWhatsNew), findsOneWidget);
    expect(find.text('Faster Live TV'), findsOneWidget);

    await tester.tap(find.text(en.updateNow));
    expect(notifier.startCalls, 1);
  });

  testWidgets('several new versions: each one\'s notes, newest first', (
    tester,
  ) async {
    await pumpPage(
      tester,
      _state(
        UpdateStatus.available,
        latest: 'v1.9.4',
        notes: [
          const ReleaseNotes('1.9.4', {'en': '- Smaller guide'}),
          _notes193,
        ],
      ),
    );

    expect(find.text(en.updateWhatsNew), findsOneWidget);
    final newer = tester.getTopLeft(find.text('Smaller guide')).dy;
    final older = tester.getTopLeft(find.text('Faster Live TV')).dy;
    expect(newer, lessThan(older));
    expect(
      tester.getTopLeft(find.text('1.9.3')).dy,
      allOf(greaterThan(newer), lessThan(older)),
    );
  });

  testWidgets('new versions without notes: no notes card', (tester) async {
    await pumpPage(tester, _state(UpdateStatus.available, latest: 'v1.9.3'));

    expect(find.text('1.9.3'), findsOneWidget);
    expect(find.text(en.updateWhatsNew), findsNothing);
  });

  testWidgets('the app in Italian: the Italian notes', (tester) async {
    final it = AppLocalizationsIt();
    await pumpPage(
      tester,
      _state(UpdateStatus.available, latest: 'v1.9.3', notes: [_notes193]),
      locale: const Locale('it'),
    );

    expect(find.text(it.updateWhatsNew), findsOneWidget);
    expect(find.text('TV in diretta più veloce'), findsOneWidget);
    expect(find.text('Faster Live TV'), findsNothing);
  });

  testWidgets('the remote reaches Update now, Check for updates and the '
      'notes', (tester) async {
    await pumpPage(
      tester,
      _state(UpdateStatus.available, latest: 'v1.9.3', notes: [_notes193]),
    );

    await tabTo(tester, find.text(en.updateNow));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(isFocused(find.text(en.updateCheck)), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(isFocused(find.text('Faster Live TV')), isTrue);
  });

  testWidgets('downloading: the bar, the percentage and Cancel, no buttons', (
    tester,
  ) async {
    final notifier = await pumpPage(
      tester,
      _state(UpdateStatus.downloading, latest: 'v1.9.3', progress: 42),
    );

    expect(find.text(en.downloadingUpdate('42')), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text(en.updateNow), findsNothing);
    expect(find.text(en.updateCheck), findsNothing);

    await tester.tap(find.text(en.updateCancel));
    expect(notifier.cancelCalls, 1);
  });

  testWidgets('a failed download: the reason, and Update now again', (
    tester,
  ) async {
    await pumpPage(
      tester,
      _state(
        UpdateStatus.error,
        latest: 'v1.9.3',
        errorKey: 'updateNetworkError',
      ),
    );

    expect(find.text(en.updateNetworkError), findsOneWidget);
    expect(find.text(en.updateNow), findsOneWidget);
  });

  testWidgets('Check for updates that fails: the reason on the page and in '
      'a red message', (tester) async {
    final notifier = await pumpPage(
      tester,
      _state(UpdateStatus.upToDate),
      afterCheck: _state(UpdateStatus.error, errorKey: 'updateSourceError'),
    );

    await tester.tap(find.text(en.updateCheck));
    await tester.pump();

    expect(notifier.checkCalls, 1);
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text(en.updateSourceError),
      ),
      findsOneWidget,
    );
    expect(find.text(en.updateSourceError), findsNWidgets(2));
  });

  testWidgets('Check for updates that finds one: no message, Update now', (
    tester,
  ) async {
    await pumpPage(
      tester,
      _state(UpdateStatus.upToDate),
      afterCheck: _state(UpdateStatus.available, latest: 'v1.9.3'),
    );

    await tester.tap(find.text(en.updateCheck));
    await tester.pump();

    expect(find.byType(SnackBar), findsNothing);
    expect(find.text(en.updateNow), findsOneWidget);
  });

  testWidgets('while checking: "checking" and the button is off', (
    tester,
  ) async {
    final notifier = await pumpPage(tester, _state(UpdateStatus.checking));

    expect(find.text(en.updateChecking), findsOneWidget);
    await tester.tap(find.text(en.updateCheck));
    expect(notifier.checkCalls, 0);
  });

  testWidgets('a debug build never offers an update', (tester) async {
    await pumpPage(
      tester,
      _state(UpdateStatus.available, latest: 'v1.9.3'),
      isReleaseBuild: false,
    );

    expect(find.text('1.9.3'), findsNothing);
    expect(find.text(en.updateNow), findsNothing);
  });

  testWidgets('Italian', (tester) async {
    final it = AppLocalizationsIt();
    await pumpPage(
      tester,
      _state(UpdateStatus.available, latest: 'v1.9.3'),
      locale: const Locale('it'),
    );

    expect(find.text(it.settingsInfoUpdates.toUpperCase()), findsOneWidget);
    expect(find.text(it.updateInstalledVersion), findsOneWidget);
    expect(find.text(it.updateNow), findsOneWidget);
    expect(find.text(it.updateCheck), findsOneWidget);
  });
}
