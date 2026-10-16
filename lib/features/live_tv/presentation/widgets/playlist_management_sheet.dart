import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as p;
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:cinemuse_app/features/live_tv/data/local_playlist_storage.dart';
import 'package:cinemuse_app/features/live_tv/domain/live_tv_playlist.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/application/custom_epg_url_notifier.dart';
import 'package:cinemuse_app/features/live_tv/application/epg_refresh_notifier.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/add_remote_playlist_dialog.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/configure_epg_dialog.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/save_live_tv_change.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/setting_toggle.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Playlist list, shown in Settings and in the Live TV options sheet
// ---------------------------------------------------------------------------

class PlaylistListSection extends ConsumerWidget {
  const PlaylistListSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final playlists = ref.watch(customPlaylistsProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (playlists.isEmpty)
          _buildEmptyState(context, l10n)
        else
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: playlists.length,
              itemBuilder: (context, index) =>
                  _PlaylistTile(playlist: playlists[index]),
            ),
          ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () =>
                    _showAddRemotePlaylistDialog(context, ref, l10n),
                icon: const Icon(LucideIcons.link, size: 16),
                label: Text(l10n.liveTvAddUrl),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => _pickAndAddLocalPlaylist(context, ref),
                icon: const Icon(LucideIcons.folderInput, size: 16),
                label: Text(l10n.liveTvAddFile),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Divider(height: 1, color: Colors.white10),
        const SizedBox(height: 20),
        const _EpgSection(),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          l10n.liveTvNoCustomPlaylists,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  void _showAddRemotePlaylistDialog(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    showDialog(
      context: context,
      builder: (_) => AddRemotePlaylistDialog(
        onAdd: (name, url, type) => saveLiveTvChangeError(
          context,
          ref,
          () => ref
              .read(customPlaylistsProvider.notifier)
              .addPlaylist(
                LiveTvPlaylist(
                  name: name,
                  urlOrPath: url,
                  isLocal: false,
                  type: type,
                ),
              ),
        ),
      ),
    );
  }

  Future<void> _pickAndAddLocalPlaylist(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['m3u', 'm3u8', 'json'],
    );

    final path = result?.files.single.path;
    if (path == null || !context.mounted) return;
    await savePlaylists(
      context,
      ref,
      (playlists) => playlists.addLocalPlaylist(File(path)),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual playlist tile — addon-style with toggle + action icons
// ---------------------------------------------------------------------------

class _PlaylistTile extends ConsumerWidget {
  final LiveTvPlaylist playlist;

  const _PlaylistTile({required this.playlist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isEnabled = playlist.isEnabled;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isEnabled ? 1.0 : 0.5,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isEnabled
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.03),
          ),
        ),
        child: Row(
          children: [
            // Type icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isEnabled
                    ? AppTheme.accent.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                playlist.isLocal ? LucideIcons.fileText : LucideIcons.globe,
                size: 20,
                color: isEnabled ? AppTheme.accent : Colors.white30,
              ),
            ),
            const SizedBox(width: 14),
            // Name + subtitle + badge
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    playlist.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    playlist.displaySource,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  _TypeBadge(playlist: playlist, l10n: l10n),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Actions row
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SettingToggle(
                  value: isEnabled,
                  onChanged: (_) => savePlaylists(
                    context,
                    ref,
                    (playlists) => playlists.togglePlaylistEnabled(playlist.id),
                  ),
                ),
                const SizedBox(width: 4),
                if (playlist.isLocal &&
                    (Platform.isWindows || Platform.isLinux))
                  _OpenFolderButton(playlist: playlist, l10n: l10n),
                if (!playlist.isLocal)
                  _OpenLinkButton(playlist: playlist, l10n: l10n),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(LucideIcons.trash2, size: 17),
                  color: Colors.redAccent,
                  tooltip: l10n.settingsRemove,
                  onPressed: () => savePlaylists(
                    context,
                    ref,
                    (playlists) => playlists.removePlaylist(playlist.id),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Type badge chip
// ---------------------------------------------------------------------------

class _TypeBadge extends StatelessWidget {
  final LiveTvPlaylist playlist;
  final AppLocalizations l10n;

  const _TypeBadge({required this.playlist, required this.l10n});

  String _label() {
    if (playlist.isLocal) {
      return playlist.type == PlaylistType.json
          ? l10n.liveTvTypeJsonFile
          : l10n.liveTvTypeM3uFile;
    }
    return playlist.type == PlaylistType.json
        ? l10n.liveTvTypeJsonUrl
        : l10n.liveTvTypeM3uUrl;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Text(
        _label(),
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Open folder button (desktop, local playlists only)
// ---------------------------------------------------------------------------

class _OpenFolderButton extends StatelessWidget {
  final LiveTvPlaylist playlist;
  final AppLocalizations l10n;

  const _OpenFolderButton({required this.playlist, required this.l10n});

  Future<void> _openFolder(BuildContext context) async {
    try {
      final absolutePath = await LocalPlaylistStorage.resolveToAbsolutePath(
        playlist.urlOrPath,
      );
      if (Platform.isWindows) {
        await Process.run('explorer', ['/select,', absolutePath]);
      } else if (Platform.isLinux) {
        final dirPath = p.dirname(absolutePath);
        await Process.run('xdg-open', [dirPath]);
      }
    } catch (e, s) {
      // Only the error type: the path or URL can hold login details.
      AppLogger.warn(
        'PlaylistListSection',
        'Failed to open the playlist file location',
        error: e.runtimeType,
        stackTrace: s,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(LucideIcons.folderOpen, size: 17),
      color: AppTheme.textMuted,
      tooltip: l10n.liveTvOpenFileLocation,
      onPressed: () => _openFolder(context),
    );
  }
}

// ---------------------------------------------------------------------------
// Open link button (remote playlists only)
// ---------------------------------------------------------------------------

class _OpenLinkButton extends StatelessWidget {
  final LiveTvPlaylist playlist;
  final AppLocalizations l10n;

  const _OpenLinkButton({required this.playlist, required this.l10n});

  Future<void> _openLink() async {
    try {
      final uri = Uri.parse(playlist.urlOrPath);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e, s) {
      AppLogger.warn(
        'PlaylistListSection',
        'Failed to open the playlist URL',
        error: e.runtimeType,
        stackTrace: s,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(LucideIcons.externalLink, size: 17),
      color: AppTheme.textMuted,
      tooltip: l10n.liveTvOpenLink,
      onPressed: _openLink,
    );
  }
}

// ---------------------------------------------------------------------------
// EPG / TV Guide Section
// ---------------------------------------------------------------------------

class _EpgSection extends ConsumerWidget {
  const _EpgSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final customUrl = ref.watch(customEpgUrlProvider).valueOrNull;
    final activeUrl = ref.watch(activeEpgUrlProvider);
    final isRefreshing = ref.watch(epgRefreshProvider);
    final isCustom = customUrl != null && customUrl.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                LucideIcons.calendar,
                size: 18,
                color: AppTheme.accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.liveTvEpgSection,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.liveTvEpgSectionDesc,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isCustom
                          ? Colors.amber.withValues(alpha: 0.15)
                          : AppTheme.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isCustom ? l10n.liveTvEpgCustom : l10n.liveTvEpgDefault,
                      style: TextStyle(
                        color: isCustom ? Colors.amber : AppTheme.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                activeUrl,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showConfigureEpgDialog(
                        context,
                        ref,
                        l10n,
                        customUrl,
                      ),
                      icon: const Icon(LucideIcons.edit2, size: 14),
                      label: Text(l10n.liveTvConfigureEpg),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: isRefreshing
                        ? null
                        : () => _refreshEpg(context, ref, l10n),
                    icon: const Icon(LucideIcons.refreshCw, size: 14),
                    label: Text(l10n.liveTvRefreshEpg),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showConfigureEpgDialog(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    String? currentUrl,
  ) {
    showDialog(
      context: context,
      builder: (context) => ConfigureEpgDialog(
        initialUrl: currentUrl ?? '',
        // Changing the URL reloads the guide by itself (REV-115).
        onSave: (url) => saveLiveTvChangeError(
          context,
          ref,
          () => ref.read(customEpgUrlProvider.notifier).setUrl(url),
        ),
        onReset: () => saveLiveTvChangeError(
          context,
          ref,
          () => ref.read(customEpgUrlProvider.notifier).reset(),
        ),
      ),
    );
  }

  Future<void> _refreshEpg(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    // TODO(REV-117): say so when the download fails (today it falls back
    // to the cached guide and this still says "refreshed").
    await ref.read(epgRefreshProvider.notifier).refresh();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.liveTvEpgRefreshed),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
