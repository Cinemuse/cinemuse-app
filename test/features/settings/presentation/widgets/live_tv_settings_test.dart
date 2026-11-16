import 'package:cinemuse_app/core/application/provider_retry.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/domain/live_tv_guide.dart';
import 'package:cinemuse_app/features/live_tv/domain/live_tv_playlist.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/settings/domain/user_settings.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/live_tv_settings.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Keeps the settings in memory: a save only changes the state.
class _MemorySettings extends SettingsNotifier {
  @override
  UserSettings build() => const UserSettings();

  @override
  Future<void> updateSettings(
    UserSettings Function(UserSettings current) change,
  ) async {
    state = change(state);
  }
}

class _NoPlaylists extends PlaylistsNotifier {
  @override
  List<LiveTvPlaylist> build() => const [];
}

class _NoGuides extends GuidesNotifier {
  @override
  List<LiveTvGuide> build() => const [];
}

void main() {
  Future<ProviderContainer> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: noProviderRetry,
        overrides: [
          settingsProvider.overrideWith(_MemorySettings.new),
          playlistsProvider.overrideWith(_NoPlaylists.new),
          guidesProvider.overrideWith(_NoGuides.new),
          playlistFailuresProvider.overrideWithValue(const {}),
          guideFailuresProvider.overrideWithValue(const {}),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: SingleChildScrollView(child: LiveTvSettings()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(LiveTvSettings)),
    );
  }

  testWidgets('the rewind length is the only buffer setting', (tester) async {
    await pumpPage(tester);

    expect(find.text('Rewind length'), findsOneWidget);
    expect(find.text('5 min'), findsOneWidget);
    expect(find.text('DVR Buffer Size'), findsNothing);
    expect(find.text('Enable Disk Caching'), findsNothing);
  });

  testWidgets('picking a rewind length saves it', (tester) async {
    final container = await pumpPage(tester);

    await tester.tap(find.text('5 min'));
    await tester.pumpAndSettle();
    for (final minutes in UserSettings.liveTvRewindChoices) {
      expect(find.text('$minutes min'), findsWidgets);
    }
    await tester.tap(find.text('15 min').last);
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).liveTvRewindMinutes, 15);
  });
}
