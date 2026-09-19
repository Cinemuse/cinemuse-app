import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cinemuse_app/core/utils/platform_info.dart';
import 'package:cinemuse_app/core/application/display_mode_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PlatformInfo.setTvForTesting(null);
  });

  tearDown(() {
    PlatformInfo.setTvForTesting(null);
  });

  group('PlatformInfo', () {
    test('defaults to false for isTV in test environment', () {
      expect(PlatformInfo.isTV, isFalse);
    });

    test('respects setTvForTesting override', () {
      PlatformInfo.setTvForTesting(true);
      expect(PlatformInfo.isTV, isTrue);

      PlatformInfo.setTvForTesting(false);
      expect(PlatformInfo.isTV, isFalse);
    });
  });

  group('DisplayModeNotifier', () {
    test('initializes with standard mode by default on non-TV', () {
      final notifier = DisplayModeNotifier();
      expect(notifier.state, equals(DisplayMode.standard));
    });

    test('initializes with bigPicture mode when on TV', () {
      PlatformInfo.setTvForTesting(true);
      final notifier = DisplayModeNotifier();
      expect(notifier.state, equals(DisplayMode.bigPicture));
    });

    test('toggleMode switches between standard and bigPicture', () async {
      final notifier = DisplayModeNotifier();
      expect(notifier.state, equals(DisplayMode.standard));

      await notifier.toggleMode();
      expect(notifier.state, equals(DisplayMode.bigPicture));

      await notifier.toggleMode();
      expect(notifier.state, equals(DisplayMode.standard));
    });

    test('setMode updates state and persists preference', () async {
      final notifier = DisplayModeNotifier();
      await notifier.setMode(DisplayMode.bigPicture);
      expect(notifier.state, equals(DisplayMode.bigPicture));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('display_mode'), equals('bigPicture'));
    });
  });
}
