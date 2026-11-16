import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A value that callers set directly, such as a tab, a search text or a focus
/// callback. Replaces Riverpod's legacy `StateProvider`.
class SettableNotifier<T> extends Notifier<T> {
  SettableNotifier(this._initial);

  final T _initial;

  @override
  T build() => _initial;

  /// Replaces the value.
  void set(T value) => state = value;

  /// Replaces the value with one worked out from the current one.
  void update(T Function(T current) change) => state = change(state);
}
