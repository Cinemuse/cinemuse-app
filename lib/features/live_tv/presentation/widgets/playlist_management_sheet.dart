import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/services/local_playlist_storage.dart';
import 'package:cinemuse_app/features/live_tv/domain/live_tv_playlist.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/setting_toggle.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Bottom-sheet wrapper (used from the Live TV channel panel)
// ---------------------------------------------------------------------------

class PlaylistManagementSheet extends ConsumerWidget {
  const PlaylistManagementSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.liveTvCustomPlaylists,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Flexible(child: PlaylistListSection()),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable content section — used in both the sheet and Settings screen
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
        // Playlist tiles
        if (playlists.isEmpty)
          _buildEmptyState(context, l10n)
        else
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: playlists.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: Colors.white.withValues(alpha: 0.05),
              ),
              itemBuilder: (context, index) => _PlaylistTile(
                playlist: playlists[index],
                isLast: index == playlists.length - 1,
              ),
            ),
          ),
        const SizedBox(height: 20),
        // Action buttons
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
      builder: (context) => _AddRemotePlaylistDialog(
        onAdd: (name, url, type) {
          ref
              .read(customPlaylistsProvider.notifier)
              .addPlaylist(
                LiveTvPlaylist(
                  name: name,
                  urlOrPath: url,
                  isLocal: false,
                  type: type,
                ),
              );
        },
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

    if (result == null || result.files.single.path == null) return;

    final sourceFile = File(result.files.single.path!);
    final extension = sourceFile.path.toLowerCase();
    final type = extension.contains('json')
        ? PlaylistType.json
        : PlaylistType.m3u;

    final destFile = await LocalPlaylistStorage.copyPlaylistFile(sourceFile);

    ref
        .read(customPlaylistsProvider.notifier)
        .addPlaylist(
          LiveTvPlaylist(
            name: result.files.single.name,
            urlOrPath: destFile.uri.pathSegments.last, // basename only
            isLocal: true,
            type: type,
          ),
        );
  }
}

// ---------------------------------------------------------------------------
// Individual playlist tile — addon-style with toggle + action icons
// ---------------------------------------------------------------------------

class _PlaylistTile extends ConsumerWidget {
  final LiveTvPlaylist playlist;
  final bool isLast;

  const _PlaylistTile({required this.playlist, required this.isLast});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isEnabled = playlist.isEnabled;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isEnabled ? 1.0 : 0.5,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            // Type icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isEnabled
                    ? AppTheme.accent.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                playlist.isLocal ? LucideIcons.fileText : LucideIcons.globe,
                size: 18,
                color: isEnabled ? AppTheme.accent : Colors.white30,
              ),
            ),
            const SizedBox(width: 12),
            // Name + subtitle + badge
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    playlist.urlOrPath,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
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
                  onChanged: (_) => ref
                      .read(customPlaylistsProvider.notifier)
                      .togglePlaylistEnabled(playlist.id),
                ),
                const SizedBox(width: 4),
                if (playlist.isLocal && Platform.isWindows)
                  _OpenFolderButton(playlist: playlist, l10n: l10n),
                if (!playlist.isLocal)
                  _OpenLinkButton(playlist: playlist, l10n: l10n),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(LucideIcons.trash2, size: 17),
                  color: Colors.redAccent,
                  tooltip: l10n.settingsRemove,
                  onPressed: () => ref
                      .read(customPlaylistsProvider.notifier)
                      .removePlaylist(playlist.id),
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
// Open folder button (Windows-only, local playlists only)
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
      await Process.run('explorer', ['/select,', absolutePath]);
    } catch (_) {
      // Silently fail — file may have been deleted
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
      await Process.run('cmd', ['/c', 'start', '', uri.toString()]);
    } catch (_) {}
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
// Dialog for adding a remote playlist
// ---------------------------------------------------------------------------

class _AddRemotePlaylistDialog extends StatefulWidget {
  final void Function(String name, String url, PlaylistType type) onAdd;

  const _AddRemotePlaylistDialog({required this.onAdd});

  @override
  State<_AddRemotePlaylistDialog> createState() =>
      _AddRemotePlaylistDialogState();
}

class _AddRemotePlaylistDialogState extends State<_AddRemotePlaylistDialog> {
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  PlaylistType _type = PlaylistType.m3u;

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _nameController.text.isNotEmpty && _urlController.text.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.liveTvAddRemotePlaylist),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: l10n.liveTvPlaylistName),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              decoration: InputDecoration(labelText: l10n.liveTvPlaylistUrl),
              keyboardType: TextInputType.url,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<PlaylistType>(
              initialValue: _type,
              decoration: InputDecoration(labelText: l10n.liveTvPlaylistFormat),
              items: PlaylistType.values
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(e.name.toUpperCase()),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _type = val);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _canSubmit
              ? () {
                  widget.onAdd(
                    _nameController.text,
                    _urlController.text,
                    _type,
                  );
                  Navigator.pop(context);
                }
              : null,
          child: Text(l10n.commonCreate),
        ),
      ],
    );
  }
}
