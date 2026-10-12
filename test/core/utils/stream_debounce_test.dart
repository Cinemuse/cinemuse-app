import 'dart:async';

import 'package:cinemuse_app/core/utils/stream_debounce.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const wait = Duration(milliseconds: 300);

  test('passes on only the last event of a burst', () {
    fakeAsync((async) {
      final source = StreamController<int>();
      addTearDown(source.close);
      final received = <int>[];
      source.stream.debounce(wait).listen(received.add);

      source
        ..add(1)
        ..add(2)
        ..add(3);
      async.elapse(const Duration(milliseconds: 100));
      expect(received, isEmpty);

      async.elapse(wait);
      expect(received, [3]);
    });
  });

  // REV-182: the old transformer listened forever, so a disposed provider
  // left its Supabase realtime channel open.
  test('cancelling the result cancels the source and the timer', () {
    fakeAsync((async) {
      var isSourceCancelled = false;
      final source = StreamController<int>(
        onCancel: () => isSourceCancelled = true,
      );
      addTearDown(source.close);
      final received = <int>[];
      final subscription = source.stream.debounce(wait).listen(received.add);

      source.add(1);
      unawaited(subscription.cancel());
      async.elapse(wait * 2);

      expect(isSourceCancelled, isTrue);
      expect(received, isEmpty);
    });
  });

  test('does not listen to the source until listened to', () {
    var isListened = false;
    final source = StreamController<int>(onListen: () => isListened = true);
    addTearDown(source.close);

    final debounced = source.stream.debounce(wait);
    expect(isListened, isFalse);

    debounced.listen((_) {});
    expect(isListened, isTrue);
  });
}
