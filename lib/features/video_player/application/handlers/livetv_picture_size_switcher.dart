import 'dart:async';
import 'dart:convert';

import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:media_kit/media_kit.dart';

/// One picture size of a live stream and the engine's video track that
/// carries it.
class PictureSizeTrack {
  final int height;
  final String trackId;

  const PictureSizeTrack(this.height, this.trackId);
}

/// The picture sizes in mpv's `track-list` ([json]), biggest first: one per
/// height, the one with the most bits per second (Sky has two 480p).
List<PictureSizeTrack> pictureSizesFromTrackList(String json) {
  final decoded = jsonDecode(json);
  if (decoded is! List) return const [];
  final best = <int, ({String id, int bitrate})>{};
  for (final track in decoded) {
    if (track is! Map || track['type'] != 'video') continue;
    final height = track['demux-h'];
    final id = track['id'];
    if (height is! int || height <= 0 || id == null) continue;
    final bitrate = track['hls-bitrate'] is int
        ? track['hls-bitrate'] as int
        : 0;
    final current = best[height];
    if (current == null || bitrate > current.bitrate) {
      best[height] = (id: id.toString(), bitrate: bitrate);
    }
  }
  final heights = best.keys.toList()..sort((a, b) => b - a);
  return [for (final h in heights) PictureSizeTrack(h, best[h]!.id)];
}

/// The picture size of the live stream playing: the biggest, or the user's
/// pick until the channel changes.
///
/// mpv shows each size of a stream as a video track and never adapts by
/// itself. Changing the track in place froze the picture for up to 15 s and
/// then played with an empty buffer, so a new size reopens the stream with
/// that track chosen ([reopen]): about 2 s, with a full buffer, and mpv takes
/// the sound of the same size (Sky carries it inside each size).
///
/// The size never changes by itself: a reopen jumps back to live and drops
/// what was loaded, so the user decides. When the stream keeps buffering
/// ([_pausesToSuggest] pauses within [_pauseWindow]) and a smaller size
/// exists, [onSuggestLower] tells them, once per channel.
class LivePictureSizeSwitcher {
  final Player player;

  /// mpv's `track-list`, as JSON.
  final Future<String> Function() readTrackList;

  /// Opens the stream again; it plays [videoTrack].
  final void Function() reopen;

  /// The sizes, the pick or the size on screen changed.
  final void Function() onChanged;

  /// The stream keeps buffering: a lower size may help.
  final void Function() onSuggestLower;

  LivePictureSizeSwitcher({
    required this.player,
    required this.readTrackList,
    required this.reopen,
    required this.onChanged,
    required this.onSuggestLower,
  }) {
    _subscriptions = [
      player.stream.tracks.listen((_) => unawaited(_readSizes())),
      player.stream.height.listen((height) {
        if (height == _playing) return;
        _playing = height;
        onChanged();
      }),
      player.stream.buffering.listen(_onBuffering),
    ];
  }

  static const _logTag = 'LivePictureSize';
  static const int _pausesToSuggest = 3;
  static const Duration _pauseWindow = Duration(minutes: 2);

  /// Loading after an open or a seek isn't a pause; pauses count once it
  /// has played this long.
  static const Duration _settleTime = Duration(seconds: 10);

  late final List<StreamSubscription<Object?>> _subscriptions;
  List<PictureSizeTrack> _sizes = const [];
  String? _selectedTrack;
  int? _picked;
  int? _playing;

  bool _sawLoading = false;
  bool _settled = false;
  bool _suggested = false;
  int _recentPauses = 0;
  final List<Timer> _pauseTimers = [];
  Timer? _settleTimer;

  LivePictureSizes get value => LivePictureSizes(
    heights: [for (final s in _sizes) s.height],
    picked: _picked,
    playing: _playing,
  );

  /// The video track the next open plays: mpv's own pick (the biggest) when
  /// the user picked nothing.
  String get videoTrack {
    final height = _picked;
    if (height == null) return 'auto';
    for (final size in _sizes) {
      if (size.height == height) return size.trackId;
    }
    return 'auto';
  }

  /// Another channel or source: the biggest, sizes unknown until it opens.
  void reset() {
    _picked = null;
    _sizes = const [];
    _selectedTrack = null;
    _suggested = false;
  }

  /// The stream is (re)opening: its loading isn't a pause.
  void onOpening() {
    _unsettle();
    _clearPauses();
  }

  /// The user moved in the stream: the loading that follows isn't a pause,
  /// even when the part is already loaded (mpv says "buffering" briefly).
  void onSeek() => _unsettle();

  /// The user picked [height].
  void pick(int height) {
    if (height == _picked) return;
    _picked = height;
    onChanged();
    if (_wantedTrack != _selectedTrack) reopen();
  }

  void dispose() {
    for (final sub in _subscriptions) {
      unawaited(sub.cancel());
    }
    _clearPauses();
    _settleTimer?.cancel();
  }

  /// The track the current pick wants; with no pick, the biggest.
  String? get _wantedTrack {
    final track = videoTrack;
    return track == 'auto' ? _sizes.firstOrNull?.trackId : track;
  }

  Future<void> _readSizes() async {
    try {
      final json = await readTrackList();
      final sizes = pictureSizesFromTrackList(json);
      // A reopen empties the list for a moment: the sizes stay known.
      if (sizes.isEmpty) return;
      _sizes = sizes;
      _selectedTrack = _selectedVideoTrack(json);
      onChanged();
    } on Object catch (e, st) {
      // The panel shows no sizes; the stream plays on.
      AppLogger.warn(_logTag, 'Track list not read', error: e, stackTrace: st);
    }
  }

  static String? _selectedVideoTrack(String json) {
    final decoded = jsonDecode(json);
    if (decoded is! List) return null;
    for (final track in decoded) {
      if (track is Map &&
          track['type'] == 'video' &&
          track['selected'] == true) {
        return track['id']?.toString();
      }
    }
    return null;
  }

  void _unsettle() {
    _sawLoading = false;
    _settled = false;
    _settleTimer?.cancel();
  }

  void _onBuffering(bool isBuffering) {
    if (isBuffering) {
      _sawLoading = true;
      if (_settled) _countPause();
      return;
    }
    if (_sawLoading && !_settled && !(_settleTimer?.isActive ?? false)) {
      _settleTimer = Timer(_settleTime, () => _settled = true);
    }
  }

  void _countPause() {
    _recentPauses++;
    _pauseTimers.add(Timer(_pauseWindow, () => _recentPauses--));
    if (_recentPauses < _pausesToSuggest) return;
    _clearPauses();
    if (_suggested || !_hasSmaller) return;
    _suggested = true;
    AppLogger.info(_logTag, 'Buffering: suggesting a lower size');
    onSuggestLower();
  }

  bool get _hasSmaller {
    final current = _picked ?? _sizes.firstOrNull?.height;
    return current != null && _sizes.any((s) => s.height < current);
  }

  void _clearPauses() {
    for (final timer in _pauseTimers) {
      timer.cancel();
    }
    _pauseTimers.clear();
    _recentPauses = 0;
  }
}
