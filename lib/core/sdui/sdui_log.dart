import 'package:flutter/foundation.dart';

/// Kinds of events recorded by the SDUI subsystem. Kept as plain strings so
/// new events can be added without touching the enum (and its consumers).
class SduiLogKind {
  static const String boot = 'boot';
  static const String fetchOk = 'fetch_ok';
  static const String fetchFail = 'fetch_fail';
  static const String notModified = 'not_modified';
  static const String cacheHit = 'cache_hit';
  static const String cacheWrite = 'cache_write';
  static const String cacheReadFail = 'cache_read_fail';
  static const String validation = 'validation';
  static const String widgetFallback = 'widget_fallback';
  static const String versionChange = 'version_change';
  static const String defaultConfig = 'default_config';
}

class SduiLogEntry {
  final DateTime at;
  final String kind;
  final String message;
  final String? key;

  const SduiLogEntry({
    required this.at,
    required this.kind,
    required this.message,
    this.key,
  });

  String get timestamp =>
      '${at.hour.toString().padLeft(2, '0')}:'
      '${at.minute.toString().padLeft(2, '0')}:'
      '${at.second.toString().padLeft(2, '0')}';

  @override
  String toString() =>
      '[sdui/$kind]${key == null ? '' : '($key)'} $message';
}

/// Bounded, in-memory ring buffer of the last [capacity] SDUI events.
///
/// Used by the diagnostics surface. Deliberately dependency-free and
/// allocation-cheap: SDUI must never be able to grow memory without limit.
class SduiLog {
  SduiLog._();

  static const int capacity = 100;

  static final List<SduiLogEntry?> _entries = List<SduiLogEntry?>.filled(
    capacity,
    null,
  );
  static int _cursor = 0;
  static int _total = 0;

  static void add(String kind, String message, {String? key}) {
    _entries[_cursor] = SduiLogEntry(
      at: DateTime.now(),
      kind: kind,
      message: message,
      key: key,
    );
    _cursor = (_cursor + 1) % capacity;
    _total++;
    if (kDebugMode) {
      debugPrint('[SDUI] [$kind]${key == null ? '' : '($key)'} $message');
    }
  }

  /// Entries newest-first, which is how diagnostics screens usually want them.
  static List<SduiLogEntry> entries() {
    final out = <SduiLogEntry>[];
    final count = _total < capacity ? _total : capacity;
    for (var i = 1; i <= count; i++) {
      final idx = (_cursor - i + capacity * 2) % capacity;
      final e = _entries[idx];
      if (e != null) out.add(e);
    }
    return out;
  }

  static List<String> lines() => entries().map((e) => e.toString()).toList();

  static int get totalEvents => _total;

  static void clear() {
    for (var i = 0; i < capacity; i++) {
      _entries[i] = null;
    }
    _cursor = 0;
    _total = 0;
  }
}