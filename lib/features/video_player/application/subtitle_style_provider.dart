import 'package:cinemuse_app/features/settings/application/local_settings_service.dart';
import 'package:cinemuse_app/features/settings/domain/subtitle_style.dart';
import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The subtitle look on screen: the change made in this player, or else the
/// one saved in Settings. The appearance menu showed the defaults instead
/// while nothing was changed in the player (REV-170).
final effectiveSubtitleStyleProvider = Provider.autoDispose
    .family<SubtitleStyle, PlayerParams>((ref, params) {
      final custom = ref.watch(
        playerControllerProvider(
          params,
        ).select((s) => s.valueOrNull?.customSubtitleStyle),
      );
      return custom ??
          ref.watch(localSettingsProvider.select((s) => s.subtitleStyle));
    });
