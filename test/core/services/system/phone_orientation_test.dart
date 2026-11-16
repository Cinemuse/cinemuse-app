import 'package:cinemuse_app/core/services/system/phone_orientation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The turns the app asked the system for, newest last.
  late List<List<String>> turns;

  setUp(() {
    turns = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'SystemChrome.setPreferredOrientations') {
            turns.add(List<String>.from(call.arguments as List));
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  const upright = ['DeviceOrientation.portraitUp'];
  const free = <String>[];

  group('isPhoneScreen', () {
    test('an Android phone is a phone', () {
      expect(
        PhoneOrientation.isPhoneScreen(
          isAndroid: true,
          isTV: false,
          screen: const Size(393, 852),
        ),
        isTrue,
      );
    });

    test('held sideways it is still a phone', () {
      expect(
        PhoneOrientation.isPhoneScreen(
          isAndroid: true,
          isTV: false,
          screen: const Size(852, 393),
        ),
        isTrue,
      );
    });

    test('a tablet, a TV and a PC are not', () {
      expect(
        PhoneOrientation.isPhoneScreen(
          isAndroid: true,
          isTV: false,
          screen: const Size(800, 1280),
        ),
        isFalse,
      );
      expect(
        PhoneOrientation.isPhoneScreen(
          isAndroid: true,
          isTV: true,
          screen: const Size(960, 540),
        ),
        isFalse,
      );
      expect(
        PhoneOrientation.isPhoneScreen(
          isAndroid: false,
          isTV: false,
          screen: const Size(900, 600),
        ),
        isFalse,
      );
    });
  });

  group('on a phone', () {
    setUp(() => PhoneOrientation.setUpForTesting(isPhone: true));

    test('the player turns freely, and upright again once closed', () async {
      await PhoneOrientation.playerOpened();
      expect(turns.last, free);
      await PhoneOrientation.playerClosed();
      expect(turns.last, upright);
    });

    test('leaving full screen in the player keeps it free', () async {
      await PhoneOrientation.playerOpened();
      await PhoneOrientation.exitFullscreen();
      expect(turns.last, free);
    });

    test('leaving full screen outside the player is upright', () async {
      // The small Live TV player on its page.
      await PhoneOrientation.exitFullscreen();
      expect(turns.last, upright);
    });

    test('the next episode opening before the old player closes', () async {
      await PhoneOrientation.playerOpened();
      await PhoneOrientation.playerOpened();
      await PhoneOrientation.playerClosed();
      expect(turns.last, free);
      await PhoneOrientation.playerClosed();
      expect(turns.last, upright);
    });
  });

  test('anywhere else the turn is never touched', () async {
    PhoneOrientation.setUpForTesting(isPhone: false);
    await PhoneOrientation.playerOpened();
    await PhoneOrientation.playerClosed();
    expect(turns, isEmpty);
  });
}
