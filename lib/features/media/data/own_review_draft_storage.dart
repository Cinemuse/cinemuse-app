import 'dart:convert';

import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:cinemuse_app/features/media/domain/own_review.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final ownReviewDraftStorageProvider = Provider<OwnReviewDraftStorage>(
  (ref) => OwnReviewDraftStorage(),
);

/// Unsaved ratings and reviews, one per title and per account, on this device
/// only. A failure here only logs: the user is still typing, and the text on
/// screen is safe.
class OwnReviewDraftStorage {
  static const _logTag = 'OwnReviewDraftStorage';

  String _key(String userId, RatedTitle title) =>
      'own_review_draft_${userId}_${title.mediaType.name}-${title.tmdbId}';

  Future<OwnReviewDraft?> read(String userId, RatedTitle title) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_key(userId, title));
      return stored == null
          ? null
          : OwnReviewDraft.fromJson(jsonDecode(stored));
    } catch (e) {
      AppLogger.warn(_logTag, 'Unsaved review unreadable', error: e);
      return null;
    }
  }

  Future<void> write(
    String userId,
    RatedTitle title,
    OwnReviewDraft draft,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key(userId, title), jsonEncode(draft.toJson()));
    } catch (e) {
      AppLogger.warn(_logTag, 'Unsaved review not kept', error: e);
    }
  }

  Future<void> remove(String userId, RatedTitle title) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(userId, title));
    } catch (e) {
      AppLogger.warn(_logTag, 'Unsaved review not deleted', error: e);
    }
  }
}
