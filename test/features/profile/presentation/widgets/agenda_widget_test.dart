import 'package:cinemuse_app/core/application/l10n_provider.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/services/system/connectivity_service.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/profile/application/agenda_providers.dart';
import 'package:cinemuse_app/features/profile/domain/agenda_event.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/agenda_widget.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/cursor_helpers.dart';

void main() {
  // REV-246: an agenda item showed the arrow cursor.
  testWidgets('an agenda item: the hand', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          agendaProvider.overrideWith(
            (ref) async => {
              AgendaGroup.today: [
                AgendaEvent(
                  id: 'movie_1',
                  tmdbId: 1,
                  title: 'Some Movie',
                  releaseDate: DateTime.now(),
                  type: MediaKind.movie,
                ),
              ],
            },
          ),
          connectivityProvider.overrideWith(
            (ref) => Stream.value(ConnectivityResult.wifi),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: AgendaWidget(isExpanded: true)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await expectHandOver(tester, find.text('Some Movie'));
  });

  group('errors show Retry (REV-237)', () {
    final l10n = AppLocalizationsEn();

    Future<void> pumpAgenda(
      WidgetTester tester, {
      required Future<Map<AgendaGroup, List<AgendaEvent>>> Function() load,
      ConnectivityResult connection = ConnectivityResult.wifi,
    }) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            agendaProvider.overrideWith((ref) => load()),
            connectivityProvider.overrideWith(
              (ref) => Stream.value(connection),
            ),
            localizationsProvider.overrideWithValue(l10n),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: AgendaWidget(isExpanded: true)),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('a load error: its text and a Retry that loads again', (
      tester,
    ) async {
      var loads = 0;
      await pumpAgenda(
        tester,
        load: () async {
          loads++;
          throw const ServerFailure('dev text');
        },
      );

      expect(find.text(l10n.failureServer), findsOneWidget);
      await tester.tap(find.text(l10n.commonRetry));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(loads, 2);
    });

    testWidgets('offline: the offline text and a Retry', (tester) async {
      await pumpAgenda(
        tester,
        load: () async => {},
        connection: ConnectivityResult.none,
      );

      expect(find.text(l10n.offlineScreenTitle), findsOneWidget);
      expect(find.text(l10n.commonRetry), findsOneWidget);
    });
  });
}
