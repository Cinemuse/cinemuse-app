import 'package:cinemuse_app/features/video_player/application/helpers/live_buffer_size.dart';
import 'package:flutter_test/flutter_test.dart';

const _mib = 1024 * 1024;
const _gib = 1024 * _mib;

/// Rai 1 in 1080p declares 5,340,630 bits a second (measured 2026-11-07).
const _rai1 = 5340630;

void main() {
  group('before the channel says its rate', () {
    test('each kind of device gets its ceiling when memory is plentiful', () {
      for (final (device, ceiling) in [
        (LiveDevice.tv, 128 * _mib),
        (LiveDevice.phone, 256 * _mib),
        (LiveDevice.computer, 2048 * _mib),
      ]) {
        final size = LiveBufferSize.forChannel(
          device: device,
          rewindMinutes: 5,
          freeMemoryBytes: 16 * _gib,
        );
        expect(size.totalBytes, ceiling, reason: '$device');
      }
    });

    test('never more than half the free memory', () {
      // The Fire Stick had about 230 MB free while playing.
      final size = LiveBufferSize.forChannel(
        device: LiveDevice.tv,
        rewindMinutes: 5,
        freeMemoryBytes: 230 * _mib,
      );

      expect(size.totalBytes, 115 * _mib);
    });

    test('never under the floor, however little memory is free', () {
      final size = LiveBufferSize.forChannel(
        device: LiveDevice.phone,
        rewindMinutes: 5,
        freeMemoryBytes: 20 * _mib,
      );

      expect(size.totalBytes, LiveBufferSize.floorBytes);
    });

    test('unknown free memory: the device ceiling', () {
      final size = LiveBufferSize.forChannel(
        device: LiveDevice.tv,
        rewindMinutes: 5,
      );

      expect(size.totalBytes, 128 * _mib);
    });
  });

  group('once the channel says its rate', () {
    test('only what the rewind length needs, plus the 30 s ahead', () {
      final size = LiveBufferSize.forChannel(
        device: LiveDevice.computer,
        rewindMinutes: 5,
        freeMemoryBytes: 16 * _gib,
        bitsPerSecond: _rai1,
      );

      // 5 minutes of rewind and 30 s ahead, in whole bytes a second.
      expect(size.totalBytes, _rai1 ~/ 8 * 330);
    });

    test('a longer rewind than the memory allows stops at the limit', () {
      final size = LiveBufferSize.forChannel(
        device: LiveDevice.tv,
        rewindMinutes: 60,
        freeMemoryBytes: 16 * _gib,
        bitsPerSecond: _rai1,
      );

      expect(size.totalBytes, 128 * _mib);
    });

    test('a slow channel still gets the floor', () {
      final size = LiveBufferSize.forChannel(
        device: LiveDevice.tv,
        rewindMinutes: 2,
        bitsPerSecond: 128000,
      );

      expect(size.totalBytes, LiveBufferSize.floorBytes);
    });
  });

  test('most of it is ahead, and the rewind part is never zero', () {
    final size = LiveBufferSize.forChannel(
      device: LiveDevice.tv,
      rewindMinutes: 5,
    );

    expect(size.aheadBytes, 96 * _mib);
    expect(size.rewindBytes, 32 * _mib);
  });
}
