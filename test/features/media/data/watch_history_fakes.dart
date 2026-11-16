import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Postgrest builders for the watch repository tests: `select()` and
// `rpc()` complete with a fixed value.
class FakeFilterBuilder<T> extends Fake implements PostgrestFilterBuilder<T> {
  final T _value;

  /// The columns passed to `order()`, in call order.
  final List<String> orders;
  FakeFilterBuilder(this._value, [List<String>? orders])
    : orders = orders ?? [];

  @override
  PostgrestFilterBuilder<T> eq(String column, Object value) => this;

  @override
  PostgrestFilterBuilder<T> limit(int count, {String? referencedTable}) => this;

  @override
  PostgrestFilterBuilder<T> range(
    int from,
    int to, {
    String? referencedTable,
  }) => this;

  @override
  PostgrestTransformBuilder<T> order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) {
    orders.add(column);
    return this;
  }

  /// Like Postgrest: the first row, or null when there is none.
  @override
  PostgrestTransformBuilder<Map<String, dynamic>?> maybeSingle() =>
      _FakeSingleBuilder(
        (_value as List?)?.firstOrNull as Map<String, dynamic>?,
      );

  @override
  Future<R> then<R>(
    FutureOr<R> Function(T value) onValue, {
    Function? onError,
  }) {
    return Future.value(_value).then(onValue, onError: onError);
  }
}

class _FakeSingleBuilder extends Fake
    implements PostgrestTransformBuilder<Map<String, dynamic>?> {
  final Map<String, dynamic>? _row;
  _FakeSingleBuilder(this._row);

  @override
  Future<R> then<R>(
    FutureOr<R> Function(Map<String, dynamic>? value) onValue, {
    Function? onError,
  }) => Future.value(_row).then(onValue, onError: onError);
}

class FakeQueryBuilder extends Fake implements SupabaseQueryBuilder {
  final dynamic _value;
  final orders = <String>[];
  FakeQueryBuilder([this._value]);

  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> select([
    String columns = '*',
  ]) {
    return FakeFilterBuilder<List<Map<String, dynamic>>>(
      (_value as List?)?.cast<Map<String, dynamic>>() ?? [],
      orders,
    );
  }

  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> upsert(
    Object values, {
    String? onConflict,
    bool ignoreDuplicates = false,
    bool defaultToNull = true,
  }) {
    return FakeFilterBuilder<List<Map<String, dynamic>>>([]);
  }

  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> delete() {
    return FakeFilterBuilder<List<Map<String, dynamic>>>([]);
  }

  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> update(Map values) {
    return FakeFilterBuilder<List<Map<String, dynamic>>>([]);
  }
}
