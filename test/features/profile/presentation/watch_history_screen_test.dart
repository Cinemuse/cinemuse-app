import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/profile/application/profile_providers.dart';
import 'package:cinemuse_app/features/profile/application/user_data_sync_service.dart';
import 'package:cinemuse_app/features/profile/presentation/watch_history_screen.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/cursor_helpers.dart';

class FakeSettingsNotifier extends SettingsNotifier {
  @override
  UserSettings build() => const UserSettings();
}

/// A sync that fails as if offline.
class OfflineSyncService extends UserDataSyncService {
  OfflineSyncService(super.ref);

  @override
  Future<void> syncNow() async => throw const NetworkFailure('offline');
}

// REV-108: pull to refresh called the repository with no try/catch: offline,
// nothing told the user it failed.
void main() {
  final l10n = AppLocalizationsEn();

  final watched = WatchHistory(
    userId: 'user-a',
    tmdbId: 1,
    mediaType: MediaKind.movie,
    status: WatchStatus.completed,
    lastWatchedAt: DateTime.utc(2026, 10, 1),
    media: MediaItem(
      tmdbId: 1,
      mediaType: MediaKind.movie,
      titleEn: 'Some Movie',
      titleIt: 'Some Movie',
      updatedAt: DateTime.utc(2026),
    ),
  );

  Widget app() => ProviderScope(
    overrides: [
      userDataSyncServiceProvider.overrideWith(OfflineSyncService.new),
      watchLogsProvider.overrideWith((ref) async => [watched]),
      watchHistoryStreamProvider.overrideWith((ref) => Stream.value([])),
      settingsProvider.overrideWith(FakeSettingsNotifier.new),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: WatchHistoryScreen(),
    ),
  );

  testWidgets('pull to refresh offline: "no connection", the list stays', (
    tester,
  ) async {
    // A desktop window: the wide test font overflows the filter pills at 800.
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Some Movie'), findsWidgets);

    await tester.fling(
      find.text('Some Movie').first,
      const Offset(0, 400),
      1000,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text(l10n.failureNetwork), findsOneWidget);
    expect(find.text('Some Movie'), findsWidgets);
  });

  // REV-246: the phone's filters and order button showed the arrow cursor.
  testWidgets('phone: the filters and order button shows the hand', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(590, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await expectHandOver(tester, find.text(l10n.watchHistoryFiltersTitle));
  });
}
