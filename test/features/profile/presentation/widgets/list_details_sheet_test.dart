import 'package:cinemuse_app/core/services/system/connectivity_service.dart';
import 'package:cinemuse_app/features/media/data/tmdb_service.dart';
import 'package:cinemuse_app/features/profile/application/profile_providers.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/list_details_sheet.dart';
import 'package:cinemuse_app/features/search/application/search_provider.dart';
import 'package:cinemuse_app/features/search/application/search_state.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:cinemuse_app/shared/widgets/media_card.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/offline_lists.dart';

class MockTmdbService extends Mock implements TmdbService {}

class FakeSettingsNotifier extends SettingsNotifier {
  @override
  UserSettings build() => const UserSettings();
}

// REV-203: offline, a title added from the list's search stayed in the list
// with no message.
void main() {
  final l10n = AppLocalizationsEn();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('offline, + (search) on the Watchlist: a red message, '
      'the title is not in the list', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...offlineListsOverrides(),
          tmdbServiceProvider.overrideWithValue(MockTmdbService()),
          userIdProvider.overrideWithValue('user-a'),
          connectivityProvider.overrideWith(
            (ref) => Stream.value(ConnectivityResult.wifi),
          ),
          settingsProvider.overrideWith(FakeSettingsNotifier.new),
          searchProvider.overrideWith(
            (ref) =>
                SearchNotifier(ref, userId: 'user-a')
                  ..state = const SearchState(
                    query: 'Some',
                    status: SearchStatus.loaded,
                    results: [
                      {
                        'id': 1,
                        'title': 'Some Movie',
                        'media_type': 'movie',
                        'poster_path': null,
                        'vote_average': 7.0,
                      },
                    ],
                  ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ListDetailsSheet(list: offlineWatchlist)),
        ),
      ),
    );
    // Not pumpAndSettle: the empty list's animation never settles.
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byTooltip(l10n.searchPlaceholder));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.widgetWithText(MediaCard, 'Some Movie'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text(l10n.failureNetwork), findsOneWidget);
    expect(find.text('Some Movie'), findsNothing);
  });
}
