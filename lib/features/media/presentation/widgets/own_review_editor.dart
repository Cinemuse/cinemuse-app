import 'dart:async';

import 'package:cinemuse_app/core/error/error_mappers.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/application/own_reviews_provider.dart';
import 'package:cinemuse_app/features/media/domain/own_review.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/setting_slider.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/app_snackbar.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:cinemuse_app/shared/widgets/dpad_text_box.dart';
import 'package:cinemuse_app/shared/widgets/wreath.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Giving a title a score and a review, inside the reviews sheet: the wreath
/// shows the score and the slider sets it. One Save for both, because holding
/// the remote's key passes through many scores. For a remote the order is the
/// slider, the review box, then Save.
class OwnReviewEditor extends ConsumerStatefulWidget {
  final RatedTitle title;

  /// The rating being changed; null for a new one.
  final OwnReview? review;

  /// The unsaved score and text from an earlier opening, if any.
  final OwnReviewDraft? draft;

  /// Saved, or cancelled with nothing changed: back to the reviews.
  final VoidCallback onClose;

  /// Cancelled with something changed. The sheet shows the Undo message, which
  /// stays up after the editor closes.
  final VoidCallback onDiscard;

  /// "Remove review" was chosen. The sheet does the removal: the editor closes
  /// at once, and its Undo message stays up after that.
  final ValueChanged<OwnReview> onRemove;

  const OwnReviewEditor({
    super.key,
    required this.title,
    required this.review,
    this.draft,
    required this.onClose,
    required this.onDiscard,
    required this.onRemove,
  });

  /// Lower than this, the wreath moves beside the slider and the box. A Fire
  /// Stick at 100% Screen size has a sheet 459 tall.
  static const shortHeight = 560.0;

  /// Narrower than this there is no room beside the wreath, however short.
  static const _sideBySideWidth = 480.0;

  /// Room for the focus ring, drawn outside each control.
  static const _ringRoom = AppTheme.focusRingGap + AppTheme.focusRingWidth;

  @override
  ConsumerState<OwnReviewEditor> createState() => _OwnReviewEditorState();
}

class _OwnReviewEditorState extends ConsumerState<OwnReviewEditor> {
  late int _rating =
      widget.draft?.rating ?? widget.review?.rating ?? OwnReview.startingRating;
  late final _textController = TextEditingController(
    text: widget.draft?.text ?? widget.review?.text,
  );
  // The box also reports moves of the cursor, which change nothing.
  late String _keptText = _textController.text;
  final _saveFocusNode = FocusNode(debugLabel: 'OwnReviewSave');
  // Kept: it remembers the way the remote came, to go back the same way.
  final _traversalPolicy = ReadingOrderTraversalPolicy();
  // Enter and a click can come together: one save.
  bool _isSaving = false;

  OwnReviewDraft get _current =>
      OwnReviewDraft(rating: _rating, text: _textController.text);

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _textController.dispose();
    _saveFocusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_textController.text == _keptText) return;
    _keptText = _textController.text;
    _keepDraft();
  }

  void _keepDraft() {
    // Not awaited: it logs its own failure, and typing doesn't wait for it.
    unawaited(
      ref
          .read(ownReviewActionsProvider)
          .keepDraft(widget.title, _current, saved: widget.review),
    );
  }

  void _cancel() {
    if (_current.differsFrom(widget.review)) {
      widget.onDiscard();
    } else {
      widget.onClose();
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    _isSaving = true;
    try {
      await ref
          .read(ownReviewActionsProvider)
          .save(widget.title, rating: _rating, text: _textController.text);
      if (mounted) widget.onClose();
    } catch (e) {
      // The editor stays, with what was typed.
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: ref.read(errorMapperProvider).map(e).message,
        isError: true,
      );
    } finally {
      _isSaving = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isShort = constraints.maxHeight < OwnReviewEditor.shortHeight;
        final isSideBySide =
            isShort && constraints.maxWidth >= OwnReviewEditor._sideBySideWidth;

        return Padding(
          // The on-screen keyboard mustn't cover the box being typed in.
          padding: EdgeInsets.only(
            bottom:
                MediaQuery.viewInsetsOf(context).bottom +
                16 -
                OwnReviewEditor._ringRoom,
          ),
          child: FocusTraversalGroup(
            policy: _traversalPolicy,
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    // The scroll view cuts what is drawn past its edges.
                    padding: const EdgeInsets.fromLTRB(
                      OwnReviewEditor._ringRoom,
                      0,
                      OwnReviewEditor._ringRoom,
                      OwnReviewEditor._ringRoom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.ownReviewEditorTitle,
                          style: DesktopTypography.sectionHeader,
                        ),
                        const SizedBox(height: 12),
                        if (isSideBySide)
                          _sideBySide(context, l10n)
                        else
                          _stacked(context, l10n, isShort: isShort),
                        const Spacer(),
                        const SizedBox(height: 12),
                        _Buttons(
                          isInOneRow: isSideBySide,
                          saveFocusNode: _saveFocusNode,
                          onSave: _save,
                          onCancel: _cancel,
                          onRemove: switch (widget.review) {
                            final review? => () => widget.onRemove(review),
                            null => null,
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sideBySide(BuildContext context, AppLocalizations l10n) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wreath(score: _rating, size: 170, showNumber: true),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _slider(l10n),
              const SizedBox(height: 10),
              _textBox(context, l10n, lines: 4),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stacked(
    BuildContext context,
    AppLocalizations l10n, {
    required bool isShort,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Wreath(
            score: _rating,
            size: isShort ? 120 : 190,
            showNumber: true,
          ),
        ),
        const SizedBox(height: 8),
        _slider(l10n),
        const SizedBox(height: 12),
        _textBox(context, l10n, lines: 5),
        const SizedBox(height: 6),
        Text(
          l10n.ownReviewFormattingHint,
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _slider(AppLocalizations l10n) => SettingSlider(
    label: l10n.ownReviewScoreField,
    value: _rating.toDouble(),
    min: OwnReview.minRating.toDouble(),
    max: OwnReview.maxRating.toDouble(),
    divisions: OwnReview.maxRating - OwnReview.minRating,
    autofocus: true,
    onChanged: (value) {
      setState(() => _rating = value.round());
      _keepDraft();
    },
  );

  Widget _textBox(
    BuildContext context,
    AppLocalizations l10n, {
    required int lines,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.ownReviewTextField,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        DpadTextBox(
          isMultiline: true,
          borderRadius: AppTheme.radius12,
          onDown: () {
            // Save, not the Cancel beside it. The policy doesn't see this
            // move: its memory would take Up from Save past the box.
            _traversalPolicy.invalidateScopeData(FocusScope.of(context));
            _saveFocusNode.requestFocus();
          },
          builder: (context, textNode, stopTyping) => TextField(
            controller: _textController,
            focusNode: textNode,
            minLines: lines,
            maxLines: lines,
            keyboardType: TextInputType.multiline,
            style: const TextStyle(
              color: AppTheme.textWhite,
              fontSize: 14,
              height: 1.4,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.3),
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: AppTheme.radius12,
                borderSide: const BorderSide(color: Colors.white10),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppTheme.radius12,
                borderSide: const BorderSide(color: Colors.white10),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: AppTheme.radius12,
                borderSide: BorderSide(color: AppTheme.accent),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Save and Cancel, plus Remove when there is a rating to remove.
class _Buttons extends StatelessWidget {
  final bool isInOneRow;
  final FocusNode saveFocusNode;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final VoidCallback? onRemove;

  const _Buttons({
    required this.isInOneRow,
    required this.saveFocusNode,
    required this.onSave,
    required this.onCancel,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Filled like the sheet's "Edit review": bare text on the sheet's colour
    // didn't read as a button.
    final cancel = _EditorButton(
      label: l10n.commonCancel,
      color: AppTheme.textWhite,
      background: AppTheme.textWhite.withValues(alpha: 0.08),
      border: AppTheme.textWhite.withValues(alpha: 0.1),
      onTap: onCancel,
    );
    final save = _EditorButton(
      label: l10n.ownReviewSave,
      color: AppTheme.textWhite,
      background: AppTheme.accent,
      focusNode: saveFocusNode,
      onTap: onSave,
    );
    final remove = onRemove == null
        ? null
        : _EditorButton(
            label: l10n.ownReviewRemove,
            color: AppTheme.error,
            onTap: onRemove!,
          );

    if (isInOneRow) {
      return Row(
        children: [
          ?remove,
          const Spacer(),
          SizedBox(width: 110, child: cancel),
          const SizedBox(width: 10),
          SizedBox(width: 110, child: save),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: cancel),
            const SizedBox(width: 12),
            Expanded(child: save),
          ],
        ),
        if (remove != null) ...[const SizedBox(height: 4), remove],
      ],
    );
  }
}

class _EditorButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color? background;
  final Color? border;
  final FocusNode? focusNode;
  final VoidCallback onTap;

  const _EditorButton({
    required this.label,
    required this.color,
    this.background,
    this.border,
    this.focusNode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DpadFocusable(
      focusNode: focusNode,
      onTap: onTap,
      borderRadius: AppTheme.radius12,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: background,
          borderRadius: AppTheme.radius12,
          border: border == null ? null : Border.all(color: border!),
        ),
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
