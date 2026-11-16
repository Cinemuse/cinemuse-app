import 'package:cinemuse_app/features/updates/domain/update_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final failed = UpdateState(status: UpdateStatus.initial).copyWith(
    status: UpdateStatus.error,
    errorKey: 'updateNetworkError',
    errorArgs: {'abi': 'x86'},
  );

  test('a new step clears the old error (REV-33)', () {
    final retrying = failed.copyWith(status: UpdateStatus.checking);

    expect(retrying.errorKey, isNull);
    expect(retrying.errorArgs, isNull);
  });

  test('a newer error replaces the old one', () {
    final again = failed
        .copyWith(status: UpdateStatus.downloading)
        .copyWith(status: UpdateStatus.error, errorKey: 'updateFailed');

    expect(again.errorKey, 'updateFailed');
    expect(again.errorArgs, isNull);
  });

  test('updating only the progress keeps the current state', () {
    final progressed = failed.copyWith(progress: 0.5);

    expect(progressed.errorKey, 'updateNetworkError');
  });
}
