import 'package:cinemuse_app/core/error/error_mappers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ErrorService extends Notifier<UserFriendlyError?> {
  @override
  UserFriendlyError? build() => null;

  void handle(Object error, {StackTrace? stackTrace}) {
    // 0. Log for debugging
    print('ErrorService: Handling error: $error');
    if (stackTrace != null) {
      print(stackTrace);
    }

    // 1. Map to user friendly error
    final mapped = ref.read(errorMapperProvider).map(error);

    // 2. Update state to trigger UI
    state = mapped;
  }

  void consume() {
    state = null;
  }
}

final errorServiceProvider = NotifierProvider<ErrorService, UserFriendlyError?>(() {
  return ErrorService();
});
