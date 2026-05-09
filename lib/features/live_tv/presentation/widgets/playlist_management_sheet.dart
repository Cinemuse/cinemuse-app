import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:cinemuse_app/features/live_tv/domain/live_tv_playlist.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';

class PlaylistManagementSheet extends ConsumerWidget {
  const PlaylistManagementSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(customPlaylistsProvider);
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor.withValues(alpha: 0.9),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Custom Playlists',
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

              // Playlist List
              if (playlists.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'No custom playlists added yet.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: playlists.length,
                    itemBuilder: (context, index) {
                      final playlist = playlists[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          playlist.isLocal ? LucideIcons.fileText : LucideIcons.globe,
                          color: theme.colorScheme.primary,
                        ),
                        title: Text(playlist.name),
                        subtitle: Text(
                          playlist.urlOrPath,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          icon: const Icon(LucideIcons.trash2),
                          color: theme.colorScheme.error,
                          onPressed: () {
                            ref
                                .read(customPlaylistsProvider.notifier)
                                .removePlaylist(playlist.id);
                          },
                        ),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 24),
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _showAddRemotePlaylistDialog(context, ref),
                      icon: const Icon(LucideIcons.link),
                      label: const Text('Add URL'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => _pickAndAddLocalPlaylist(context, ref),
                      icon: const Icon(LucideIcons.folderInput),
                      label: const Text('Add File'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddRemotePlaylistDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => _AddRemotePlaylistDialog(
        onAdd: (name, url, type) {
          ref.read(customPlaylistsProvider.notifier).addPlaylist(
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

  Future<void> _pickAndAddLocalPlaylist(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['m3u', 'm3u8', 'json'],
    );

    if (result != null && result.files.single.path != null) {
      final sourceFile = File(result.files.single.path!);
      final extension = p.extension(sourceFile.path).toLowerCase();
      final type = extension.contains('json') ? PlaylistType.json : PlaylistType.m3u;
      
      // Copy to app documents directory
      final appDocDir = await getApplicationDocumentsDirectory();
      final fileName = p.basename(sourceFile.path);
      final destFile = File('${appDocDir.path}/$fileName');
      await sourceFile.copy(destFile.path);

      ref.read(customPlaylistsProvider.notifier).addPlaylist(
            LiveTvPlaylist(
              name: result.files.single.name,
              urlOrPath: destFile.path,
              isLocal: true,
              type: type,
            ),
          );
    }
  }
}

class _AddRemotePlaylistDialog extends StatefulWidget {
  final Function(String name, String url, PlaylistType type) onAdd;

  const _AddRemotePlaylistDialog({required this.onAdd});

  @override
  State<_AddRemotePlaylistDialog> createState() => _AddRemotePlaylistDialogState();
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Remote Playlist'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Playlist Name'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(labelText: 'Playlist URL'),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<PlaylistType>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Format'),
            items: PlaylistType.values
                .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(e.name.toUpperCase()),
                    ))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _type = val);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_nameController.text.isNotEmpty && _urlController.text.isNotEmpty) {
              widget.onAdd(_nameController.text, _urlController.text, _type);
              Navigator.pop(context);
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
