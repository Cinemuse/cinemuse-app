import 'package:cinemuse_app/features/media/data/tmdb_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_service.dart';

/// The user's streaming country (`UserSettings.watchRegion`), on its own so
/// Explore re-runs only when it changes.
final watchRegionProvider = Provider<String>(
  (ref) => ref.watch(settingsProvider.select((s) => s.watchRegion)),
);

/// A country in the "Streaming country" setting.
typedef WatchRegion = ({String code, String name});

/// The countries TMDB has streaming data for, sorted by their name in the
/// app's language.
final watchRegionsProvider = FutureProvider.autoDispose<List<WatchRegion>>((
  ref,
) async {
  final results = await ref.watch(tmdbServiceProvider).getWatchRegions();
  final regions = [
    for (final r in results)
      if (r['iso_3166_1'] case final String code)
        (
          code: code,
          name: (r['native_name'] ?? r['english_name'] ?? code) as String,
        ),
  ]..sort((a, b) => a.name.compareTo(b.name));
  return regions;
});
