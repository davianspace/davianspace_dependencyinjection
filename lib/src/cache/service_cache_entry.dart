import 'dart:async';

/// A single entry in [SingletonCache] or [ScopedCache].
///
/// During async initialization, [completer] is set immediately to prevent
/// concurrent double-initialisation races (same pattern as .NET's
/// `Lazy<T>` with `LazyThreadSafetyMode.ExecutionAndPublication`).
final class ServiceCacheEntry {
  /// The fully-resolved instance, or `null` while async init is in progress.
  Object? instance;

  /// Non-null only during an async factory initialisation.
  Completer<Object>? completer;

  ServiceCacheEntry({this.instance, this.completer});

  bool get isResolved => instance != null;
  bool get isPending => completer != null && !completer!.isCompleted;
}
