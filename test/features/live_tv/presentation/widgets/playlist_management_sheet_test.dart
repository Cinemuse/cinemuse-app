import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/data/live_tv_repository.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/epg_program.dart';
import 'package:cinemuse_app/features/live_tv/domain/live_tv_guide.dart';
import 'package:cinemuse_app/features/live_tv/domain/live_tv_playlist.dart';
import 'package:cinemuse_app/features/live_tv/domain/live_tv_source.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/playlist_management_sheet.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/setting_toggle.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:cinemuse_app/core/application/provider_retry.dart';

/// A guide download that ends when the test says so, and the failures the
/// test sets; never calls a server.
class _SlowEpgRepository extends LiveTvRepository {
  _SlowEpgRepository() : super(Dio());

  final download = Completer<void>();
  var playlistFailures = <String, LiveTvSourceFailure>{};
  var guideFailures = <String, LiveTvSourceFailure>{};

  @override
  Future<LiveTvLoad<List<Channel>>> fetchChannels({
    List<LiveTvPlaylist>? playlists,
  }) async => LiveTvLoad(const [], failures: playlistFailures);

  @override
  Future<LiveTvLoad<Map<String, List<EpgProgram>>>> fetchEpg({
    required List<LiveTvGuide> guides,
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) await download.future;
    return LiveTvLoad(const {}, failures: guideFailures);
  }
}

/// Saving a playlist fails, as it would offline.
class _FailingPlaylists extends PlaylistsNotifier {
  @override
  Future<void> add(LiveTvPlaylist playlist) async =>
      throw const UnknownFailure('save failed');
}

/// Saving a guide fails.
class _FailingGuides extends GuidesNotifier {
  @override
  Future<void> add(LiveTvGuide guide) async =>
      throw const UnknownFailure('save failed');
}

void main() {
  late _SlowEpgRepository repository;

  Future<void> pumpSection(
    WidgetTester tester, {
    List<LiveTvPlaylist> playlists = const [],
    List<LiveTvGuide> guides = const [],
    List<Override> overrides = const [],
    Map<String, LiveTvSourceFailure> playlistFailures = const {},
    Map<String, LiveTvSourceFailure> guideFailures = const {},
  }) async {
    SharedPreferences.setMockInitialValues({
      'live_tv_custom_playlists': [for (final p in playlists) p.encode()],
      'live_tv_custom_guides': [for (final g in guides) g.encode()],
    });
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    repository = _SlowEpgRepository()
      ..playlistFailures = playlistFailures
      ..guideFailures = guideFailures;
    await tester.pumpWidget(
      ProviderScope(
        retry: noProviderRetry,
        overrides: [
          liveTvRepositoryProvider.overrideWithValue(repository),
          cinemuseGuideUrlProvider.overrideWithValue(
            'https://example.com/cinemuse.json',
          ),
          cinemusePlaylistUrlProvider.overrideWithValue(
            'https://example.com/cinemuse.m3u',
          ),
          ...overrides,
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

  testWidgets('Refresh is off until the downloads end (REV-136)', (
    tester,
  ) async {
    await pumpSection(tester);

    await tester.tap(find.text('Refresh'));
    await tester.pump();
    expect(isEnabled(tester, 'Refresh'), isFalse);
    expect(find.text('Playlists and guides refreshed'), findsNothing);

    repository.download.complete();
    await tester.pumpAndSettle();
    expect(isEnabled(tester, 'Refresh'), isTrue);
    expect(find.text('Playlists and guides refreshed'), findsOneWidget);
  });

  final myIptv = LiveTvPlaylist(
    name: 'My IPTV',
    urlOrPath: 'https://example.com/my.m3u',
    isLocal: false,
    type: PlaylistType.m3u,
  );

  testWidgets('a playlist or guide that failed says why, with an icon by its '
      'name: red when nothing came from it, amber for a saved guide', (
    tester,
  ) async {
    await pumpSection(
      tester,
      playlists: [myIptv],
      playlistFailures: {
        myIptv.id: const LiveTvSourceFailure(NetworkFailure('offline')),
      },
      guideFailures: {
        LiveTvGuide.cinemuseId: const LiveTvSourceFailure(
          ValidationFailure('no programmes'),
          usesSavedCopy: true,
        ),
      },
    );

    expect(
      find.text(
        "Couldn't load: Can't reach the server. Check your connection.",
      ),
      findsOneWidget,
    );
    expect(find.text('example.com'), findsNothing);
    expect(
      find.text(
        "Showing the saved guide. Couldn't update: No programmes found in it.",
      ),
      findsOneWidget,
    );
    expect(find.byIcon(LucideIcons.alertCircle), findsOneWidget);
    expect(find.byIcon(LucideIcons.alertTriangle), findsOneWidget);
    // The rows that loaded keep their usual text.
    expect(find.text('Free-to-air channels'), findsOneWidget);
  });

  testWidgets('a playlist showing its saved channels is amber and says so', (
    tester,
  ) async {
    await pumpSection(
      tester,
      playlists: [myIptv],
      playlistFailures: {
        myIptv.id: const LiveTvSourceFailure(
          ServerFailure('down', statusCode: 503),
          usesSavedCopy: true,
        ),
      },
    );

    expect(
      find.textContaining('Showing the saved channels. Couldn\'t update: '),
      findsOneWidget,
    );
    expect(find.textContaining('503'), findsOneWidget);
    expect(find.byIcon(LucideIcons.alertTriangle), findsOneWidget);
    expect(find.byIcon(LucideIcons.alertCircle), findsNothing);
  });

  testWidgets('a failure answered by the server shows its code', (
    tester,
  ) async {
    await pumpSection(
      tester,
      playlists: [myIptv],
      playlistFailures: {
        myIptv.id: const LiveTvSourceFailure(
          ServerFailure('not found', statusCode: 404),
        ),
      },
    );

    expect(
      find.text("Couldn't load: The server returned an error (404)."),
      findsOneWidget,
    );
  });

  testWidgets('Refresh names what still failed instead of "refreshed"', (
    tester,
  ) async {
    await pumpSection(tester, playlists: [myIptv]);
    repository
      ..playlistFailures = {
        myIptv.id: const LiveTvSourceFailure(NetworkFailure('offline')),
      }
      ..guideFailures = {
        LiveTvGuide.cinemuseId: const LiveTvSourceFailure(
          NetworkFailure('offline'),
        ),
      };

    await tester.tap(find.text('Refresh'));
    repository.download.complete();
    await tester.pumpAndSettle();

    expect(
      find.text("Couldn't load: My IPTV (playlist), Cinemuse IPTV (EPG)"),
      findsOneWidget,
    );
    expect(find.text('Playlists and guides refreshed'), findsNothing);
  });

  testWidgets('a playlist row shows only the site, not the login (REV-137)', (
    tester,
  ) async {
    await pumpSection(
      tester,
      playlists: [
        LiveTvPlaylist(
          name: 'My IPTV',
          urlOrPath:
              'http://example.com:8080/get.php?username=me&password=secret',
          isLocal: false,
          type: PlaylistType.m3u,
        ),
      ],
    );

    expect(find.text('My IPTV'), findsOneWidget);
    expect(find.text('example.com'), findsOneWidget);
    expect(find.textContaining('secret'), findsNothing);
  });

  testWidgets('the Cinemuse playlist can be turned off, not removed '
      '(REV-336)', (tester) async {
    await pumpSection(
      tester,
      playlists: [
        LiveTvPlaylist(
          name: 'My IPTV',
          urlOrPath: 'https://example.com/my.m3u',
          isLocal: false,
          type: PlaylistType.m3u,
        ),
      ],
    );

    // One Cinemuse row in each list: the playlist and the guide.
    expect(find.text('Cinemuse IPTV'), findsNWidgets(2));
    expect(find.text('Built-in'), findsNWidgets(2));
    expect(find.text('Free-to-air channels'), findsOneWidget);
    expect(find.text('Guide of the free-to-air channels'), findsOneWidget);
    expect(find.byType(SettingToggle), findsNWidgets(3));
    // Only the user's own playlist has them.
    expect(find.byTooltip('Remove'), findsOneWidget);
    expect(find.byTooltip('Open Link'), findsOneWidget);
  });

  testWidgets('a removed playlist goes at once, with Undo; Undo puts it '
      'back in its place', (tester) async {
    LiveTvPlaylist playlist(String name) => LiveTvPlaylist(
      name: name,
      urlOrPath: 'https://example.com/$name.m3u',
      isLocal: false,
      type: PlaylistType.m3u,
    );
    await pumpSection(
      tester,
      playlists: [playlist('First IPTV'), playlist('Second IPTV')],
    );

    await tester.tap(find.byTooltip('Remove').first);
    await tester.pumpAndSettle();
    expect(find.text('First IPTV'), findsNothing);
    expect(find.text('First IPTV removed (4)'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    double top(String name) => tester.getTopLeft(find.text(name)).dy;
    expect(top('First IPTV'), lessThan(top('Second IPTV')));
  });

  for (final (url, canCreate) in [
    ('abc', false),
    (' https://example.com/x.m3u ', true),
  ]) {
    testWidgets('Add URL: "$url" → Create ${canCreate ? 'on' : 'off'} '
        '(REV-136)', (tester) async {
      await pumpSection(tester);
      await tester.tap(find.text('Add URL').first);
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
  testWidgets('a guide row is a playlist row: site only, badge, switch, '
      'open and remove', (tester) async {
    await pumpSection(
      tester,
      guides: [
        LiveTvGuide(
          name: 'My guide',
          urlOrPath: 'http://epg.example.com/xmltv.php?username=me&password=x1',
          isLocal: false,
        ),
      ],
    );

    expect(find.text('My guide'), findsOneWidget);
    expect(find.text('epg.example.com'), findsOneWidget);
    expect(find.textContaining('x1'), findsNothing);
    expect(find.text('XMLTV URL'), findsOneWidget);
    expect(find.byType(SettingToggle), findsNWidgets(3));
    expect(find.byTooltip('Remove'), findsOneWidget);
    expect(find.byTooltip('Open Link'), findsOneWidget);
  });

  testWidgets('the guide link form has no format box', (tester) async {
    await pumpSection(tester);
    await tester.tap(find.text('Add URL').last);
    await tester.pumpAndSettle();

    expect(find.text('Add Remote Guide'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Guide Name'), findsOneWidget);
    expect(find.text('Format'), findsNothing);
  });

  // REV-261: a failed save shows under the box, the dialog stays open.
  const saveError = 'Error saving: Something went wrong.';
  for (final (name, override, fill) in [
    (
      'Add URL',
      playlistsProvider.overrideWith(_FailingPlaylists.new),
      (WidgetTester tester) async {
        await tester.tap(find.text('Add URL').first);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, 'Playlist Name'),
          'My list',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Playlist URL'),
          'https://example.com/x.m3u',
        );
        await tester.pump();
        await tester.tap(find.text('Create'));
      },
    ),
    (
      'Add guide URL',
      guidesProvider.overrideWith(_FailingGuides.new),
      (WidgetTester tester) async {
        await tester.tap(find.text('Add URL').last);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, 'Guide Name'),
          'My guide',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Guide URL'),
          'https://example.com/guide.xml',
        );
        await tester.pump();
        await tester.tap(find.text('Create'));
      },
    ),
  ]) {
    testWidgets('$name: a failed save shows under the box', (tester) async {
      await pumpSection(tester, overrides: [override]);
      await fill(tester);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      final error = find.descendant(
        of: find.byType(TextField),
        matching: find.text(saveError),
      );
      expect(error, findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);

      // Typing again clears it.
      await tester.enterText(find.byType(TextField).last, 'https://e.com/y');
      await tester.pump();
      expect(error, findsNothing);
    });
  }
}
