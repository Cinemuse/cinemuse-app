import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';

/// "Refresh": downloads every playlist and every guide that is on again,
/// the guides skipping their cache. The state is `true` while a download
/// runs, so the button can't start a second one (REV-136).
class LiveTvRefreshNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// Completes with the playlists and guides that still failed.
  Future<FailedLiveTvSources> refresh() async {
    const none = (playlists: <String>[], guides: <String>[]);
    if (state) return none;
    state = true;
    try {
      ref.invalidate(channelsLoadProvider);
      await Future.wait([
        ref.read(channelsLoadProvider.future),
        ref.read(guidesLoadProvider.notifier).refresh(),
      ]);
      return ref.read(failedLiveTvSourcesProvider).value ?? none;
    } finally {
      state = false;
    }
  }
}

// Not autoDispose: a download keeps going if the sheet is closed, and must
// still clear the flag when it ends.
final liveTvRefreshProvider = NotifierProvider<LiveTvRefreshNotifier, bool>(
  LiveTvRefreshNotifier.new,
);
