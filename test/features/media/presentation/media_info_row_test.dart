import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/external_links.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/gallery_box.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/media_info_row.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestableWidget(
    Widget child, {
    Size surfaceSize = const Size(1280, 800),
  }) {
    return ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(size: surfaceSize),
          child: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(width: surfaceSize.width, child: child),
            ),
          ),
        ),
      ),
    );
  }

  final sampleDetailsFull = {
    'id': 12345,
    'title': 'Test Movie',
    'images': {
      'backdrops': [
        {'file_path': '/backdrop1.jpg'},
      ],
      'posters': [
        {'file_path': '/poster1.jpg'},
      ],
      'logos': [
        {'file_path': '/logo1.jpg'},
      ],
    },
    'reviews': {
      'results': [
        {
          'author': 'Critic Jane',
          'content':
              'An incredible cinematic masterpiece with stunning visuals.',
        },
      ],
    },
    'external_ids': {
      'imdb_id': 'tt1234567',
      'wikidata_id': 'Q12345',
      'instagram_id': 'testmovie',
    },
    'homepage': 'https://example.com',
  };

  final sampleDetailsNoLinks = {
    'id': 67890,
    'name': 'Test Series',
    'images': {
      'backdrops': [
        {'file_path': '/backdrop1.jpg'},
      ],
      'posters': [
        {'file_path': '/poster1.jpg'},
      ],
      'logos': <dynamic>[],
    },
    'reviews': {
      'results': [
        {'author': 'Reviewer Bob', 'content': 'Great plot twists and pacing.'},
      ],
    },
    'external_ids': null,
    'homepage': null,
  };

  group('MediaInfoRow Widget Tests', () {
    testWidgets('renders 2 columns (Gallery, Links) in a single row', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          MediaInfoRow(
            mediaItem: MediaItem.fromTmdbDetails(
              sampleDetailsFull,
              MediaKind.movie,
            ),
            typeForTmdb: 'movie',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GalleryBox), findsOneWidget);
      expect(find.byType(ExternalLinks), findsOneWidget);

      // Verify that they are inside an IntrinsicHeight Row on widescreen
      final rowFinder = find.ancestor(
        of: find.byType(GalleryBox),
        matching: find.byType(Row),
      );
      expect(rowFinder, findsOneWidget);

      // Verify Row contains all 2 columns
      final rowWidget = tester.widget<Row>(rowFinder);
      expect(rowWidget.children.whereType<Expanded>().length, equals(2));
    });

    testWidgets(
      'flexes into a 1-column layout (Gallery) when links are absent',
      (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(
            MediaInfoRow(
              mediaItem: MediaItem.fromTmdbDetails(
                sampleDetailsNoLinks,
                MediaKind.tv,
              ),
              typeForTmdb: 'tv',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(GalleryBox), findsOneWidget);
        expect(find.byType(ExternalLinks), findsNothing);

        // Verify Row has exactly 1 Expanded column
        final rowFinder = find.ancestor(
          of: find.byType(GalleryBox),
          matching: find.byType(Row),
        );
        expect(rowFinder, findsOneWidget);

        final rowWidget = tester.widget<Row>(rowFinder);
        expect(rowWidget.children.whereType<Expanded>().length, equals(1));
      },
    );

    testWidgets(
      'stacks vertically in Column when available width is narrow (< 650px)',
      (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(
            MediaInfoRow(
              mediaItem: MediaItem.fromTmdbDetails(
                sampleDetailsFull,
                MediaKind.movie,
              ),
              typeForTmdb: 'movie',
            ),
            surfaceSize: const Size(400, 800),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(GalleryBox), findsOneWidget);
        expect(find.byType(ExternalLinks), findsOneWidget);

        // Should be inside a Column
        final columnFinder = find.ancestor(
          of: find.byType(GalleryBox),
          matching: find.byType(Column),
        );
        expect(columnFinder, findsWidgets);
      },
    );

    testWidgets(
      'spatial navigation allows D-Pad navigation between Gallery and Links',
      (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(
            MediaInfoRow(
              mediaItem: MediaItem.fromTmdbDetails(
                sampleDetailsFull,
                MediaKind.movie,
              ),
              typeForTmdb: 'movie',
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find focus nodes in Gallery and Links
        final galleryFocus = tester.widgetList<Focus>(
          find.descendant(
            of: find.byType(GalleryBox),
            matching: find.byType(Focus),
          ),
        );
        expect(galleryFocus, isNotEmpty);

        final linksFocus = tester.widgetList<Focus>(
          find.descendant(
            of: find.byType(ExternalLinks),
            matching: find.byType(Focus),
          ),
        );
        expect(linksFocus, isNotEmpty);

        // Focus on the first element in Gallery
        galleryFocus.first.focusNode?.requestFocus();
        await tester.pumpAndSettle();
        expect(
          FocusManager.instance.primaryFocus,
          galleryFocus.first.focusNode,
        );

        // Focus on Links item directly
        linksFocus.first.focusNode?.requestFocus();
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus, linksFocus.first.focusNode);
      },
    );
  });
}
