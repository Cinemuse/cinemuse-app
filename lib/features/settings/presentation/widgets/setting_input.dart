import 'package:cinemuse_app/core/error/error_mappers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/app_snackbar.dart';
import 'package:cinemuse_app/shared/widgets/focus_ring.dart';

class SettingInput extends ConsumerStatefulWidget {
  final String? label;
  final String? description;
  final String value;
  final String placeholder;
  final bool isPassword;
  final Future<void> Function(String) onSave;

  const SettingInput({
    super.key,
    this.label,
    this.description,
    required this.value,
    this.placeholder = '',
    this.isPassword = false,
    required this.onSave,
  });

  @override
  ConsumerState<SettingInput> createState() => _SettingInputState();
}

class _SettingInputState extends ConsumerState<SettingInput> {
  late TextEditingController _controller;
  bool _isDirty = false;
  bool _isSaving = false;
  bool _showSuccess = false;
  late bool _isObscured;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _controller.addListener(_checkForChanges);
    _isObscured = widget.isPassword;
  }

  @override
  void didUpdateWidget(covariant SettingInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != _controller.text) {
      _controller.text = widget.value;
      _isDirty = false;
    }
  }

  void _checkForChanges() {
    final newValue = _controller.text;
    final isNowDirty = newValue != widget.value;
    if (isNowDirty != _isDirty) {
      setState(() {
        _isDirty = isNowDirty;
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_isDirty || _isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.onSave(_controller.text);
      if (mounted) {
        setState(() {
          _isSaving = false;
          _isDirty = false;
          _showSuccess = true;
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _showSuccess = false;
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        // Translated text, never e.toString() (REV-86, REV-164).
        AppSnackBar.show(
          context,
          message: AppLocalizations.of(
            context,
          )!.settingsErrorSaving(ref.read(errorMapperProvider).map(e).message),
          isError: true,
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_checkForChanges);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final input = Row(
      children: [
        Expanded(
          child: SettingsTextField(
            controller: _controller,
            obscureText: _isObscured,
            decoration: settingsInputDecoration(
              hintText: widget.placeholder,
              suffixIcon: widget.isPassword
                  ? IconButton(
                      tooltip: _isObscured
                          ? AppLocalizations.of(context)!.commonShowPassword
                          : AppLocalizations.of(context)!.commonHidePassword,
                      icon: Icon(
                        _isObscured ? Icons.visibility_off : Icons.visibility,
                        color: AppTheme.textMuted,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _isObscured = !_isObscured;
                        });
                      },
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: (_isDirty && !_isSaving) ? _handleSave : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isDirty && !_isSaving
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.05),
              foregroundColor: _isDirty && !_isSaving
                  ? Colors.black
                  : Colors.grey,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : _showSuccess
                ? const Icon(Icons.check, size: 18, color: Colors.green)
                : const Icon(Icons.save, size: 18),
            label: Text(
              _isSaving
                  ? ''
                  : _showSuccess
                  ? l10n.settingsSaved
                  : l10n.settingsSave,
            ),
          ),
        ),
      ],
    );

    if (widget.label == null) return input;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label!,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
          if (widget.description != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.description!,
              style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
            ),
          ],
          const SizedBox(height: 12),
          input,
        ],
      ),
    );
  }
}

/// The settings text box: the shared look, and the focus ring while the
/// keyboard / remote is in it (REV-263).
class SettingsTextField extends StatelessWidget {
  final TextEditingController controller;
  final InputDecoration decoration;
  final bool obscureText;
  final ValueChanged<String>? onSubmitted;

  const SettingsTextField({
    super.key,
    required this.controller,
    required this.decoration,
    this.obscureText = false,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return FocusRingFollower(
      borderRadius: BorderRadius.circular(16),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: const TextStyle(color: Colors.white),
        decoration: decoration,
        onSubmitted: onSubmitted,
      ),
    );
  }
}

/// The look of every settings text box (REV-83).
InputDecoration settingsInputDecoration({
  String? hintText,
  String? errorText,
  Widget? suffixIcon,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
  );
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(color: Colors.white24),
    errorText: errorText,
    filled: true,
    fillColor: Colors.black.withValues(alpha: 0.3),
    suffixIcon: suffixIcon,
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: const BorderSide(color: AppTheme.accent),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  );
}
