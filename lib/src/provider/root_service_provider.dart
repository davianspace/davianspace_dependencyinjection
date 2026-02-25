import 'dart:async';

import 'package:davianspace_dependencyinjection/src/cache/singleton_cache.dart';
import 'package:davianspace_dependencyinjection/src/callsite/call_site.dart';
import 'package:davianspace_dependencyinjection/src/diagnostics/service_provider_diagnostics.dart';
import 'package:davianspace_dependencyinjection/src/disposal/disposal_tracker.dart';
import 'package:davianspace_dependencyinjection/src/provider/service_provider_options.dart';

/// The immutable root of the DI container.
///
/// Created once by [ServiceCollection.buildServiceProvider].
/// Holds the compiled call site map, the singleton cache, and the root
/// disposal tracker. Shared across all scopes.
final class RootServiceProvider {
  /// The compiled call site map: `Type → CallSite` (last-wins, for single resolution).
  final Map<Type, CallSite> callSites;

  /// All call sites indexed by type (supports multiple registrations for `getAll`).
  final Map<Type, List<CallSite>> allCallSites;

  /// The compiled keyed call site map: `(Type, Object key) → CallSite`.
  final Map<(Type, Object), CallSite> keyedCallSites;

  /// Shared singleton instance cache.
  final SingletonCache singletonCache;

  /// Root disposal tracker (singletons registered here).
  final DisposalTracker disposalTracker;

  /// Build-time and runtime options.
  final ServiceProviderOptions options;

  /// Diagnostics emitter.
  final ServiceProviderDiagnostics diagnostics;

  bool _disposed = false;

  RootServiceProvider({
    required this.callSites,
    required this.allCallSites,
    required this.keyedCallSites,
    required this.options,
    required this.diagnostics,
  })  : singletonCache = SingletonCache(),
        disposalTracker = DisposalTracker();

  /// Returns `true` if the root provider has been disposed.
  bool get isDisposed => _disposed;

  /// Disposes all singleton services in reverse creation order.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    diagnostics.info('Root provider disposing.');
    disposalTracker.dispose();
    // StreamController.close() returns a Future; unawaited is intentional
    // here — the sync dispose path cannot await it.  Async callers should
    // use disposeAsync() instead.
    unawaited(diagnostics.close());
  }

  /// Async version of [dispose].
  Future<void> disposeAsync() async {
    if (_disposed) return;
    _disposed = true;
    diagnostics.info('Root provider disposing (async).');
    await disposalTracker.disposeAsync();
    await diagnostics.close();
  }
}
