import 'dart:ffi';
import 'dart:io';

import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// How much memory the device can still give to the app, in bytes, as the
/// system counts it (memory in use by caches it can drop counts as free).
class FreeMemoryReader {
  const FreeMemoryReader._();

  static const _logTag = 'FreeMemoryReader';
  static const MethodChannel _channel = MethodChannel('com.cinemuse/platform');

  /// Null when the system doesn't say: the caller then decides without it.
  static Future<int?> read() async {
    try {
      if (Platform.isAndroid) {
        return await _channel.invokeMethod<int>('freeMemory');
      }
      if (Platform.isLinux) {
        // A small file the kernel writes on the spot: read in one go.
        return parseMemAvailable(File('/proc/meminfo').readAsStringSync());
      }
      if (Platform.isWindows) return _windowsFreeMemory();
    } on Object catch (e, s) {
      AppLogger.warn(_logTag, 'Free memory not read', error: e, stackTrace: s);
    }
    return null;
  }

  /// The `MemAvailable` line of Linux's `/proc/meminfo`, which is in KiB.
  @visibleForTesting
  static int? parseMemAvailable(String meminfo) {
    final match = RegExp(
      r'^MemAvailable:\s+(\d+) kB',
      multiLine: true,
    ).firstMatch(meminfo);
    return match == null ? null : int.parse(match.group(1)!) * 1024;
  }

  // MEMORYSTATUSEX: a 4-byte size, a 4-byte load, then seven 8-byte counts;
  // the free physical memory is the second count.
  static const _statusSize = 64;
  static const _freePhysicalOffset = 16;

  // LMEM_ZEROINIT: LocalAlloc hands the block back filled with zeros.
  static const _zeroed = 0x40;

  // Windows' own allocator, so no package is needed for one small block.
  static int? _windowsFreeMemory() {
    final kernel32 = DynamicLibrary.open('kernel32.dll');
    final localAlloc = kernel32
        .lookupFunction<
          Pointer<Uint8> Function(Uint32, IntPtr),
          Pointer<Uint8> Function(int, int)
        >('LocalAlloc');
    final localFree = kernel32
        .lookupFunction<
          Pointer<Void> Function(Pointer<Uint8>),
          Pointer<Void> Function(Pointer<Uint8>)
        >('LocalFree');
    final globalMemoryStatusEx = kernel32
        .lookupFunction<
          Int32 Function(Pointer<Uint8>),
          int Function(Pointer<Uint8>)
        >('GlobalMemoryStatusEx');

    final status = localAlloc(_zeroed, _statusSize);
    if (status == nullptr) return null;
    try {
      status.cast<Uint32>().value = _statusSize;
      if (globalMemoryStatusEx(status) == 0) return null;
      return Pointer<Uint64>.fromAddress(
        status.address + _freePhysicalOffset,
      ).value;
    } finally {
      localFree(status);
    }
  }
}
