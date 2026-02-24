import 'package:davianspace_dependencyinjection/src/abstractions/service_provider_interface.dart';
import 'package:davianspace_dependencyinjection/src/abstractions/service_scope_interface.dart';
import 'package:davianspace_dependencyinjection/src/cache/scoped_cache.dart';
import 'package:davianspace_dependencyinjection/src/callsite/call_site.dart';
import 'package:davianspace_dependencyinjection/src/diagnostics/missing_service_exception.dart';
import 'package:davianspace_dependencyinjection/src/disposal/disposal_tracker.dart';
import 'package:davianspace_dependencyinjection/src/provider/root_service_provider.dart';
import 'package:davianspace_dependencyinjection/src/resolution/call_site_lookup.dart';
import 'package:davianspace_dependencyinjection/src/resolution/call_site_executor.dart';
import 'package:davianspace_dependencyinjection/src/resolution/resolution_chain.dart';

/// A [ServiceProviderBase] tied to a single [ServiceScope].
///
/// Owns its own [ScopedCache] and [DisposalTracker].
/// Singletons are always resolved through the shared [RootServiceProvider].
final class ScopedServiceProvider
    implements ServiceProviderBase, CallSiteLookup {
  final RootServiceProvider _root;
  final ScopedCache _scopedCache;
  final DisposalTracker _disposalTracker;

  bool _disposed = false;

  ScopedServiceProvider(this._root)
      : _scopedCache = ScopedCache(),
        _disposalTracker = DisposalTracker();

  // -------------------------------------------------------------------------
  // Guard
  // -------------------------------------------------------------------------

  void _assertNotDisposed() {
    if (_disposed) {
      throw StateError(
          'Cannot use a ServiceScope/ScopedServiceProvider that has been disposed.');
    }
  }

  // -------------------------------------------------------------------------
  // ServiceProviderBase
  // -------------------------------------------------------------------------

  @override
  T? tryGet<T extends Object>() {
    _assertNotDisposed();
    final cs = _root.callSites[T];
    if (cs == null) return null;
    return _execute(cs) as T;
  }

  @override
  T getRequired<T extends Object>() {
    _assertNotDisposed();
    final cs = _root.callSites[T];
    if (cs == null) throw MissingServiceException(T);
    return _execute(cs) as T;
  }

  @override
  List<T> getAll<T extends Object>() {
    _assertNotDisposed();
    final all = _root.allCallSites[T];
    if (all == null || all.isEmpty) return const [];
    return [for (final cs in all) _execute(cs) as T];
  }

  @override
  Future<T> getAsync<T extends Object>() async {
    _assertNotDisposed();
    final cs = _root.callSites[T];
    if (cs == null) throw MissingServiceException(T);
    return await _executeAsync(cs) as T;
  }

  @override
  Future<T?> tryGetAsync<T extends Object>() async {
    _assertNotDisposed();
    final cs = _root.callSites[T];
    if (cs == null) return null;
    return await _executeAsync(cs) as T;
  }

  @override
  T? tryGetKeyed<T extends Object>(Object key) {
    _assertNotDisposed();
    final cs = _root.keyedCallSites[(T, key)];
    if (cs == null) return null;
    return _execute(cs) as T;
  }

  @override
  T getRequiredKeyed<T extends Object>(Object key) {
    _assertNotDisposed();
    final cs = _root.keyedCallSites[(T, key)];
    if (cs == null) throw MissingServiceException(T, key: key);
    return _execute(cs) as T;
  }

  @override
  Future<T> getAsyncKeyed<T extends Object>(Object key) async {
    _assertNotDisposed();
    final cs = _root.keyedCallSites[(T, key)];
    if (cs == null) throw MissingServiceException(T, key: key);
    return await _executeAsync(cs) as T;
  }

  @override
  ServiceScopeBase createScope() {
    _assertNotDisposed();
    return ServiceScope(ScopedServiceProvider(_root));
  }

  // -------------------------------------------------------------------------
  // Convenience (on the concrete type)
  // -------------------------------------------------------------------------

  @override
  Object resolveRequired(Type type) {
    _assertNotDisposed();
    final cs = _root.callSites[type];
    if (cs == null) throw MissingServiceException(type);
    return _execute(cs);
  }

  /// Resolves all registrations for [type] as an untyped list.
  List<Object> resolveAll(Type type) {
    _assertNotDisposed();
    final all = _root.allCallSites[type];
    if (all == null || all.isEmpty) return const [];
    return [for (final cs in all) _execute(cs)];
  }

  /// Returns `true` if [T] has a registration.
  bool isRegistered<T extends Object>() => _root.callSites.containsKey(T);

  /// Returns `true` if [T] has a keyed registration for [key].
  bool isKeyedRegistered<T extends Object>(Object key) =>
      _root.keyedCallSites.containsKey((T, key));

  // -------------------------------------------------------------------------
  // CallSiteLookup
  // -------------------------------------------------------------------------

  @override
  CallSite? callSiteForType(Type type) => _root.callSites[type];

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  /// Whether this scope has been disposed.
  bool get isDisposed => _disposed;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _scopedCache.dispose();
    _disposalTracker.dispose();
    _root.diagnostics.trace('Scope disposed.');
  }

  Future<void> disposeAsync() async {
    if (_disposed) return;
    _disposed = true;
    _scopedCache.dispose();
    await _disposalTracker.disposeAsync();
    _root.diagnostics.trace('Scope disposed (async).');
  }

  // -------------------------------------------------------------------------
  // Internal
  // -------------------------------------------------------------------------

  Object _execute(CallSite cs) {
    final executor = CallSiteExecutor(
      singletonCache: _root.singletonCache,
      scopedCache: _scopedCache,
      disposalTracker: _disposalTracker,
      diagnostics: _root.diagnostics,
      providerRef: this,
    );
    return executor.resolve(cs, ResolutionChain());
  }

  Future<Object> _executeAsync(CallSite cs) async {
    final executor = CallSiteExecutor(
      singletonCache: _root.singletonCache,
      scopedCache: _scopedCache,
      disposalTracker: _disposalTracker,
      diagnostics: _root.diagnostics,
      providerRef: this,
    );
    return executor.resolveAsync(cs, ResolutionChain());
  }
}

/// Wrapper around a [ScopedServiceProvider] that also implements
/// [ServiceScopeBase], tying scope disposal to provider disposal.
final class ServiceScope implements ServiceScopeBase {
  final ScopedServiceProvider _provider;

  ServiceScope(this._provider);

  @override
  ServiceProviderBase get serviceProvider => _provider;

  @override
  void dispose() => _provider.dispose();

  @override
  Future<void> disposeAsync() => _provider.disposeAsync();
}
