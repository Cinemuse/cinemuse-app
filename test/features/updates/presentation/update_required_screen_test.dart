import 'package:cinemuse_app/features/updates/application/update_service.dart';
import 'package:cinemuse_app/features/updates/domain/release_notes.dart';
import 'package:cinemuse_app/features/updates/domain/update_state.dart';
import 'package:cinemuse_app/features/updates/presentation/update_required_screen.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:cinemuse_app/l10n/app_localizations_it.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/focus_helpers.dart';
import 'package:cinemuse_app/core/application/provider_retry.dart';

/// Holds a fixed update state and records the buttons' calls.
class _FakeUpdateNotifier extends UpdateNotifier {
  final UpdateState initial;
  int startCalls = 0;
  int checkCalls = 0;

  _FakeUpdateNotifier(this.initial);

  @override
  UpdateState build() => initial;

  @override
  Future<void> startUpdate() async => startCalls++;

  @override
  Future<void> checkForUpdates() async => checkCalls++;
}

void main() {
  final en = AppLocalizationsEn();

  Future<_FakeUpdateNotifier> pumpScreen(
    WidgetTester tester,
    UpdateStatus status, {
    String? errorKey,
    List<ReleaseNotes> notes = const [],
    Locale locale = const Locale('en'),
  }) async {
    final notifier = _FakeUpdateNotifier(
      UpdateState(status: status, errorKey: errorKey, releaseNotes: notes),
    );
    await tester.pumpWidget(
      ProviderScope(
        retry: noProviderRetry,
        overrides: [updateProvider.overrideWith(() => notifier)],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const UpdateRequiredScreen(),
        ),
      ),
    );
    await tester.pump();
    return notifier;
  }

  group('UpdateRequiredScreen (REV-306)', () {
    testWidgets('release found: Update now has the focus and starts it', (
      tester,
    ) async {
      final notifier = await pumpScreen(tester, UpdateStatus.available);

      expect(find.text(en.updateRequiredTitle), findsOneWidget);
      expect(find.text(en.updateRequiredMessage), findsOneWidget);
      expect(isFocused(find.text(en.updateNow)), isTrue);

      await tester.tap(find.text(en.updateNow));
      expect(notifier.startCalls, 1);
    });

    testWidgets("the new versions' notes under Update now, reached with "
        'the remote', (tester) async {
      await pumpScreen(
        tester,
        UpdateStatus.available,
        notes: [
          const ReleaseNotes('2.2.0', {'en': '- Smaller guide'}),
          const ReleaseNotes('2.1.0', {'en': '- Faster Live TV'}),
        ],
      );

      expect(find.text(en.updateWhatsNew), findsOneWidget);
      expect(find.text('2.2.0'), findsOneWidget);
      expect(find.text('2.1.0'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Smaller guide')).dy,
        lessThan(tester.getTopLeft(find.text('Faster Live TV')).dy),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(isFocused(find.text('Smaller guide')), isTrue);
    });

    testWidgets('no notes: only the button', (tester) async {
      await pumpScreen(tester, UpdateStatus.available);

      expect(find.text(en.updateWhatsNew), findsNothing);
    });

    testWidgets('update check failed: the reason and Retry', (tester) async {
      final notifier = await pumpScreen(
        tester,
        UpdateStatus.error,
        errorKey: 'updateNetworkError',
      );

      expect(find.text(en.updateNetworkError), findsOneWidget);
      expect(find.text(en.updateNow), findsNothing);
      expect(isFocused(find.text(en.commonRetry)), isTrue);

      await tester.tap(find.text(en.commonRetry));
      expect(notifier.checkCalls, 1);
    });

    testWidgets('downloading: the bar and Cancel on the screen itself', (
      tester,
    ) async {
      await pumpScreen(tester, UpdateStatus.downloading);

      expect(find.text(en.downloadingUpdate('0')), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text(en.updateCancel), findsOneWidget);
    });

    testWidgets('no newer release found yet: Retry', (tester) async {
      final notifier = await pumpScreen(tester, UpdateStatus.upToDate);

      await tester.tap(find.text(en.commonRetry));
      expect(notifier.checkCalls, 1);
    });

    testWidgets(
      'Linux: Update now, like every other device',
      (tester) async {
        final notifier = await pumpScreen(tester, UpdateStatus.available);

        await tester.tap(find.text(en.updateNow));
        expect(notifier.startCalls, 1);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );

    testWidgets('Italian', (tester) async {
      final it = AppLocalizationsIt();
      await pumpScreen(
        tester,
        UpdateStatus.available,
        locale: const Locale('it'),
      );

      expect(find.text(it.updateRequiredTitle), findsOneWidget);
      expect(find.text(it.updateNow), findsOneWidget);
    });
  });
}
