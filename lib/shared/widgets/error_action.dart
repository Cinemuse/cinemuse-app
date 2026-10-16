import 'package:flutter/widgets.dart';

/// One extra button on an error widget (e.g. "Open on YouTube").
class ErrorAction {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;

  const ErrorAction({required this.label, this.icon, required this.onPressed});
}
