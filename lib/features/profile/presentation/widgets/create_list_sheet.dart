import 'package:cinemuse_app/core/constants/app_constants.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/app_bottom_sheet.dart';
import 'package:flutter/material.dart';

class CreateListSheet extends StatefulWidget {
  final Function(String name) onCreate;

  const CreateListSheet({super.key, required this.onCreate});

  static Future<void> show(
    BuildContext context, {
    required Function(String name) onCreate,
  }) {
    return AppBottomSheet.show(
      context: context,
      constraints: const BoxConstraints(maxWidth: 500),
      child: CreateListSheet(onCreate: onCreate),
    );
  }

  @override
  State<CreateListSheet> createState() => _CreateListSheetState();
}

class _CreateListSheetState extends State<CreateListSheet> {
  final _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _canCreate = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateCanCreate);
    // Add slight delay to ensure bottom sheet is fully built before requesting focus
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _focusNode.requestFocus();
    });
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
    _focusNode.dispose();
    super.dispose();
  }

  void _handleCreate() {
    if (_canCreate) {
      widget.onCreate(_controller.text.trim());
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppBottomSheet(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24.0,
          right: 24.0,
          top: 8.0,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 24.0,
        ),
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
              focusNode: _focusNode,
              maxLength: AppConstants.maxListNameLength,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: l10n.detailsCollectionNameHint,
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.black.withValues(alpha: 0.3),
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
              onSubmitted: (_) => _handleCreate(),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      l10n.commonCancel,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _canCreate ? _handleCreate : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppTheme.accent.withValues(
                        alpha: 0.3,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      l10n.commonCreate,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
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
