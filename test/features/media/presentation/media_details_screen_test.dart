import 'package:cinemuse_app/core/services/system/connectivity_service.dart';
import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:cinemuse_app/features/media/application/watch_history_store.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/media/presentation/media_details_screen.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/streaming/unified_stream_resolver.dart';
import 'package:cinemuse_app/features/streaming/unified_stream_resolver_provider.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/offline_lists.dart';

class MockUnifiedStreamResolver extends Mock implements UnifiedStreamResolver {}

class FakeSettingsNotifier extends SettingsNotifier {
  @override
  UserSettings build() => const UserSettings();
}

void main() {
  final l10n = AppLocalizationsEn();

  // A movie half watched.
  final history = WatchHistory(
    userId: 'user-a',
    tmdbId: 1,
    mediaType: MediaKind.movie,
    status: WatchStatus.watching,
    progressSeconds: 600,
    totalDuration: 6000,
    lastWatchedAt: DateTime.utc(2026, 10, 1),
  );

  Widget app({required List<Override> overrides}) {
    final resolver = MockUnifiedStreamResolver();
    when(
      () => resolver.hasCachedStream(
        any(),
        any(),
        season: any(named: 'season'),
        episode: any(named: 'episode'),
      ),
    ).thenReturn(false);
    return ProviderScope(
      overrides: [
        ...offlineListsOverrides(),
        unifiedStreamResolverProvider.overrideWithValue(resolver),
        settingsProvider.overrideWith(FakeSettingsNotifier.new),
        watchHistoryStoreProvider.overrideWith(
          (ref) => Stream.value({history.titleKey: history}),
        ),
        movieWatchCountProvider.overrideWith((ref, id) => 0),
        ...overrides,
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaDetailsScreen(mediaId: '1', mediaType: 'movie'),
      ),
    );
  }

  final loaded = [
    connectivityProvider.overrideWith(
      (ref) => Stream.value(ConnectivityResult.wifi),
    ),
    mediaDetailsProvider.overrideWith(
      (ref, args) async => {'id': 1, 'title': 'Some Movie'},
    ),
  ];

  // REV-205: Drop and Clear progress from the Play menu showed "Exception".
  for (final action in [l10n.menuStopWatching, l10n.menuClearProgress]) {
    testWidgets('offline, Play menu → "$action": a red translated message', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(overrides: loaded));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      // The menu takes taps only once it is fully open.
      await tester.pumpAndSettle();
      await tester.tap(find.text(action));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text(l10n.failureNetwork), findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);
    });
  }
}
