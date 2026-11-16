import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cinemuse_app/features/profile/application/profile_providers.dart';
import 'package:cinemuse_app/features/media/data/tmdb_service.dart';
import 'package:cinemuse_app/features/media/domain/search_result.dart';
import 'package:cinemuse_app/core/services/system/connectivity_service.dart';
import 'package:cinemuse_app/features/search/application/search_provider.dart';
import 'package:cinemuse_app/features/search/application/search_state.dart';
import 'package:cinemuse_app/features/search/presentation/search_overlay.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/settings/domain/user_settings.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/media_card.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cinemuse_app/core/application/provider_retry.dart';

class MockTmdbService extends Mock implements TmdbService {}

class FakeSettingsNotifier extends SettingsNotifier {
  FakeSettingsNotifier([this.initial = const UserSettings()]);

  final UserSettings initial;

  @override
  UserSettings build() => initial;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockTmdbService mockTmdbService;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'search_history_u1': ['Inception', 'Interstellar', 'Batman'],
    });
    mockTmdbService = MockTmdbService();
  });

  Widget createTestWidget({
    SearchState? initialState,
    ConnectivityResult Function()? connectivity,
    Widget home = const Scaffold(body: SearchOverlay()),
  }) {
    return ProviderScope(
      retry: noProviderRetry,
      overrides: [
        tmdbServiceProvider.overrideWithValue(mockTmdbService),
        userIdProvider.overrideWithValue('u1'),
        connectivityProvider.overrideWith(
          (ref) =>
              Stream.value(connectivity?.call() ?? ConnectivityResult.wifi),
        ),
        settingsProvider.overrideWith(FakeSettingsNotifier.new),
        if (initialState != null)
          searchProvider.overrideWithBuild((ref, notifier) {
            notifier.build();
            return initialState;
          }),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );
  }

  testWidgets('TextField requests focus on mount and shows history items', (
    tester,
  ) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Inception'), findsOneWidget);
    expect(find.text('Interstellar'), findsOneWidget);
    expect(find.text('Batman'), findsOneWidget);
    // Remote users' only delete hint: shown for everyone now.
    expect(find.textContaining('Hold to delete'), findsOneWidget);

    // Verify TextField has focus
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.focusNode?.hasFocus, isTrue);
  });

  testWidgets(
    'Offline shows the error box; Retry checks the connection again',
    (tester) async {
      var result = ConnectivityResult.none;
      await tester.pumpWidget(createTestWidget(connectivity: () => result));
      await tester.pumpAndSettle();

      expect(find.text('Inception'), findsNothing);
      expect(find.text('Retry'), findsOneWidget);

      result = ConnectivityResult.wifi;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsNothing);
      expect(find.text('Inception'), findsOneWidget);
    },
  );

  testWidgets(
    'ArrowDown from TextField transfers focus to first history item, ArrowUp returns to TextField',
    (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.focusNode?.hasFocus, isTrue);

      // Press ArrowDown
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      // TextField should lose focus
      expect(textField.focusNode?.hasFocus, isFalse);

      // Press ArrowUp to return to TextField
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();

      expect(textField.focusNode?.hasFocus, isTrue);
    },
  );

  group('the back arrow, hidden on the keys', () {
    bool arrowShown(WidgetTester tester) => tester
        .widget<Visibility>(
          find
              .ancestor(
                of: find.byIcon(LucideIcons.arrowLeft),
                matching: find.byType(Visibility),
              )
              .first,
        )
        .visible;

    Future<void> moveMouse(WidgetTester tester) async {
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(400, 400));
      await mouse.moveBy(const Offset(100, 0));
      await mouse.removePointer();
      await tester.pump();
    }

    /// The overlay opened over a page, as in the app.
    Future<void> pumpOpen(WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(home: const Scaffold(body: Text('Page below'))),
      );
      await tester.pumpAndSettle();
      unawaited(
        tester
            .state<NavigatorState>(find.byType(Navigator))
            .push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: SearchOverlay()),
              ),
            ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SearchOverlay), findsOneWidget);
    }

    testWidgets('Left from the empty box stays in it', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      final textField = tester.widget<TextField>(find.byType(TextField));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();

      expect(arrowShown(tester), isFalse);
      expect(textField.focusNode?.hasFocus, isTrue);
    });

    testWidgets('the mouse brings it back, and a click closes the search', (
      tester,
    ) async {
      await pumpOpen(tester);
      await moveMouse(tester);

      await tester.tap(find.byIcon(LucideIcons.arrowLeft));
      await tester.pumpAndSettle();

      expect(find.byType(SearchOverlay), findsNothing);
      expect(find.text('Page below'), findsOneWidget);
    });

    for (final (name, pressKey) in [
      ('Esc', () => simulateKeyDownEvent(LogicalKeyboardKey.escape)),
      (
        "the remote's Back",
        // Flutter's test keys have no Android scan code for it: sent as the
        // web names it, the app sees the same Back key.
        () => simulateKeyDownEvent(
          LogicalKeyboardKey.goBack,
          physicalKey: PhysicalKeyboardKey.browserBack,
          platform: 'web',
        ),
      ),
    ]) {
      testWidgets('$name closes the search', (tester) async {
        await pumpOpen(tester);

        await pressKey();
        await tester.pumpAndSettle();

        expect(find.byType(SearchOverlay), findsNothing);
        expect(find.text('Page below'), findsOneWidget);
      });
    }
  });

  testWidgets(
    'Typing text shows Clear button; ArrowRight at end of text focuses Clear button; Enter on Clear button clears text and refocuses TextField',
    (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Dune');
      await tester.pumpAndSettle();

      // Clear button (x) should now be visible
      expect(find.byTooltip('Clear All'), findsOneWidget);

      // Move cursor to end of text
      textField.controller?.selection = const TextSelection.collapsed(
        offset: 4,
      );

      // Press ArrowRight to focus Clear button
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      expect(textField.focusNode?.hasFocus, isFalse);

      // Press Enter to activate Clear button
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // Text should now be empty and TextField should have focus again
      expect(textField.controller?.text, isEmpty);
      expect(textField.focusNode?.hasFocus, isTrue);
    },
  );

  testWidgets(
    'ArrowDown from TextField focuses first result card; ArrowUp from first row card returns to TextField',
    (tester) async {
      final searchState = SearchState(
        query: 'Matrix',
        status: SearchStatus.loaded,
        results: [
          for (final result in [
            {
              'id': 603,
              'title': 'The Matrix',
              'media_type': 'movie',
              'poster_path': null,
              'vote_average': 8.7,
            },
            {
              'id': 604,
              'title': 'The Matrix Reloaded',
              'media_type': 'movie',
              'poster_path': null,
              'vote_average': 7.2,
            },
          ])
            SearchResult.fromTmdbMap(result),
        ],
        hasMore: false,
        searchHistory: ['Inception'],
      );

      await tester.pumpWidget(createTestWidget(initialState: searchState));
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.focusNode?.hasFocus, isTrue);

      // Press ArrowDown to navigate to first card
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      expect(textField.focusNode?.hasFocus, isFalse);

      // Press ArrowUp to return to TextField
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();

      expect(textField.focusNode?.hasFocus, isTrue);
    },
  );

  testWidgets('Long press on history item removes it from search history', (
    tester,
  ) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Inception'), findsOneWidget);

    // Navigate to Inception
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    // Context key (Gamepad X) triggers long press
    await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonX);
    await tester.pumpAndSettle();

    // Inception should be removed from the list
    expect(find.text('Inception'), findsNothing);
    expect(find.text('Interstellar'), findsOneWidget);
  });

  testWidgets('ArrowRight navigates across columns in GridView', (
    tester,
  ) async {
    final searchState = SearchState(
      query: 'Matrix',
      status: SearchStatus.loaded,
      results: List.generate(
        8,
        (i) => SearchResult.fromTmdbMap({
          'id': 100 + i,
          'title': 'Matrix $i',
          'media_type': 'movie',
          'poster_path': null,
          'vote_average': 8.0,
        }),
      ),
      hasMore: false,
    );

    await tester.pumpWidget(createTestWidget(initialState: searchState));
    await tester.pumpAndSettle();

    // Go down to first card (Card 0)
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<MediaCard>()
          ?.title,
      equals('Matrix 0'),
    );

    // From card 0, go right to card 1
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<MediaCard>()
          ?.title,
      equals('Matrix 1'),
    );

    // From card 1, go right to card 2
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<MediaCard>()
          ?.title,
      equals('Matrix 2'),
    );

    // From card 2, go right to card 3
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<MediaCard>()
          ?.title,
      equals('Matrix 3'),
    );
  });
}
