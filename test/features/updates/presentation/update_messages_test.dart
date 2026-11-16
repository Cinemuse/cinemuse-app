import 'package:cinemuse_app/core/application/provider_retry.dart';
import 'package:cinemuse_app/features/updates/application/update_service.dart';
import 'package:cinemuse_app/features/updates/domain/update_state.dart';
import 'package:cinemuse_app/features/updates/presentation/update_messages.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:cinemuse_app/l10n/app_localizations_it.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The app-start check answers [afterCheck]; [emit] plays the later steps.
class _FakeUpdateNotifier extends UpdateNotifier {
  final UpdateState afterCheck;
  int checkCalls = 0;

  _FakeUpdateNotifier(this.afterCheck);

  @override
  UpdateState build() => UpdateState(status: UpdateStatus.initial);

  @override
  Future<void> checkForUpdates() async {
    checkCalls++;
    state = afterCheck;
  }

  void emit(UpdateState next) => state = next;
}

final _available = UpdateState(
  status: UpdateStatus.available,
  latestVersion: 'v1.9.3',
);

void main() {
  final en = AppLocalizationsEn();

  Future<_FakeUpdateNotifier> pumpMessages(
    WidgetTester tester,
    UpdateState afterCheck, {
    bool showsMessages = true,
    bool isReleaseBuild = true,
    Locale locale = const Locale('en'),
  }) async {
    final notifier = _FakeUpdateNotifier(afterCheck);
    await tester.pumpWidget(
      ProviderScope(
        retry: noProviderRetry,
        overrides: [
          updateProvider.overrideWith(() => notifier),
          updatesShownProvider.overrideWithValue(isReleaseBuild),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: UpdateMessages(
            showsMessages: showsMessages,
            child: const Scaffold(body: Text('Home tab')),
          ),
        ),
      ),
    );
    // The check starts after the first frame.
    await tester.pump();
    await tester.pump();
    return notifier;
  }

  Finder message(String text) => find.descendant(
    of: find.byType(SnackBar),
    matching: find.textContaining(text),
  );

  testWidgets('a new version at app start: the message names it and where '
      'to update', (tester) async {
    final notifier = await pumpMessages(tester, _available);

    expect(notifier.checkCalls, 1);
    expect(message(en.updateAvailableMessage('1.9.3')), findsOneWidget);
  });

  testWidgets('Italian', (tester) async {
    await pumpMessages(tester, _available, locale: const Locale('it'));

    expect(
      message(AppLocalizationsIt().updateAvailableMessage('1.9.3')),
      findsOneWidget,
    );
  });

  testWidgets('up to date: no message', (tester) async {
    await pumpMessages(tester, UpdateState(status: UpdateStatus.upToDate));

    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('the check at app start fails: no message', (tester) async {
    await pumpMessages(
      tester,
      UpdateState(status: UpdateStatus.error, errorKey: 'updateSourceError'),
    );

    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a debug build: no message', (tester) async {
    await pumpMessages(tester, _available, isReleaseBuild: false);

    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('under the update-required screen: no message', (tester) async {
    await pumpMessages(tester, _available, showsMessages: false);

    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a download that fails: its reason in a red message', (
    tester,
  ) async {
    final notifier = await pumpMessages(tester, _available);
    ScaffoldMessenger.of(
      tester.element(find.text('Home tab')),
    ).hideCurrentSnackBar();
    await tester.pumpAndSettle();

    notifier.emit(_available.copyWith(status: UpdateStatus.downloading));
    await tester.pump();
    notifier.emit(
      _available.copyWith(
        status: UpdateStatus.error,
        errorKey: 'updateNetworkError',
      ),
    );
    await tester.pump();

    expect(message(en.updateNetworkError), findsOneWidget);
  });
}
