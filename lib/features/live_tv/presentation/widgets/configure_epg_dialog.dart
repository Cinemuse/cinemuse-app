import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// The dialog to set the guide (EPG) address. It stays open until the save
/// works; a failed save shows under the box (REV-261).
class ConfigureEpgDialog extends StatefulWidget {
  final String initialUrl;

  /// Save and reset return the error text, or `null` once saved.
  final Future<String?> Function(String url) onSave;
  final Future<String?> Function() onReset;

  const ConfigureEpgDialog({
    super.key,
    required this.initialUrl,
    required this.onSave,
    required this.onReset,
  });

  @override
  State<ConfigureEpgDialog> createState() => _ConfigureEpgDialogState();
}

class _ConfigureEpgDialogState extends State<ConfigureEpgDialog> {
  late final TextEditingController _controller;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String?> Function() save) async {
    setState(() {
      _isSaving = true;
      _error = null;
    });
    final error = await save();
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
      title: Text(l10n.liveTvEpgDialogTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: l10n.liveTvEpgUrl,
                hintText: l10n.liveTvEpgDialogHint,
                errorText: _error,
              ),
              keyboardType: TextInputType.url,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
          ],
        ),
      ),
      actions: [
        if (widget.initialUrl.isNotEmpty)
          TextButton(
            onPressed: _isSaving ? null : () => _run(widget.onReset),
            child: Text(
              l10n.liveTvResetEpg,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _isSaving
              ? null
              : () => _run(() => widget.onSave(_controller.text)),
          child: Text(l10n.settingsSave),
        ),
      ],
    );
  }
}
