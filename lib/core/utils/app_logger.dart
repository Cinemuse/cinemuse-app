import 'dart:collection';

import 'package:flutter/foundation.dart';

/// How important a log line is. Ordered from least to most important.
enum LogLevel { debug, info, warn, error }

/// One line kept in [AppLogger.recent].
@immutable
class LogEntry {
  final DateTime time;
  final LogLevel level;
  final String tag;

  /// Already redacted.
  final String message;

  const LogEntry({
    required this.time,
    required this.level,
    required this.tag,
    required this.message,
  });

  @override
  String toString() =>
      '${time.toIso8601String()} ${level.name.toUpperCase()} [$tag] $message';
}

/// The app's only logger (see CONVENTIONS.md → Logging).
///
/// Every message is passed through [redact] before it is printed or stored,
/// as a safety net. Callers must still never log secrets on purpose.
abstract final class AppLogger {
  /// How many lines [recent] keeps, for the in-app debug panel.
  static const int maxRecent = 200;

  /// Lowest level that is printed and stored. Debug lines are dropped in
  /// release builds to keep the console and the [recent] buffer useful.
  static LogLevel minLevel = kReleaseMode ? LogLevel.info : LogLevel.debug;

  /// Where finished lines go. Tests replace it to capture output.
  static void Function(String line) sink = _defaultSink;

  static final ListQueue<LogEntry> _recent = ListQueue<LogEntry>();

  /// The last [maxRecent] lines, oldest first.
  static List<LogEntry> get recent => List.unmodifiable(_recent);

  static void debug(String tag, String message) =>
      log(LogLevel.debug, tag, message);

  static void info(String tag, String message) =>
      log(LogLevel.info, tag, message);

  static void warn(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) => log(LogLevel.warn, tag, message, error: error, stackTrace: stackTrace);

  static void error(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) => log(LogLevel.error, tag, message, error: error, stackTrace: stackTrace);

  /// Logs [message] at [level]. Prefer the level helpers above.
  static void log(
    LogLevel level,
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.index < minLevel.index) return;

    final buffer = StringBuffer(message);
    if (error != null) buffer.write(' | error: $error');
    if (stackTrace != null) buffer.write('\n$stackTrace');

    final entry = LogEntry(
      time: DateTime.now(),
      level: level,
      tag: tag,
      message: redact(buffer.toString()),
    );

    _recent.addLast(entry);
    while (_recent.length > maxRecent) {
      _recent.removeFirst();
    }
    sink(entry.toString());
  }

  /// Empties [recent]. For tests and a future "clear log" button.
  static void clearRecent() => _recent.clear();

  /// Replaces secrets in [text] with `***`.
  static String redact(String text) {
    var result = text;
    for (final rule in _redactions) {
      result = result.replaceAllMapped(rule.pattern, rule.replace);
    }
    return result;
  }

  static void _defaultSink(String line) => debugPrint(line);
}

class _Redaction {
  final RegExp pattern;
  final String Function(Match match) replace;

  const _Redaction(this.pattern, this.replace);
}

// Names whose value is a secret, in query params, JSON and `key=value` text.
// `username` is included because IPTV playlist URLs carry it next to the
// password (`get.php?username=…&password=…`).
const _secretNames =
    r'api[_-]?key|apikey|access[_-]?token|refresh[_-]?token|token|'
    r'password|passwd|pwd|secret|username';

final List<_Redaction> _redactions = [
  // user:pass@ in URLs: https://user:pass@host → https://***:***@host
  _Redaction(
    RegExp(r'([a-zA-Z][a-zA-Z0-9+.-]*://)[^\s/:@]+:[^\s/@]+@'),
    (m) => '${m[1]}***:***@',
  ),
  // Authorization headers: "Bearer abc" → "Bearer ***"
  _Redaction(
    RegExp(r'\b(Bearer|Basic)\s+[A-Za-z0-9\-._~+/]+=*', caseSensitive: false),
    (m) => '${m[1]} ***',
  ),
  // JWTs (Supabase access tokens, anon keys) anywhere in the text.
  _Redaction(
    RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'),
    (m) => '***',
  ),
  // ?api_key=…, &password=…, "token": "…", password: …
  _Redaction(
    RegExp(
      '(["\']?(?:$_secretNames)["\']?\\s*[=:]\\s*["\']?)[^\\s"\'&,;}#]+',
      caseSensitive: false,
    ),
    (m) => '${m[1]}***',
  ),
];
