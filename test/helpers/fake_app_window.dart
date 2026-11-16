import 'package:cinemuse_app/core/services/system/app_full_screen.dart';

/// Records what the app asks of its window, instead of asking Windows.
class FakeAppWindow extends AppWindow {
  final fullScreenCalls = <bool>[];
  var closeCalls = 0;

  @override
  Future<void> setFullScreen(bool on) async => fullScreenCalls.add(on);

  @override
  Future<void> close() async => closeCalls++;
}
