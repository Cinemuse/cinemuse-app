import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/streaming/models/stream_metadata.dart';
import 'package:cinemuse_app/features/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

class SettingsBadge extends StatelessWidget {
  final String text;
  final Color color;
  const SettingsBadge({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppTheme.radiusSm,
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class SettingsLabel extends StatelessWidget {
  final String text;
  final Color? color;
  const SettingsLabel({super.key, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: color ?? AppTheme.textMuted.withValues(alpha: 0.8),
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    );
  }
}

class StreamMetadataOverview extends StatelessWidget {
  final StreamCandidate stream;

  const StreamMetadataOverview({super.key, required this.stream});

  /// For a source that gives the size apart from the stream's name.
  static String? _readableSize(int? bytes) {
    if (bytes == null || bytes <= 0) return null;
    const megabyte = 1024 * 1024;
    const gigabyte = 1024 * megabyte;
    return bytes >= gigabyte
        ? '${(bytes / gigabyte).toStringAsFixed(1)} GB'
        : '${(bytes / megabyte).ceil()} MB';
  }

  @override
  Widget build(BuildContext context) {
    final meta = stream.metadata;
    final l10n = AppLocalizations.of(context);
    final cachedLabel = l10n?.playerCached ?? 'CACHED';

    if (meta == null) {
      return Text(
        stream.title,
        style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final size = meta.size ?? _readableSize(stream.sizeInBytes);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (stream.isCached) ...[
              if (stream.cachedOn.isEmpty)
                SettingsBadge(text: cachedLabel, color: AppTheme.success)
              else
                for (final entry in stream.cachedOn.entries)
                  if (entry.value)
                    SettingsBadge(
                      text: entry.key == 'Real-Debrid'
                          ? 'RD'
                          : entry.key == 'TorBox'
                          ? 'TB'
                          : cachedLabel,
                      color: AppTheme.success,
                    ),
            ],
            if (meta.video.resolution != VideoResolution.unknown)
              SettingsBadge(
                text: meta.video.resolution.friendlyLabel,
                color: AppTheme.badgeResolution,
              ),
            if (meta.video.isHDR)
              const SettingsBadge(text: 'HDR', color: AppTheme.badgeHdr),
            if (meta.video.isDV)
              const SettingsBadge(text: 'DV', color: AppTheme.badgeHdr),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SettingsLabel(
              text: stream.provider,
              color: AppTheme.accent.withValues(alpha: 0.9),
            ),
            if (size != null)
              SettingsLabel(
                text: size,
                color: AppTheme.badgeSize.withValues(alpha: 0.8),
              ),
            if (meta.flags.contains(ReleaseFlag.extended))
              SettingsLabel(text: ReleaseFlag.extended.label),
            if (meta.languages.isNotEmpty)
              SettingsLabel(
                text: meta.languages.join(' • '),
                color: AppTheme.textSecondary,
              ),
          ],
        ),
      ],
    );
  }
}
