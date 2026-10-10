import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/navigation/application/back_navigation_notifier.dart';
import 'package:cinemuse_app/features/navigation/application/nav_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Reading a GlobalKey's state needs the widgets binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  final t0 = DateTime.utc(2026, 10, 10, 12);

  // The shell navigator key has no navigator here, so "close the open page"
  // never applies.
  BackOutcome back({bool canExitApp = true, DateTime? now}) => container
      .read(backNavigationProvider.notifier)
      .handleBack(canExitApp: canExitApp, now: now ?? t0);

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  test('on another tab, Back goes to Home (REV-09)', () {
    container.read(navIndexProvider.notifier).state = NavTab.explore;

    expect(back(), BackOutcome.handled);
    expect(container.read(navIndexProvider), NavTab.home);
  });

  test('in Live TV full-window, Back first leaves full-window', () {
    container.read(navIndexProvider.notifier).state = NavTab.liveTv;
    container.read(liveTvViewModeProvider.notifier).state =
        LiveTvViewMode.fullWindow;

    expect(back(), BackOutcome.handled);
    expect(container.read(liveTvViewModeProvider), LiveTvViewMode.split);
    expect(container.read(navIndexProvider), NavTab.liveTv);
  });

  test('on Home, the first Back asks, the second one in time exits', () {
    expect(back(now: t0), BackOutcome.confirmExit);
    expect(
      back(now: t0.add(const Duration(milliseconds: 1500))),
      BackOutcome.exit,
    );
  });

  test('on Home, a second Back after the window asks again', () {
    expect(back(now: t0), BackOutcome.confirmExit);
    expect(
      back(now: t0.add(const Duration(seconds: 3))),
      BackOutcome.confirmExit,
    );
  });

  test('on Home, Escape on PC never closes the app', () {
    expect(back(canExitApp: false), BackOutcome.handled);
    expect(back(canExitApp: false), BackOutcome.handled);
  });
}
