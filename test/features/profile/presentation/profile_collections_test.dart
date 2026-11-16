import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:cinemuse_app/features/profile/application/pinned_list_ids_provider.dart';
import 'package:cinemuse_app/features/profile/domain/user_list.dart';
import 'package:cinemuse_app/features/profile/presentation/profile_collections.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/core/application/provider_retry.dart';

UserList _list(String id, String name, ListType type) => UserList(
  id: id,
  userId: 'user-a',
  name: name,
  type: type,
  createdAt: DateTime(2026),
);

class FakeUserListsNotifier extends UserListsNotifier {
  @override
  Stream<List<UserList>> build() => Stream.value([
    _list('w', 'Watchlist', ListType.watchlist),
    _list('horror', 'Horror', ListType.custom),
  ]);
}

class FakePinnedListIdsNotifier extends PinnedListIdsNotifier {
  @override
  Set<String> build() => {'w'};

  @override
  Future<void> togglePin(String listId) async {
    state = state.contains(listId)
        ? ({...state}..remove(listId))
        : {...state, listId};
  }
}

// REV-255: list cards on the Collections page had no right-click menu.
void main() {
  final l10n = AppLocalizationsEn();

  late ProviderContainer container;

  Future<void> pumpPage(WidgetTester tester, {Locale? locale}) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: noProviderRetry,
        overrides: [
          userListsProvider.overrideWith(FakeUserListsNotifier.new),
          droppedListProvider.overrideWith((ref) async => null),
          pinnedListIdsProvider.overrideWith(FakePinnedListIdsNotifier.new),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: ProfileCollections()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    container = ProviderScope.containerOf(
      tester.element(find.byType(ProfileCollections)),
    );
  }

  Future<void> rightClick(WidgetTester tester, String text) async {
    await tester.tap(find.text(text), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
  }

  testWidgets('own list: right-click pins it, and offers delete', (
    tester,
  ) async {
    await pumpPage(tester);

    await rightClick(tester, 'Horror');
    expect(find.text(l10n.menuOpenList), findsOneWidget);
    expect(find.text(l10n.detailsDeleteList), findsOneWidget);
    await tester.tap(find.text(l10n.listPinToHome));
    await tester.pumpAndSettle();

    expect(container.read(pinnedListIdsProvider), contains('horror'));
    expect(find.text(l10n.listPinnedSuccess), findsOneWidget);
  });

  testWidgets('Watchlist: right-click unpins it, no delete', (tester) async {
    await pumpPage(tester);

    await rightClick(tester, l10n.listWatchLater);
    expect(find.text(l10n.detailsDeleteList), findsNothing);
    await tester.tap(find.text(l10n.listUnpinFromHome));
    await tester.pumpAndSettle();

    expect(container.read(pinnedListIdsProvider), isNot(contains('w')));
  });

  testWidgets('an empty list with no description says so in Italian', (
    tester,
  ) async {
    // Wide: the test font draws every letter as a full square.
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpPage(tester, locale: const Locale('it'));

    expect(find.text('Ancora nessun titolo'), findsOneWidget);
    expect(find.text('No items yet'), findsNothing);
  });
}
