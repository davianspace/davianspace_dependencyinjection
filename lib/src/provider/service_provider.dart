import 'package:davianspace_dependencyinjection/src/abstractions/async_disposable.dart';
import 'package:davianspace_dependencyinjection/src/abstractions/disposable.dart';
import 'package:davianspace_dependencyinjection/src/abstractions/service_provider_interface.dart';
import 'package:davianspace_dependencyinjection/src/abstractions/service_scope_interface.dart';
import 'package:davianspace_dependencyinjection/src/callsite/call_site.dart';
import 'package:davianspace_dependencyinjection/src/diagnostics/missing_service_exception.dart';
import 'package:davianspace_dependencyinjection/src/diagnostics/service_registration_info.dart';
import 'package:davianspace_dependencyinjection/src/provider/root_service_provider.dart';
import 'package:davianspace_dependencyinjection/src/provider/scoped_service_provider.dart';
import 'package:davianspace_dependencyinjection/src/resolution/call_site_lookup.dart';
import 'package:davianspace_dependencyinjection/src/resolution/call_site_executor.dart';
import 'package:davianspace_dependencyinjection/src/resolution/resolution_chain.dart';

/// The public-facing DI container.
///
/// Created via `ServiceCollection.buildServiceProvider()`.
/// Acts as the root provider: singletons are cached here; scoped services are
/// created per [ServiceScope].
///
/// Implements [Disposable] and [AsyncDisposable] — disposing the root provider
/// disposes all singleton services.
final class ServiceProvider
    implements
        ServiceProviderBase,
        Disposable,
        AsyncDisposable,
        CallSiteLookup {
  final RootServiceProvider _root;

  /// Cached executor — stateless across calls (all state is in the injected
  /// caches/tracker/provider). Eliminates a per-resolution allocation.
  late final CallSiteExecutor _executor = CallSiteExecutor(
    singletonCache: _root.singletonCache,
    scopedCache: null, // root has no scoped cache
    disposalTracker: _root.disposalTracker,
    diagnostics: _root.diagnostics,
    providerRef: this,
  );

  ServiceProvider(this._root) {
    _root.diagnostics.info(
        'ServiceProvider built with ${_root.callSites.length} service(s).');
  }

  // -------------------------------------------------------------------------
  // Guard
  // -------------------------------------------------------------------------

  void _assertNotDisposed() {
    if (_root.isDisposed) {
      throw StateError(
          'Cannot use a ServiceProvider that has been disposed.');
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
    _root.diagnostics.trace('Creating new scope.');
    return ServiceScope(ScopedServiceProvider(_root));
  }

  // -------------------------------------------------------------------------
  // CallSiteLookup
  // -------------------------------------------------------------------------

  @override
  CallSite? callSiteForType(Type type) => _root.callSites[type];

  // -------------------------------------------------------------------------
  // Disposal
  // -------------------------------------------------------------------------

  @override
  void dispose() => _root.dispose();

  @override
  Future<void> disposeAsync() => _root.disposeAsync();

  // -------------------------------------------------------------------------
  // Diagnostic helpers (available on the concrete type — not on the interface)
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

  /// Returns `true` if [T] has a registration in this container.
  bool isRegistered<T extends Object>() => _root.callSites.containsKey(T);

  /// Returns `true` if [T] has a keyed registration for [key].
  bool isKeyedRegistered<T extends Object>(Object key) =>
      _root.keyedCallSites.containsKey((T, key));

  /// Dumps the entire call site map as a human-readable string.
  String dumpRegistrations() {
    final sb = StringBuffer('ServiceProvider registrations '
        '(${_root.callSites.length}):\n');
    for (final entry in _root.callSites.entries) {
      sb.writeln('  ${entry.key} → ${entry.value.kind.name} '
          '[${entry.value.lifetime.name}]');
    }
    return sb.toString();
  }

  /// Returns a list of [ServiceRegistrationInfo] describing every registered
  /// service type, its lifetime, and how it is resolved.
  ///
  /// Useful for diagnostic dashboards, tests that verify registrations, and
  /// tooling that inspects the built container:
  /// ```dart
  /// for (final info in provider.getServiceDescriptions()) {
  ///   print('${info.serviceType} [${info.lifetimeName}] via ${info.strategyName}');
  /// }
  /// ```
  List<ServiceRegistrationInfo> getServiceDescriptions() {
    final result = <ServiceRegistrationInfo>[];
    for (final entry in _root.callSites.entries) {
      result.add(ServiceRegistrationInfo(
        serviceType: entry.key,
        lifetimeName: entry.value.lifetime.name,
        strategyName: entry.value.kind.name,
      ));
    }
    return List.unmodifiable(result);
  }

  // -------------------------------------------------------------------------
  // Internal
  // -------------------------------------------------------------------------

  Object _execute(CallSite cs) {
    return _executor.resolve(cs, ResolutionChain());
  }

  Future<Object> _executeAsync(CallSite cs) {
    return _executor.resolveAsync(cs, ResolutionChain());
  }
}
