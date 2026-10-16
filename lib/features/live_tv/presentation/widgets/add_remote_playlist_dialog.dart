import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/live_tv/domain/live_tv_playlist.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/menu/menu_focus_ring.dart';
import 'package:flutter/material.dart';

/// The dialog to add a playlist from its link. It stays open until the save
/// works; a failed save shows under the link box (REV-261).
class AddRemotePlaylistDialog extends StatefulWidget {
  /// Saves the playlist; returns the error text, or `null` once saved.
  final Future<String?> Function(String name, String url, PlaylistType type)
  onAdd;

  const AddRemotePlaylistDialog({super.key, required this.onAdd});

  @override
  State<AddRemotePlaylistDialog> createState() =>
      _AddRemotePlaylistDialogState();
}

class _AddRemotePlaylistDialogState extends State<AddRemotePlaylistDialog> {
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  PlaylistType _type = PlaylistType.m3u;
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    final uri = Uri.tryParse(_urlController.text.trim());
    return !_isSaving &&
        _nameController.text.trim().isNotEmpty &&
        uri != null &&
        uri.host.isNotEmpty &&
        (uri.scheme == 'http' || uri.scheme == 'https');
  }

  void _onChanged(String _) => setState(() => _error = null);

  Future<void> _create() async {
    setState(() {
      _isSaving = true;
      _error = null;
    });
    final error = await widget.onAdd(
      _nameController.text.trim(),
      _urlController.text.trim(),
      _type,
    );
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context);
    } else {
      setState(() {
        _isSaving = false;
        _error = error;
      });
    }
  }

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
              onChanged: _onChanged,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: l10n.liveTvPlaylistUrl,
                errorText: _error,
              ),
              keyboardType: TextInputType.url,
              onChanged: _onChanged,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<PlaylistType>(
              initialValue: _type,
              mouseCursor: AppTheme.clickCursor,
              dropdownMenuItemMouseCursor: AppTheme.clickCursor,
              decoration: InputDecoration(labelText: l10n.liveTvPlaylistFormat),
              items: withMenuFocusRings(
                PlaylistType.values
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(e.name.toUpperCase()),
                      ),
                    )
                    .toList(),
              ),
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
          onPressed: _canSubmit ? _create : null,
          child: Text(l10n.commonCreate),
        ),
      ],
    );
  }
}
