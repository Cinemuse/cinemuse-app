import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cinemuse_app/core/constants/tmdb_constants.dart';
import 'package:cinemuse_app/core/error/error_mappers.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:cinemuse_app/features/streaming/subtitles/external_subtitle.dart';
import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'pick_track.dart';
import 'settings_headers.dart';
import 'stream_metadata_overview.dart';

/// Section widget for browsing and downloading external subtitles.
class ExternalSubtitlesSection extends ConsumerStatefulWidget {
  final AsyncValue<List<ExternalSubtitle>> externalSubsAsync;
  final bool isLandscape;
  final PlayerParams params;

  const ExternalSubtitlesSection({
    super.key,
    required this.externalSubsAsync,
    required this.isLandscape,
    required this.params,
  });

  @override
  ConsumerState<ExternalSubtitlesSection> createState() =>
      _ExternalSubtitlesSectionState();
}

class _ExternalSubtitlesSectionState
    extends ConsumerState<ExternalSubtitlesSection> {
  final Map<String, bool> _expandedLanguages = {};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSectionTitle(l10n.playerExternalTracks),
        widget.externalSubsAsync.when(
          data: (subs) => _buildExternalSubtitleList(context, subs),
          loading: () => const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          // The search's error, already logged by TrackManager.
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                ref.watch(errorMapperProvider).map(e).message,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExternalSubtitleList(
    BuildContext context,
    List<ExternalSubtitle> subs,
  ) {
    final l10n = AppLocalizations.of(context)!;
    if (subs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Text(
            l10n.playerNoExternalSubtitles,
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
    final l10n = AppLocalizations.of(context)!;
    final isExpanded = _expandedLanguages[language] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsAccordionHeader(
          title: l10n.languageName(language),
          subtitle: l10n.playerSubtitlesCount(subtitles.length),
          isExpanded: isExpanded,
          onTap: () =>
              setState(() => _expandedLanguages[language] = !isExpanded),
          compact: widget.isLandscape,
        ),
        if (isExpanded) ...[
          const SizedBox(height: 4),
          ...subtitles.map(
            (sub) =>
                _ExternalSubtitleTile(subtitle: sub, params: widget.params),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ExternalSubtitleTile extends ConsumerStatefulWidget {
  final ExternalSubtitle subtitle;
  final PlayerParams params;

  const _ExternalSubtitleTile({required this.subtitle, required this.params});

  @override
  ConsumerState<_ExternalSubtitleTile> createState() =>
      _ExternalSubtitleTileState();
}

class _ExternalSubtitleTileState extends ConsumerState<_ExternalSubtitleTile> {
  bool _isApplying = false;

  /// Downloads the subtitle and turns it on; the panel stays open.
  Future<void> _apply() async {
    if (_isApplying) return;
    setState(() => _isApplying = true);
    final controller = ref.read(
      playerControllerProvider(widget.params).notifier,
    );
    await pickTrack(
      context,
      () => controller.applyExternalSubtitle(widget.subtitle),
      failedMessage: AppLocalizations.of(context)!.playerFailedLoadSubtitle,
    );
    if (!mounted) return;
    setState(() => _isApplying = false);
  }

  @override
  Widget build(BuildContext context) {
    final sub = widget.subtitle;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: DpadFocusable(
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
