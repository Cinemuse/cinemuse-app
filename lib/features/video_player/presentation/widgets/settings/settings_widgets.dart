import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/video_player/application/language_mapper.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_metadata.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_candidate.dart';

class SubViewHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final bool compact;

  const SubViewHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        top: compact ? 8 : 12,
        right: 24,
        bottom: compact ? 8 : 12,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
            onPressed: onBack,
            splashRadius: 24,
          ),
          const SizedBox(width: 4),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: AppTheme.textWhite.withValues(alpha: 0.9),
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? subtitle;
  final VoidCallback onTap;
  final bool compact;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: 24,
        vertical: compact ? 4 : 8,
      ),
      leading: Container(
        padding: EdgeInsets.all(compact ? 10 : 12),
        decoration: BoxDecoration(
          color: AppTheme.accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppTheme.accent, size: compact ? 20 : 24),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: AppTheme.textWhite,
          fontSize: compact ? 14 : 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle ?? const SizedBox.shrink(),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24),
      onTap: onTap,
    );
  }
}

class QualitySubtitle extends StatelessWidget {
  final CinemaPlayerState state;
  const QualitySubtitle({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final currentStream = state.currentStream;
    if (currentStream == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: StreamMetadataOverview(stream: currentStream.candidate),
    );
  }
}

class TrackSubtitle extends ConsumerWidget {
  final CinemaPlayerState state;
  final bool isSubtitle;
  const TrackSubtitle({super.key, required this.state, required this.isSubtitle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = state.controller.player;
    final pref = ref.watch(settingsProvider);

    if (isSubtitle) {
      final track = state.activeSubtitleTrack ?? player.state.track.subtitle;
      final prefLang = (state.isAnime && pref.splitAnimePreferences)
          ? pref.animeSubtitleLanguage.toLowerCase()
          : pref.subtitleLanguage.toLowerCase();

      if (track.id == 'no' || track.id == 'auto') {
        if (track.id == 'no') return const Text('Off/None', style: TextStyle(color: AppTheme.textMuted));

        final subs = player.state.tracks.subtitle;
        final matched = subs.firstWhere(
          (t) => t.id != 'auto' && t.id != 'no' && LanguageMapper.isMatch(t, prefLang),
          orElse: () => subs.firstOrNull ?? track
        );

        final name = LanguageMapper.getDisplayLanguage(matched.title ?? matched.language ?? matched.id);
        return Text(name, style: const TextStyle(color: AppTheme.textMuted));
      }

      final name = LanguageMapper.getDisplayLanguage(track.title ?? track.language ?? track.id);
      return Text(name, style: const TextStyle(color: AppTheme.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis);
    } else {
      final track = state.activeAudioTrack ?? player.state.track.audio;
      final prefLang = (state.isAnime && pref.splitAnimePreferences)
          ? pref.animeAudioLanguage.toLowerCase()
          : pref.playerLanguage.toLowerCase();

      if (track.id == 'no' || track.id == 'auto') {
        if (track.id == 'no') return const Text('Off/None', style: TextStyle(color: AppTheme.textMuted));

        final audio = player.state.tracks.audio;
        final matched = audio.firstWhere(
          (t) => t.id != 'auto' && t.id != 'no' && LanguageMapper.isMatch(t, prefLang),
          orElse: () => audio.firstOrNull ?? track
        );

        final name = LanguageMapper.getDisplayLanguage(matched.title ?? matched.language ?? matched.id);
        return Text(name, style: const TextStyle(color: AppTheme.textMuted));
      }

      final name = LanguageMapper.getDisplayLanguage(track.title ?? track.language ?? track.id);
      return Text(name, style: const TextStyle(color: AppTheme.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis);
    }
  }
}

class TrackTile extends ConsumerWidget {
  final Player player;
  final dynamic track;
  final bool isSelected;
  final bool isSubtitle;
  final String? customTitle;
  final Color? color;
  final VoidCallback onBack;
  final VoidCallback? onSelected;

  const TrackTile({
    super.key,
    required this.player,
    required this.track,
    required this.isSelected,
    required this.isSubtitle,
    this.customTitle,
    this.color,
    required this.onBack,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = customTitle ?? LanguageMapper.getDisplayLanguage(track.title ?? track.language ?? track.id);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.accent.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppTheme.accent.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? (color ?? AppTheme.textWhite) : AppTheme.textWhite.withValues(alpha: 0.7),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 15,
          ),
        ),
        trailing: isSelected
            ? Icon(Icons.check_circle_rounded, color: color ?? AppTheme.accent, size: 20)
            : null,
        onTap: () {
          if (isSubtitle) {
            player.setSubtitleTrack(track);
          } else {
            player.setAudioTrack(track);
          }
          
          if (onSelected != null) {
            onSelected!();
          }
          
          onBack();
        },
      ),
    );
  }
}

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
        borderRadius: BorderRadius.circular(4),
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

  @override
  Widget build(BuildContext context) {
    final meta = stream.metadata;
    if (meta == null) {
       return Text(
        stream.title,
        style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (stream.isCached) const SettingsBadge(text: 'CACHED', color: Colors.greenAccent),
            if (meta.video.resolution != VideoResolution.unknown)
              SettingsBadge(text: meta.video.resolution.label, color: Colors.blueAccent),
            if (meta.video.isHDR) const SettingsBadge(text: 'HDR', color: Colors.orangeAccent),
            if (meta.video.isDV) const SettingsBadge(text: 'DV', color: Colors.orangeAccent),
            if (meta.video.is10Bit) const SettingsBadge(text: '10BIT', color: Colors.orangeAccent),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SettingsLabel(text: stream.provider, color: AppTheme.accent.withValues(alpha: 0.9)),
            if (meta.size != null) SettingsLabel(text: meta.size!, color: Colors.cyanAccent.withValues(alpha: 0.8)),
            ...meta.flags.where((f) => f != ReleaseFlag.none).map((f) => SettingsLabel(text: f.label, color: Colors.amberAccent.withValues(alpha: 0.8))),
            ...meta.audio.formats.map((a) => SettingsLabel(text: a.label, color: Colors.deepPurpleAccent.withValues(alpha: 0.8))),
            if (meta.languages.isNotEmpty) SettingsLabel(text: meta.languages.join(' • '), color: Colors.white70),
          ],
        ),
      ],
    );
  }
}
