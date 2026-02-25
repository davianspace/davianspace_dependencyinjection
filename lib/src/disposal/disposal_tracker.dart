import 'package:davianspace_dependencyinjection/src/abstractions/async_disposable.dart';
import 'package:davianspace_dependencyinjection/src/abstractions/disposable.dart';
import 'package:davianspace_dependencyinjection/src/diagnostics/disposal_exception.dart';

/// Tracks all disposable service instances created within a scope or the root.
///
/// Disposal is performed in **reverse creation order** to respect the natural
/// dependency order (consumers are disposed before their dependencies).
final class DisposalTracker {
  final _entries = <_DisposalEntry>[];
  bool _disposed = false;

  /// Registers [instance] for disposal tracking if it implements [Disposable]
  /// or [AsyncDisposable].
  ///
  /// Instances that implement neither are silently ignored.
  void track(Object instance) {
    if (_disposed) {
      throw StateError('Cannot track instances on a disposed DisposalTracker.');
    }
    if (instance is Disposable || instance is AsyncDisposable) {
      _entries.add(_DisposalEntry(instance));
    }
  }

  /// Whether this tracker has already been disposed.
  bool get isDisposed => _disposed;

  /// The number of tracked instances.
  int get count => _entries.length;

  /// Synchronously disposes all tracked instances in reverse creation order.
  ///
  /// Services that implement [AsyncDisposable] but not [Disposable] are
  /// skipped (use [disposeAsync] for those). Errors are collected and rethrown
  /// as a [DisposalException] for the first failing service, after which
  /// all remaining services are still attempted.
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    final errors = <(Type, Object)>[];
    for (final entry in _entries.reversed) {
      if (entry.instance is Disposable) {
        try {
          (entry.instance as Disposable).dispose();
        } catch (e) {
          errors.add((entry.instance.runtimeType, e));
        }
      }
    }
    _entries.clear();

    if (errors.isNotEmpty) {
      throw DisposalException(errors);
    }
  }

  /// Asynchronously disposes all tracked instances in reverse creation order.
  ///
  /// Awaits each [AsyncDisposable]. Synchronous [Disposable] instances are
  /// also disposed here so callers only need to call one method.
  Future<void> disposeAsync() async {
    if (_disposed) return;
    _disposed = true;

    final errors = <(Type, Object)>[];
    for (final entry in _entries.reversed) {
      try {
        if (entry.instance is AsyncDisposable) {
          await (entry.instance as AsyncDisposable).disposeAsync();
        } else if (entry.instance is Disposable) {
          (entry.instance as Disposable).dispose();
        }
      } catch (e) {
        errors.add((entry.instance.runtimeType, e));
      }
    }
    _entries.clear();

    if (errors.isNotEmpty) {
      throw DisposalException(errors);
    }
  }
}

final class _DisposalEntry {
  final Object instance;
  const _DisposalEntry(this.instance);
}
