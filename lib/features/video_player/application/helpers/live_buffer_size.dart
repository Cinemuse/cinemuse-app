import 'dart:math';

/// The kinds of device the live buffer has a ceiling for.
enum LiveDevice { tv, phone, computer }

/// How much of a live channel the video engine keeps in memory: what lies
/// ahead of the picture (`demuxer-max-bytes`) and behind it, for rewinding
/// (`demuxer-max-back-bytes`).
///
/// Most of it is "ahead": after a rewind everything up to the live picture
/// counts as ahead, and when that part is full the engine stops downloading.
/// While nobody rewinds, the engine lends the unused ahead space to rewinding,
/// so the total is what limits how far back the user can go.
class LiveBufferSize {
  final int aheadBytes;
  final int rewindBytes;

  const LiveBufferSize({required this.aheadBytes, required this.rewindBytes});

  int get totalBytes => aheadBytes + rewindBytes;

  static const _mib = 1024 * 1024;

  /// The most a device ever gives the buffer. A Fire Stick has about 1.7 GB
  /// and was closing other apps with 256 MB of live buffer.
  static const ceilings = {
    LiveDevice.tv: 128 * _mib,
    LiveDevice.phone: 256 * _mib,
    LiveDevice.computer: 2048 * _mib,
  };

  /// Below this a channel stutters, whatever the memory.
  static const floorBytes = 32 * _mib;

  /// The player stays about 30 s behind live, already downloaded.
  static const _aheadSeconds = 30;

  /// The buffer for [rewindMinutes] of a channel sending [bitsPerSecond]
  /// (unknown before it opens), on [device] with [freeMemoryBytes] free
  /// (unknown when the system doesn't say): never above the device's ceiling
  /// or half the free memory.
  factory LiveBufferSize.forChannel({
    required LiveDevice device,
    required int rewindMinutes,
    int? freeMemoryBytes,
    int? bitsPerSecond,
  }) {
    var limit = ceilings[device]!;
    if (freeMemoryBytes != null) limit = min(limit, freeMemoryBytes ~/ 2);
    limit = max(limit, floorBytes);

    var total = limit;
    if (bitsPerSecond != null && bitsPerSecond > 0) {
      final needed = bitsPerSecond ~/ 8 * (rewindMinutes * 60 + _aheadSeconds);
      total = min(limit, max(needed, floorBytes));
    }
    // The rewind part can't be zero: the engine then keeps nothing behind
    // and lends it nothing either.
    final rewind = total ~/ 4;
    return LiveBufferSize(aheadBytes: total - rewind, rewindBytes: rewind);
  }

  @override
  bool operator ==(Object other) =>
      other is LiveBufferSize &&
      other.aheadBytes == aheadBytes &&
      other.rewindBytes == rewindBytes;

  @override
  int get hashCode => Object.hash(aheadBytes, rewindBytes);

  @override
  String toString() =>
      'LiveBufferSize(ahead: ${aheadBytes ~/ _mib} MiB, '
      'rewind: ${rewindBytes ~/ _mib} MiB)';
}
