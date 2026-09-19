import 'package:cinemuse_app/core/application/display_mode_provider.dart';
import 'package:cinemuse_app/core/services/media/tmdb_service.dart';
import 'package:cinemuse_app/core/services/system/connectivity_service.dart';
import 'package:cinemuse_app/features/search/application/search_provider.dart';
import 'package:cinemuse_app/features/search/application/search_state.dart';
import 'package:cinemuse_app/features/search/presentation/search_overlay.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/media_card.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockTmdbService extends Mock implements TmdbService {}

class FakeSettingsNotifier extends StateNotifier<UserSettings>
    implements SettingsNotifier {
  FakeSettingsNotifier() : super(const UserSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockTmdbService mockTmdbService;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'global_search_history': ['Inception', 'Interstellar', 'Batman'],
    });
    mockTmdbService = MockTmdbService();
  });

  Widget createTestWidget({
    SearchState? initialState,
    DisplayMode displayMode = DisplayMode.bigPicture,
  }) {
    return ProviderScope(
      overrides: [
        tmdbServiceProvider.overrideWithValue(mockTmdbService),
        connectivityProvider.overrideWith(
          (ref) => Stream.value(ConnectivityResult.wifi),
        ),
        displayModeProvider.overrideWith((ref) {
          final notifier = DisplayModeNotifier();
          notifier.setMode(displayMode);
          return notifier;
        }),
        settingsProvider.overrideWith((ref) => FakeSettingsNotifier()),
        if (initialState != null)
          searchProvider.overrideWith((ref) {
            final notifier = SearchNotifier(ref);
            notifier.state = initialState;
            return notifier;
          }),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SearchOverlay(),
        ),
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

    // Verify TextField has focus
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.focusNode?.hasFocus, isTrue);
  });

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

  testWidgets(
    'ArrowLeft from empty TextField moves focus to Back button, and ArrowRight returns to TextField',
    (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.focusNode?.hasFocus, isTrue);

      // Press ArrowLeft
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();

      expect(textField.focusNode?.hasFocus, isFalse);

      // Press ArrowRight from Back button to return to TextField
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      expect(textField.focusNode?.hasFocus, isTrue);
    },
  );

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

  testWidgets('ArrowRight navigates across columns in GridView', (tester) async {
    final searchState = SearchState(
      query: 'Matrix',
      status: SearchStatus.loaded,
      results: List.generate(
        8,
        (i) => {
          'id': 100 + i,
          'title': 'Matrix $i',
          'media_type': 'movie',
          'poster_path': null,
          'vote_average': 8.0,
        },
      ),
      hasMore: false,
    );

    await tester.pumpWidget(createTestWidget(initialState: searchState));
    await tester.pumpAndSettle();

    // Go down to first card (Card 0)
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<MediaCard>()?.title,
      equals('Matrix 0'),
    );

    // From card 0, go right to card 1
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<MediaCard>()?.title,
      equals('Matrix 1'),
    );

    // From card 1, go right to card 2
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<MediaCard>()?.title,
      equals('Matrix 2'),
    );

    // From card 2, go right to card 3
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<MediaCard>()?.title,
      equals('Matrix 3'),
    );
  });
}
