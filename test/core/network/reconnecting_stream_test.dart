import 'dart:async';

import 'package:cinemuse_app/core/network/reconnecting_stream.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hands out a new source on each subscribe, like `.stream()` opening a
/// new realtime channel, and remembers them all.
class _Sources {
  final List<StreamController<int>> all = [];
  final List<bool> isCancelled = [];

  StreamController<int> get last => all.last;

  Stream<int> subscribe() {
    final index = all.length;
    isCancelled.add(false);
    final controller = StreamController<int>(
      onCancel: () => isCancelled[index] = true,
    );
    all.add(controller);
    return controller.stream;
  }
}

void main() {
  const delays = [Duration(seconds: 1), Duration(seconds: 4)];

  // REV-285: a realtime error used to end live updates until a restart.
  test('subscribes again after an error and keeps the updates coming', () {
    fakeAsync((async) {
      final sources = _Sources();
      final received = <int>[];
      final errors = <Object>[];
      reconnectingStream(
        sources.subscribe,
        logTag: 'test',
        delays: delays,
      ).listen(received.add, onError: errors.add);
      async.flushMicrotasks();

      sources.last.add(1);
      sources.last.addError('channel error');
      async.flushMicrotasks();
      expect(sources.isCancelled.first, isTrue);
      expect(sources.all, hasLength(1));

      async.elapse(delays.first);
      expect(sources.all, hasLength(2));
      sources.last.add(2);
      async.flushMicrotasks();

      expect(received, [1, 2]);
      expect(errors, isEmpty); // the last value stays on screen
    });
  });

  test('subscribes again when the source closes', () {
    fakeAsync((async) {
      final sources = _Sources();
      final received = <int>[];
      reconnectingStream(
        sources.subscribe,
        logTag: 'test',
        delays: delays,
      ).listen(received.add);
      async.flushMicrotasks();

      sources.last.add(1);
      unawaited(sources.last.close());
      async.elapse(delays.first);
      sources.last.add(2);
      async.flushMicrotasks();

      expect(sources.all, hasLength(2));
      expect(received, [1, 2]);
    });
  });

  test('passes on an error before the first event, then retries', () {
    fakeAsync((async) {
      final sources = _Sources();
      final received = <int>[];
      final errors = <Object>[];
      reconnectingStream(
        sources.subscribe,
        logTag: 'test',
        delays: delays,
      ).listen(received.add, onError: errors.add);
      async.flushMicrotasks();

      sources.last.addError('offline');
      async.elapse(delays.first);
      sources.last.add(1);
      async.flushMicrotasks();

      expect(errors, ['offline']);
      expect(received, [1]);
    });
  });

  test('waits longer after each failure, and starts over after data', () {
    fakeAsync((async) {
      final sources = _Sources();
      reconnectingStream(
        sources.subscribe,
        logTag: 'test',
        delays: delays,
      ).listen((_) {}, onError: (_) {});
      async.flushMicrotasks();

      // An error followed by the close counts as one failure.
      sources.last.addError('down');
      unawaited(sources.last.close());
      async.elapse(delays[0]);
      expect(sources.all, hasLength(2));

      sources.last.addError('down');
      async.elapse(delays[0]);
      expect(sources.all, hasLength(2)); // now waits the second delay
      async.elapse(delays[1] - delays[0]);
      expect(sources.all, hasLength(3));

      sources.last.addError('down'); // the last delay repeats
      async.elapse(delays[1]);
      expect(sources.all, hasLength(4));

      sources.last.add(1);
      sources.last.addError('down');
      async.elapse(delays[0]);
      expect(sources.all, hasLength(5));
    });
  });

  test('cancelling closes the source and stops the retries', () {
    fakeAsync((async) {
      final sources = _Sources();
      final subscription = reconnectingStream(
        sources.subscribe,
        logTag: 'test',
        delays: delays,
      ).listen((_) {}, onError: (_) {});
      async.flushMicrotasks();

      sources.last.addError('down');
      async.flushMicrotasks();
      unawaited(subscription.cancel());
      async.elapse(delays.last * 2);
      expect(sources.all, hasLength(1));

      // Cancelling while connected closes that source.
      final second = _Sources();
      final live = reconnectingStream(
        second.subscribe,
        logTag: 'test',
      ).listen((_) {});
      async.flushMicrotasks();
      unawaited(live.cancel());
      async.flushMicrotasks();
      expect(second.isCancelled.single, isTrue);
    });
  });

  test('does not subscribe until listened to', () {
    final sources = _Sources();
    reconnectingStream(sources.subscribe, logTag: 'test');
    expect(sources.all, isEmpty);
  });
}
