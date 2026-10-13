import 'package:cinemuse_app/features/media/domain/episode_item.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/episodes/season_selector.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// REV-204: a new GlobalKey on every build threw the selector away, so focus
// was lost whenever the episodes section rebuilt (e.g. after picking a season).
void main() {
  final seasons = [
    SeasonSummary.fromTmdbMap(const {'season_number': 1, 'episode_count': 8}),
    SeasonSummary.fromTmdbMap(const {'season_number': 2, 'episode_count': 8}),
  ];

  Widget app(int selected) => ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SeasonSelector(
          seasons: seasons,
          selectedSeason: selected,
          mediaId: '1429',
        ),
      ),
    ),
  );

  bool focusIsInSelector() {
    final focused = FocusManager.instance.primaryFocus?.context;
    return focused != null &&
        focused.findAncestorWidgetOfExactType<SeasonSelector>() != null;
  }

  testWidgets('keeps focus when rebuilt with another season', (tester) async {
    await tester.pumpWidget(app(1));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final focused = FocusManager.instance.primaryFocus;
    expect(focusIsInSelector(), isTrue);

    await tester.pumpWidget(app(2));
    await tester.pump();

    expect(FocusManager.instance.primaryFocus, same(focused));
    expect(find.text('Season 2'), findsOneWidget);
  });

  testWidgets('is a single focus stop', (tester) async {
    await tester.pumpWidget(app(1));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final first = FocusManager.instance.primaryFocus;

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    // Tab wraps around to the same node: there is no second stop inside.
    expect(FocusManager.instance.primaryFocus, same(first));
  });
}
