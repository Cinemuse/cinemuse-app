import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';

Channel _channel(String name) => Channel(lcn: 0, name: name, logo: '');

void main() {
  late ProviderContainer container;
  late StateProvider<List<Channel>> listProvider;

  Future<void> setChannels(List<Channel> channels) async {
    container.read(listProvider.notifier).state = channels;
    await container.read(channelsProvider.future);
  }

  setUp(() async {
    listProvider = StateProvider<List<Channel>>((ref) => const []);
    container = ProviderContainer(
      overrides: [
        channelsProvider.overrideWith((ref) async => ref.watch(listProvider)),
      ],
    );
    addTearDown(container.dispose);
    container.listen(selectedChannelProvider, (_, __) {});
  });

  group('SelectedChannelNotifier (REV-271)', () {
    test('drops the channel when every playlist is removed', () async {
      final rai1 = _channel('Rai 1');
      await setChannels([rai1]);
      container.read(selectedChannelProvider.notifier).select(rai1);

      await setChannels(const []);

      expect(container.read(selectedChannelProvider), isNull);
    });

    test('drops the channel when its playlist is removed', () async {
      final rai1 = _channel('Rai 1');
      final la7 = _channel('La7');
      await setChannels([rai1, la7]);
      container.read(selectedChannelProvider.notifier).select(la7);

      await setChannels([rai1]);

      expect(container.read(selectedChannelProvider), isNull);
    });

    test('keeps the channel when the list reloads with it', () async {
      final rai1 = _channel('Rai 1');
      await setChannels([rai1]);
      container.read(selectedChannelProvider.notifier).select(rai1);

      // A reload makes new Channel objects with the same id.
      await setChannels([_channel('Rai 1'), _channel('La7')]);

      expect(container.read(selectedChannelProvider), same(rai1));
    });
  });
}
