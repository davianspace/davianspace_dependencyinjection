import 'dart:async';

import 'package:davianspace_dependencyinjection/src/cache/service_cache_entry.dart';

/// Per-scope cache for scoped service instances.
///
/// Each [ServiceScope] owns exactly one [ScopedCache]; it is discarded when
/// the scope is disposed.
final class ScopedCache {
  final _entries = <_ScopedKey, ServiceCacheEntry>{};

  bool _disposed = false;

  // -------------------------------------------------------------------------
  // Sync API
  // -------------------------------------------------------------------------

  Object? get(Type type, [Object? key]) {
    _assertNotDisposed();
    return _entries[_ScopedKey(type, key)]?.instance;
  }

  void set(Type type, Object instance, [Object? key]) {
    _assertNotDisposed();
    _entries[_ScopedKey(type, key)] = ServiceCacheEntry(instance: instance);
  }

  bool contains(Type type, [Object? key]) {
    _assertNotDisposed();
    return _entries[_ScopedKey(type, key)]?.isResolved ?? false;
  }

  // -------------------------------------------------------------------------
  // Async API
  // -------------------------------------------------------------------------

  Completer<Object>? getPendingCompleter(Type type, [Object? key]) {
    _assertNotDisposed();
    final entry = _entries[_ScopedKey(type, key)];
    if (entry == null || !entry.isPending) return null;
    return entry.completer;
  }

  void reserveAsync(Type type, Completer<Object> completer, [Object? key]) {
    _assertNotDisposed();
    _entries[_ScopedKey(type, key)] = ServiceCacheEntry(completer: completer);
  }

  void completeAsync(Type type, Object instance, [Object? key]) {
    _assertNotDisposed();
    final k = _ScopedKey(type, key);
    final entry = _entries[k];
    if (entry != null &&
        entry.completer != null &&
        !entry.completer!.isCompleted) {
      entry.completer!.complete(instance);
    }
    _entries[k] = ServiceCacheEntry(instance: instance);
  }

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  /// Whether this cache has been disposed.
  bool get isDisposed => _disposed;

  /// Marks this cache as disposed and clears all entries.
  void dispose() {
    _disposed = true;
    _entries.clear();
  }

  int get count => _entries.length;

  void _assertNotDisposed() {
    if (_disposed) {
      throw StateError('ScopedCache has been disposed. '
          'Do not resolve services from a disposed scope.');
    }
  }
}

final class _ScopedKey {
  final Type type;
  final Object? key;

  const _ScopedKey(this.type, this.key);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _ScopedKey && other.type == type && other.key == key);

  @override
  int get hashCode => Object.hash(type, key);
}
