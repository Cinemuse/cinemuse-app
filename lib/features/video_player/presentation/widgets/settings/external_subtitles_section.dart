import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cinemuse_app/core/constants/tmdb_constants.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:cinemuse_app/features/streaming/subtitles/external_subtitle.dart';
import 'package:cinemuse_app/features/streaming/subtitles/subtitle_service.dart';
import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/app_snackbar.dart';
import 'settings_widgets.dart';

/// Section widget for browsing and downloading external subtitles.
class ExternalSubtitlesSection extends StatefulWidget {
  final Player player;
  final AsyncValue<List<ExternalSubtitle>> externalSubsAsync;
  final bool isLandscape;
  final VoidCallback onBack;
  final PlayerParams params;

  const ExternalSubtitlesSection({
    super.key,
    required this.player,
    required this.externalSubsAsync,
    required this.isLandscape,
    required this.onBack,
    required this.params,
  });

  @override
  State<ExternalSubtitlesSection> createState() =>
      _ExternalSubtitlesSectionState();
}

class _ExternalSubtitlesSectionState extends State<ExternalSubtitlesSection> {
  final Map<String, bool> _expandedLanguages = {};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final externalTracksLabel = l10n?.playerExternalTracks ?? 'EXTERNAL TRACKS';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            externalTracksLabel,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
        widget.externalSubsAsync.when(
          data: (subs) => _buildExternalSubtitleList(context, subs),
          loading: () => const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (e, st) {
            developer.log(
              'Error loading external subtitles',
              name: 'VideoPlayer.ExternalSubtitles',
              error: e,
              stackTrace: st,
            );
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  AppLocalizations.of(
                        context,
                      )?.playerErrorPrefix(e.toString()) ??
                      'Error: $e',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildExternalSubtitleList(
    BuildContext context,
    List<ExternalSubtitle> subs,
  ) {
    final l10n = AppLocalizations.of(context);
    if (subs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Text(
            l10n?.playerNoExternalSubtitles ?? 'No external subtitles found.',
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
        ),
      );
    }

    final grouped = <String, List<ExternalSubtitle>>{};
    for (var sub in subs) {
      grouped.putIfAbsent(sub.language, () => []).add(sub);
    }

    return Column(
      children: grouped.entries
          .map(
            (entry) => _buildLanguageFolder(
              context: context,
              language: entry.key,
              subtitles: entry.value,
            ),
          )
          .toList(),
    );
  }

  Widget _buildLanguageFolder({
    required BuildContext context,
    required String language,
    required List<ExternalSubtitle> subtitles,
  }) {
    final l10n = AppLocalizations.of(context);
    final isExpanded = _expandedLanguages[language] ?? false;
    final subtitlesCountText =
        l10n?.playerSubtitlesCount(subtitles.length) ??
        '${subtitles.length} subtitles';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DpadFocusable(
          showFocusRing: true,
          onTap: () =>
              setState(() => _expandedLanguages[language] = !isExpanded),
          borderRadius: AppTheme.radiusMd,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 8,
              vertical: widget.isLandscape ? 8 : 12,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.folder_open_rounded,
                  color: AppTheme.accent,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (l10n?.languageName(language) ?? language)
                            .toUpperCase(),
                        style: const TextStyle(
                          color: AppTheme.textWhite,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        subtitlesCountText,
                        style: TextStyle(
                          color: AppTheme.textMuted.withValues(alpha: 0.8),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.textMuted,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) ...[
          const SizedBox(height: 4),
          ...subtitles.map(
            (sub) => _ExternalSubtitleTile(
              subtitle: sub,
              player: widget.player,
              onBack: widget.onBack,
              params: widget.params,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ExternalSubtitleTile extends ConsumerStatefulWidget {
  final ExternalSubtitle subtitle;
  final Player player;
  final VoidCallback onBack;
  final PlayerParams params;

  const _ExternalSubtitleTile({
    required this.subtitle,
    required this.player,
    required this.onBack,
    required this.params,
  });

  @override
  ConsumerState<_ExternalSubtitleTile> createState() =>
      _ExternalSubtitleTileState();
}

class _ExternalSubtitleTileState extends ConsumerState<_ExternalSubtitleTile> {
  bool _isApplying = false;

  Future<void> _apply() async {
    if (_isApplying) return;
    setState(() => _isApplying = true);

    try {
      final service = ref.read(subtitleServiceProvider);
      final url = await service.getDownloadUrl(widget.subtitle);
      if (url != null && url.isNotEmpty) {
        final track = SubtitleTrack.uri(
          url,
          title: widget.subtitle.title,
          language: widget.subtitle.language,
        );
        await widget.player.setSubtitleTrack(track);
        if (!mounted) return;
        ref
            .read(playerControllerProvider(widget.params).notifier)
            .setManualTrackSelection();
        widget.onBack();
      } else {
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          AppSnackBar.show(
            context,
            message:
                l10n?.playerFailedLoadSubtitle ??
                'Failed to load external subtitle.',
          );
        }
      }
    } catch (e, st) {
      developer.log(
        'Failed to download and apply external subtitle',
        name: 'VideoPlayer.ExternalSubtitleTile',
        error: e,
        stackTrace: st,
      );
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        AppSnackBar.show(
          context,
          message: l10n?.playerErrorPrefix(e.toString()) ?? 'Error: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub = widget.subtitle;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: DpadFocusable(
        showFocusRing: true,
        borderRadius: AppTheme.radiusMd,
        onTap: _isApplying ? null : _apply,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceOverlay,
            borderRadius: AppTheme.radiusMd,
            border: Border.all(color: AppTheme.borderSubtle, width: 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sub.title,
                      style: TextStyle(
                        color: AppTheme.textWhite.withValues(alpha: 0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        SettingsBadge(
                          text: sub.providerName,
                          color: AppTheme.accent,
                        ),
                        if (sub.downloadCount != null)
                          SettingsBadge(
                            text: '\u2193 ${sub.downloadCount}',
                            color: AppTheme.accent,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (_isApplying)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(
                  LucideIcons.download,
                  color: AppTheme.textMuted,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
