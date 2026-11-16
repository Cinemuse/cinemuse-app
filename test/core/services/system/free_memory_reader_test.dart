import 'package:cinemuse_app/core/services/system/free_memory_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Linux: the free memory is the MemAvailable line, in bytes', () {
    const meminfo =
        'MemTotal:        1720412 kB\n'
        'MemFree:           85740 kB\n'
        'MemAvailable:     230464 kB\n'
        'Cached:           262988 kB\n';

    expect(FreeMemoryReader.parseMemAvailable(meminfo), 230464 * 1024);
  });

  test('Linux: no MemAvailable line means unknown', () {
    expect(FreeMemoryReader.parseMemAvailable('MemTotal: 1 kB\n'), isNull);
  });

  // The tests run on Windows and Linux: the computer running them answers.
  test('this computer says how much memory is free', () async {
    final free = await FreeMemoryReader.read();

    expect(free, isNotNull);
    expect(free, greaterThan(64 * 1024 * 1024));
  });
}
