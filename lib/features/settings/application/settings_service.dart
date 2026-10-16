import 'package:cinemuse_app/features/streaming/stremio_addon_service.dart';
import 'package:cinemuse_app/features/streaming/models/stremio_addon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/features/profile/data/profile_repository.dart';
import 'package:cinemuse_app/features/settings/domain/user_settings.dart';
import 'package:cinemuse_app/core/application/locale_service.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';

class SettingsNotifier extends Notifier<UserSettings> {
  static const _tag = 'SettingsService';

  // The user whose stored settings are in `state`. Null until a load
  // succeeds: until then `state` holds defaults and must not be saved,
  // because every save writes the whole preferences object.
  String? _loadedUserId;
  Future<void>? _loading;

  @override
  UserSettings build() {
    // Reload on account switch.
    ref.listen(authProvider, (previous, next) {
      if (previous?.value?.id != next.value?.id) initSettings();
    });
    // After build: the load sets `state`, which build can't do.
    _loading = Future.microtask(_loadSettings);
    return const UserSettings();
  }

  @visibleForTesting
  Future<void> initSettings() => _loading = _loadSettings();

  Future<void> _loadSettings() async {
    try {
      final user = ref.read(authProvider).value;

      // Account changed: drop the previous user's settings right away.
      if (user?.id != _loadedUserId) {
        _loadedUserId = null;
        state = const UserSettings();
      }
      if (user == null) return;

      final profile = await ref
          .read(profileRepositoryProvider)
          .getProfile(user.id);

      // Ignore a slow load that finishes after an account switch.
      if (ref.read(authProvider).value?.id != user.id) return;

      if (profile != null) {
        state = UserSettings.fromProfile(profile);
        _loadedUserId = user.id;
        // Sync initial app language to localeProvider
        ref.read(localeProvider.notifier).setLocale(state.appLanguage);
      }
    } catch (e, st) {
      // Safe to continue: `_loadedUserId` stays null, so nothing is saved
      // over the stored settings, and the next save retries the load.
      AppLogger.warn(
        _tag,
        'Failed to load settings (offline?). Using defaults.',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Saves the settings [change] returns (callers use `copyWith`). The new
  /// values show at once; if the write fails the old values come back and
  /// the error is rethrown, so the UI can say so (REV-78).
  Future<void> updateSettings(
    UserSettings Function(UserSettings current) change,
  ) async {
    final user = ref.read(authProvider).value;
    if (user == null) return;

    // Never save before this user's settings are loaded, or the defaults
    // would overwrite their stored keys and addons.
    if (_loadedUserId != user.id) {
      await _loading; // a load already in progress
      if (_loadedUserId != user.id) await initSettings(); // one retry
      if (_loadedUserId != user.id) {
        throw const NetworkFailure(
          'Settings are still loading. Check your connection and try again.',
        );
      }
    }

    final previous = state;
    final updated = change(previous);
    state = updated;

    final languageChanged = updated.appLanguage != previous.appLanguage;
    if (languageChanged) {
      ref.read(localeProvider.notifier).setLocale(updated.appLanguage);
    }

    final Map<String, dynamic> dbUpdates = {
      if (updated.displayName != previous.displayName)
        'username': updated.displayName,
      'preferences': updated.toPreferencesJson(),
    };

    try {
      await ref
          .read(profileRepositoryProvider)
          .updateProfile(user.id, dbUpdates);
    } catch (e, st) {
      AppLogger.warn(
        _tag,
        'Saving settings failed; restoring the old values',
        error: e,
        stackTrace: st,
      );
      // Only undo this change if no newer change replaced it meanwhile.
      if (identical(state, updated)) {
        state = previous;
        if (languageChanged) {
          ref.read(localeProvider.notifier).setLocale(previous.appLanguage);
        }
      }
      rethrow;
    }
  }

  Future<void> installAddon(String url) async {
    final addonService = ref.read(stremioAddonServiceProvider);
    final addon = await addonService.fetchManifest(url);

    // Check if already installed
    final currentAddons = [...state.installedAddons];
    currentAddons.removeWhere((a) => a.id == addon.id);
    currentAddons.add(addon);

    await updateSettings((s) => s.copyWith(installedAddons: currentAddons));
  }

  Future<void> removeAddon(String id) async {
    final currentAddons = [...state.installedAddons];
    currentAddons.removeWhere((a) => a.id == id);

    await updateSettings((s) => s.copyWith(installedAddons: currentAddons));
  }

  /// Puts a removed [addon] back at [index] (the Undo of [removeAddon]).
  Future<void> restoreAddon(StremioAddon addon, int index) async {
    final currentAddons = [...state.installedAddons]
      ..removeWhere((a) => a.id == addon.id);
    currentAddons.insert(index.clamp(0, currentAddons.length), addon);

    await updateSettings((s) => s.copyWith(installedAddons: currentAddons));
  }

  Future<void> toggleAddon(String id, bool enabled) async {
    final currentAddons = state.installedAddons.map((a) {
      if (a.id == id) return a.copyWith(enabled: enabled);
      return a;
    }).toList();

    await updateSettings((s) => s.copyWith(installedAddons: currentAddons));
  }
}

// Lives for the whole session: settings are read everywhere.
final settingsProvider = NotifierProvider<SettingsNotifier, UserSettings>(
  SettingsNotifier.new,
);
