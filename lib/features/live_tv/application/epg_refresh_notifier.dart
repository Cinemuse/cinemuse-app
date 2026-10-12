import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/features/live_tv/application/custom_epg_url_notifier.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';

/// "Refresh EPG": downloads the guide again, skipping the cache. The state
/// is `true` while a download runs, so the button can't start a second one
/// (REV-136).
class EpgRefreshNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  Future<void> refresh() async {
    if (state) return;
    state = true;
    try {
      await ref
          .read(liveTvRepositoryProvider)
          .fetchEpg(url: ref.read(activeEpgUrlProvider), forceRefresh: true);
      ref.invalidate(epgDataProvider);
    } finally {
      state = false;
    }
  }
}

// Not autoDispose: a download keeps going if the sheet is closed, and must
// still clear the flag when it ends.
final epgRefreshProvider = NotifierProvider<EpgRefreshNotifier, bool>(
  EpgRefreshNotifier.new,
);
