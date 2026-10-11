import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Downloads the signed-in user's watch history and lists again
/// (pull-to-refresh on Home, Profile and the details screen).
class UserDataSyncService {
  final Ref _ref;

  UserDataSyncService(this._ref);

  /// Syncs both; throws the first failure after both have finished.
  /// Does nothing when nobody is signed in.
  Future<void> syncNow() async {
    final userId = _ref.read(authProvider).value?.id;
    if (userId == null) return;
    await Future.wait([
      _ref.read(watchHistoryRepositoryProvider).syncWatchHistory(userId),
      _ref.read(listsRepositoryProvider).syncUserLists(userId),
    ]);
  }
}

// Not autoDispose: it holds no data, and syncNow is read once from a
// callback (an autoDispose provider would be disposed during the await).
final userDataSyncServiceProvider = Provider<UserDataSyncService>(
  UserDataSyncService.new,
);
