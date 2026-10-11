import 'dart:async';

import 'package:cinemuse_app/core/services/system/supabase_service.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/profile/application/profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

/// `from('user_stats').select().eq().maybeSingle()` answering [result].
class _FakeStatsQuery extends Fake implements SupabaseQueryBuilder {
  final Future<Map<String, dynamic>?> Function() result;
  _FakeStatsQuery(this.result);

  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> select([
    String columns = '*',
  ]) => _FakeFilter(result);
}

class _FakeFilter extends Fake
    implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {
  final Future<Map<String, dynamic>?> Function() result;
  _FakeFilter(this.result);

  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> eq(
    String column,
    Object value,
  ) => this;

  @override
  PostgrestTransformBuilder<Map<String, dynamic>?> maybeSingle() =>
      _FakeSingle(result);
}

class _FakeSingle extends Fake
    implements PostgrestTransformBuilder<Map<String, dynamic>?> {
  final Future<Map<String, dynamic>?> Function() result;
  _FakeSingle(this.result);

  @override
  Future<R> then<R>(
    FutureOr<R> Function(Map<String, dynamic>? value) onValue, {
    Function? onError,
  }) => result().then(onValue, onError: onError);
}

void main() {
  late _MockSupabaseClient supabase;
  late StreamController<List<WatchHistory>> history;
  late ProviderContainer container;
  late Future<Map<String, dynamic>?> Function() answer;

  setUp(() {
    supabase = _MockSupabaseClient();
    history = StreamController<List<WatchHistory>>.broadcast();
    when(
      () => supabase.from('user_stats'),
    ).thenAnswer((_) => _FakeStatsQuery(() => answer()));
    container = ProviderContainer(
      overrides: [
        userIdProvider.overrideWithValue('user-1'),
        supabaseClientProvider.overrideWithValue(supabase),
        watchHistoryStreamProvider.overrideWith((ref) => history.stream),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await history.close();
  });

  Future<AsyncValue<dynamic>> settle() async {
    final sub = container.listen(profileStatsProvider, (_, _) {});
    await pumpEventQueue();
    final value = container.read(profileStatsProvider);
    sub.close();
    return value;
  }

  test('a failed load is an error, not zero stats', () async {
    answer = () => Future.error(const PostgrestException(message: 'offline'));

    final stats = await settle();

    expect(stats.hasError, isTrue);
    expect(stats.hasValue, isFalse);
  });

  test('a failed refresh keeps the last stats', () async {
    final sub = container.listen(profileStatsProvider, (_, _) {});
    answer = () async => {'user_id': 'user-1', 'total_movies': 7};
    await pumpEventQueue();
    expect(container.read(profileStatsProvider).value?.totalMovies, 7);

    answer = () => Future.error(const PostgrestException(message: 'offline'));
    container.invalidate(profileStatsProvider);
    await pumpEventQueue();

    final stats = container.read(profileStatsProvider);
    expect(stats.hasError, isTrue);
    expect(stats.valueOrNull?.totalMovies, 7);
    sub.close();
  });
}
