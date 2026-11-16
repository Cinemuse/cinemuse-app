import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/core/application/provider_retry.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';

Channel _channel(String name, int lcn) =>
    Channel(lcn: lcn, name: name, logo: '');

void main() {
  final channels = [_channel('Rai 1', 1), _channel('Channel 50', 50)];

  /// Runs [body] with the channels loaded and a list of the channels found.
  void withEntry(
    void Function(
      FakeAsync async,
      ChannelNumberEntryNotifier entry,
      ProviderContainer container,
      List<Channel> found,
    )
    body,
  ) {
    fakeAsync((async) {
      final container = ProviderContainer(
        retry: noProviderRetry,
        overrides: [channelsProvider.overrideWith((ref) async => channels)],
      );
      container.listen(channelsProvider, (_, _) {});
      async.flushMicrotasks();
      final found = <Channel>[];
      body(
        async,
        container.read(channelNumberEntryProvider.notifier),
        container,
        found,
      );
      container.dispose();
    });
  }

  test('tunes 1.5 s after the last digit', () {
    withEntry((async, entry, container, found) {
      entry.type('5', onFound: found.add);
      async.elapse(const Duration(seconds: 1));
      entry.type('0', onFound: found.add);
      async.elapse(const Duration(milliseconds: 1400));
      expect(found, isEmpty);
      expect(container.read(channelNumberEntryProvider), '50');

      async.elapse(const Duration(milliseconds: 200));
      expect(found.single.name, 'Channel 50');
      expect(container.read(channelNumberEntryProvider), '');
    });
  });

  test('confirm tunes at once and stops the wait', () {
    withEntry((async, entry, container, found) {
      entry.type('1', onFound: found.add);
      entry.confirm();
      expect(found.single.name, 'Rai 1');

      async.elapse(const Duration(seconds: 2));
      expect(found, hasLength(1));
    });
  });

  test('takes at most four digits', () {
    withEntry((async, entry, container, found) {
      for (final digit in ['1', '2', '3', '4', '5']) {
        entry.type(digit, onFound: found.add);
      }
      expect(container.read(channelNumberEntryProvider), '1234');
    });
  });

  test('a number no channel has clears the digits and tunes nothing', () {
    withEntry((async, entry, container, found) {
      entry.type('7', onFound: found.add);
      async.elapse(const Duration(seconds: 2));
      expect(found, isEmpty);
      expect(container.read(channelNumberEntryProvider), '');
    });
  });

  test('clear drops the digits before they tune', () {
    withEntry((async, entry, container, found) {
      entry.type('1', onFound: found.add);
      entry.clear();
      async.elapse(const Duration(seconds: 2));
      expect(found, isEmpty);
    });
  });

  test('the number row and the number keypad type digits', () {
    expect(channelDigitFor(LogicalKeyboardKey.digit0), '0');
    expect(channelDigitFor(LogicalKeyboardKey.digit7), '7');
    expect(channelDigitFor(LogicalKeyboardKey.numpad0), '0');
    expect(channelDigitFor(LogicalKeyboardKey.numpad9), '9');
    expect(channelDigitFor(LogicalKeyboardKey.keyA), isNull);
  });
}
