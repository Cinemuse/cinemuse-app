import 'package:cinemuse_app/core/services/system/connectivity_service.dart';
import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:cinemuse_app/features/media/data/tmdb_service.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/collection_tile.dart';
import 'package:cinemuse_app/features/profile/application/profile_providers.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/focus_helpers.dart';
import '../../../../helpers/offline_lists.dart';

class _MockTmdbService extends Mock implements TmdbService {}

class _FakeSettingsNotifier extends SettingsNotifier {
  @override
  UserSettings build() => const UserSettings();
}

// REV-211: the tile was a plain GestureDetector: no remote or keyboard.
void main() {
  late int opens;
  final title = find.text('Star Wars Collection');

  Widget tile() => ProviderScope(
    overrides: [
      collectionModelProvider.overrideWith((ref, id) async {
        opens++;
        return null;
      }),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(
        body: CollectionTile(
          collection: MediaCollection(
            id: 10,
            name: 'Star Wars Collection',
            parts: [],
          ),
        ),
      ),
    ),
  );

  setUp(() => opens = 0);

  testWidgets('Enter opens the collection', (tester) async {
    await tester.pumpWidget(tile());
    await tabTo(tester, title);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(opens, 1);
  });

  testWidgets('a tap opens the collection', (tester) async {
    await tester.pumpWidget(tile());
    await tester.tap(title);
    await tester.pumpAndSettle();
    expect(opens, 1);
  });

  testWidgets('a tap opens the collection sheet with its films (REV-191)', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final tmdb = _MockTmdbService();
    when(() => tmdb.getCollectionDetails(10)).thenAnswer(
      (_) async => {
        'id': 10,
        'name': 'Star Wars Collection',
        'parts': [
          {'id': 11, 'title': 'A New Hope'},
          {'id': 12, 'title': 'The Empire Strikes Back'},
        ],
      },
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...offlineListsOverrides(),
          tmdbServiceProvider.overrideWithValue(tmdb),
          userIdProvider.overrideWithValue('user-a'),
          connectivityProvider.overrideWith(
            (ref) => Stream.value(ConnectivityResult.wifi),
          ),
          settingsProvider.overrideWith(_FakeSettingsNotifier.new),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: CollectionTile(
              collection: MediaCollection(
                id: 10,
                name: 'Star Wars Collection',
                parts: [],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(title);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('A New Hope'), findsOneWidget);
    expect(find.text('The Empire Strikes Back'), findsOneWidget);
  });
}
