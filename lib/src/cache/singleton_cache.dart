import 'dart:async';

import 'package:davianspace_dependencyinjection/src/cache/service_cache_entry.dart';

/// Thread-safe (Dart isolate-safe) cache for singleton service instances.
///
/// Supports both synchronous and asynchronous resolution with
/// double-initialisation prevention via [Completer].
final class SingletonCache {
  final _entries = <_CacheKey, ServiceCacheEntry>{};

  // -------------------------------------------------------------------------
  // Sync API
  // -------------------------------------------------------------------------

  /// Returns the cached instance for [type] + optional [key], or `null`.
  Object? get(Type type, [Object? key]) {
    return _entries[_CacheKey(type, key)]?.instance;
  }

  /// Stores [instance] for [type] + optional [key].
  void set(Type type, Object instance, [Object? key]) {
    _entries[_CacheKey(type, key)] = ServiceCacheEntry(instance: instance);
  }

  /// Returns `true` if an instance is cached for [type] + [key].
  bool contains(Type type, [Object? key]) {
    return _entries[_CacheKey(type, key)]?.isResolved ?? false;
  }

  // -------------------------------------------------------------------------
  // Async API (Completer-based double-init prevention)
  // -------------------------------------------------------------------------

  /// Returns the [Completer] that is currently initialising [type] + [key],
  /// or `null` if no async init is in progress.
  Completer<Object>? getPendingCompleter(Type type, [Object? key]) {
    final entry = _entries[_CacheKey(type, key)];
    if (entry == null || !entry.isPending) return null;
    return entry.completer;
  }

  /// Registers a [Completer] as the in-progress async initialiser.
  ///
  /// Should be called **before** the async factory is invoked.
  void reserveAsync(Type type, Completer<Object> completer, [Object? key]) {
    _entries[_CacheKey(type, key)] = ServiceCacheEntry(completer: completer);
  }

  /// Completes the async reservation: stores the [instance] and clears the
  /// completer.
  void completeAsync(Type type, Object instance, [Object? key]) {
    final k = _CacheKey(type, key);
    final entry = _entries[k];
    if (entry != null &&
        entry.completer != null &&
        !entry.completer!.isCompleted) {
      entry.completer!.complete(instance);
    }
    _entries[k] = ServiceCacheEntry(instance: instance);
  }

  /// Removes the entry for [type] + [key] (used in tests / partial resets).
  void remove(Type type, [Object? key]) =>
      _entries.remove(_CacheKey(type, key));

  /// Clears every entry.
  void clear() => _entries.clear();

  /// Total number of cached entries.
  int get count => _entries.length;
}

// ---------------------------------------------------------------------------
// Equality key
// ---------------------------------------------------------------------------

final class _CacheKey {
  final Type type;
  final Object? key;

  const _CacheKey(this.type, this.key);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _CacheKey && other.type == type && other.key == key);

  @override
  int get hashCode => Object.hash(type, key);
}
