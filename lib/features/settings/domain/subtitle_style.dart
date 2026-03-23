import 'package:flutter/material.dart';

class SubtitleStyle {
  final double fontSize;
  final Color color;
  final Color backgroundColor;
  final double verticalPosition; // 0.0 (bottom) to 1.0 (top)

  const SubtitleStyle({
    this.fontSize = 24.0,
    this.color = Colors.white,
    this.backgroundColor = Colors.transparent,
    this.verticalPosition = 0.05, // Default near bottom
  });

  SubtitleStyle copyWith({
    double? fontSize,
    Color? color,
    Color? backgroundColor,
    double? verticalPosition,
  }) {
    return SubtitleStyle(
      fontSize: fontSize ?? this.fontSize,
      color: color ?? this.color,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      verticalPosition: verticalPosition ?? this.verticalPosition,
    );
  }

  // Helper to convert Color to Hex String for persistence
  static String colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  // Helper to convert Hex String back to Color
  static Color hexToColor(String hex) {
    try {
      if (hex.startsWith('#')) {
        hex = hex.substring(1);
      }
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return Colors.white;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubtitleStyle &&
          runtimeType == other.runtimeType &&
          fontSize == other.fontSize &&
          color == other.color &&
          backgroundColor == other.backgroundColor &&
          verticalPosition == other.verticalPosition;

  @override
  int get hashCode => Object.hash(fontSize, color, backgroundColor, verticalPosition);
}
