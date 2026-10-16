import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';

/// The subtitle text colours offered both in Settings → Subtitles and in the
/// player's colour panel. One list, so a colour picked in one place shows as
/// selected in the other (REV-286).
const subtitleTextColors = <Color>[
  AppTheme.textWhite,
  AppTheme.watchlist,
  AppTheme.success,
  AppTheme.badgeSize,
  AppTheme.badgeResolution,
  AppTheme.badgeAudio,
  AppTheme.favorites,
  AppTheme.badgeHdr,
];
