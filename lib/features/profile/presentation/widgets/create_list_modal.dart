import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class CreateListModal extends StatefulWidget {
  final Function(String name) onCreate;

  const CreateListModal({super.key, required this.onCreate});

  @override
  State<CreateListModal> createState() => _CreateListModalState();
}

class _CreateListModalState extends State<CreateListModal> {
  final _controller = TextEditingController();
  bool _canCreate = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateCanCreate);
  }

  void _updateCanCreate() {
    final text = _controller.text.trim();
    if (text.isNotEmpty != _canCreate) {
      setState(() => _canCreate = text.isNotEmpty);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white10)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.detailsNewCollection,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLength: 32,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: l10n.detailsCollectionNameHint,
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.black.withOpacity(0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.accent),
                ),
                counterStyle: const TextStyle(color: Colors.white38),
              ),
              onSubmitted: (val) {
                if (val.trim().isNotEmpty) {
                  widget.onCreate(val.trim());
                  Navigator.of(context).pop();
                }
              },
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.commonCancel, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _canCreate 
                      ? () {
                          widget.onCreate(_controller.text.trim());
                          Navigator.of(context).pop();
                        }
                      : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppTheme.accent.withOpacity(0.3),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(l10n.commonCreate),
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
