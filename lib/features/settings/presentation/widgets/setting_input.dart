import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

class SettingInput extends StatefulWidget {
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
  State<SettingInput> createState() => _SettingInputState();
}

class _SettingInputState extends State<SettingInput> {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.settingsErrorSaving(e.toString()))),
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
          child: TextField(
            controller: _controller,
            obscureText: _isObscured,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: widget.placeholder,
              filled: true,
              fillColor: Colors.black.withOpacity(0.3),
              suffixIcon: widget.isPassword
                  ? IconButton(
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
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.accent),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: (_isDirty && !_isSaving) ? _handleSave : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isDirty && !_isSaving ? Colors.white : Colors.white.withOpacity(0.05),
              foregroundColor: _isDirty && !_isSaving ? Colors.black : Colors.grey,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
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
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: 12),
          input,
        ],
      ),
    );
  }
}
