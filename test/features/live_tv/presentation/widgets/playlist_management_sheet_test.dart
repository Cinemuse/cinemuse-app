import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cinemuse_app/features/live_tv/application/custom_epg_url_notifier.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/data/live_tv_repository.dart';
import 'package:cinemuse_app/features/live_tv/domain/epg_program.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/playlist_management_sheet.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

const _defaultUrl = 'https://example.com/epg.json';

/// A guide download that ends when the test says so; never calls a server.
class _SlowEpgRepository extends LiveTvRepository {
  _SlowEpgRepository() : super(Dio(), defaultEpgUrl: _defaultUrl);

  final download = Completer<void>();

  @override
  Future<Map<String, List<EpgProgram>>> fetchEpg({
    String? url,
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) await download.future;
    return {};
  }
}

void main() {
  late _SlowEpgRepository repository;

  Future<void> pumpSection(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    repository = _SlowEpgRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          liveTvRepositoryProvider.overrideWithValue(repository),
          defaultEpgUrlProvider.overrideWithValue(_defaultUrl),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: SingleChildScrollView(child: PlaylistListSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool isEnabled(WidgetTester tester, String label) => tester
      .widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      )
      .enabled;

  testWidgets('Refresh Guide is off until the download ends (REV-136)', (
    tester,
  ) async {
    await pumpSection(tester);

    await tester.tap(find.text('Refresh Guide'));
    await tester.pump();
    expect(isEnabled(tester, 'Refresh Guide'), isFalse);
    expect(find.text('EPG guide refreshed successfully'), findsNothing);

    repository.download.complete();
    await tester.pumpAndSettle();
    expect(isEnabled(tester, 'Refresh Guide'), isTrue);
    expect(find.text('EPG guide refreshed successfully'), findsOneWidget);
  });

  for (final (url, canCreate) in [
    ('abc', false),
    (' https://example.com/x.m3u ', true),
  ]) {
    testWidgets('Add URL: "$url" → Create ${canCreate ? 'on' : 'off'} '
        '(REV-136)', (tester) async {
      await pumpSection(tester);
      await tester.tap(find.text('Add URL'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Playlist Name'),
        'My list',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Playlist URL'),
        url,
      );
      await tester.pump();

      expect(isEnabled(tester, 'Create'), canCreate);
    });
  }
}
