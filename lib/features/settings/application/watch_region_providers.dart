import 'package:cinemuse_app/features/media/data/tmdb_service.dart';
import 'package:cinemuse_app/features/media/domain/watch_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_service.dart';

/// The user's streaming country (`UserSettings.watchRegion`), on its own so
/// Explore re-runs only when it changes.
final watchRegionProvider = Provider<String>(
  (ref) => ref.watch(settingsProvider.select((s) => s.watchRegion)),
);

/// The countries TMDB has streaming data for, sorted by their name in the
/// app's language.
final watchRegionsProvider = FutureProvider.autoDispose<List<WatchRegion>>((
  ref,
) async {
  final regions = await ref.watch(tmdbServiceProvider).getWatchRegions();
  return [...regions]..sort((a, b) => a.name.compareTo(b.name));
});
