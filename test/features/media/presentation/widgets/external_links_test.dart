import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/external_links.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// REV-214: a link that couldn't open did nothing.
void main() {
  final l10n = AppLocalizationsEn();

  testWidgets('a person\'s IMDb link that fails to open: a red message', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ExternalLinks(
              ids: ExternalIds(imdbId: 'nm0000001'),
              type: 'person',
              tmdbId: 1,
            ),
          ),
        ),
      ),
    );

    // url_launcher answers "couldn't open" (offline, or no app for it).
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    final launches = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      launches.add(call.method);
      return false;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );

    await tester.tap(find.text('IMDb'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(launches, contains('launch'));

    expect(find.text(l10n.detailsLinkOpenFailed), findsOneWidget);
  });
}
