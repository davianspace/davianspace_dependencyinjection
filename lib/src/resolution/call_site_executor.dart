import 'dart:async';

import 'package:davianspace_dependencyinjection/src/cache/scoped_cache.dart';
import 'package:davianspace_dependencyinjection/src/cache/singleton_cache.dart';
import 'package:davianspace_dependencyinjection/src/callsite/async_call_site.dart';
import 'package:davianspace_dependencyinjection/src/callsite/call_site.dart';
import 'package:davianspace_dependencyinjection/src/callsite/constructor_call_site.dart';
import 'package:davianspace_dependencyinjection/src/callsite/decorator_call_site.dart';
import 'package:davianspace_dependencyinjection/src/callsite/factory_call_site.dart';
import 'package:davianspace_dependencyinjection/src/callsite/instance_call_site.dart';
import 'package:davianspace_dependencyinjection/src/callsite/keyed_call_site.dart';
import 'package:davianspace_dependencyinjection/src/callsite/scoped_call_site.dart';
import 'package:davianspace_dependencyinjection/src/callsite/singleton_call_site.dart';
import 'package:davianspace_dependencyinjection/src/callsite/transient_call_site.dart';
import 'package:davianspace_dependencyinjection/src/diagnostics/missing_service_exception.dart';
import 'package:davianspace_dependencyinjection/src/diagnostics/service_provider_diagnostics.dart';
import 'package:davianspace_dependencyinjection/src/disposal/disposal_tracker.dart';
import 'package:davianspace_dependencyinjection/src/resolution/call_site_lookup.dart';
import 'package:davianspace_dependencyinjection/src/resolution/resolution_chain.dart';
import 'package:davianspace_dependencyinjection/src/utils/reflection_helper.dart';

/// Executes a [CallSite] graph during service resolution.
///
/// A new [CallSiteExecutor] is created per top-level resolution call so that
/// each call gets its own [ResolutionChain] for thread-safety (Dart is
/// single-threaded within an isolate, so this is intra-frame safety).
final class CallSiteExecutor {
  final SingletonCache _singletonCache;
  final ScopedCache? _scopedCache;
  final DisposalTracker _disposalTracker;
  final ServiceProviderDiagnostics _diagnostics;

  /// A back-reference to the provider that initiated this resolution,
  /// passed into factory closures.
  final Object _providerRef;

  CallSiteExecutor({
    required SingletonCache singletonCache,
    required ScopedCache? scopedCache,
    required DisposalTracker disposalTracker,
    required ServiceProviderDiagnostics diagnostics,
    required Object providerRef,
  })  : _singletonCache = singletonCache,
        _scopedCache = scopedCache,
        _disposalTracker = disposalTracker,
        _diagnostics = diagnostics,
        _providerRef = providerRef;

  // -------------------------------------------------------------------------
  // Sync resolution
  // -------------------------------------------------------------------------

  /// Resolves [callSite] synchronously.
  Object resolve(CallSite callSite, ResolutionChain chain) {
    _diagnostics.trace('Resolving ${callSite.serviceType}',
        serviceType: callSite.serviceType);

    return chain.guard(callSite.serviceType, () {
      return switch (callSite) {
        InstanceCallSite(:final instance) => instance,
        SingletonCallSite(:final serviceType, :final inner, :final key) =>
          _resolveSingleton(serviceType, inner, chain, key),
        ScopedCallSite(:final serviceType, :final inner, :final key) =>
          _resolveScoped(serviceType, inner, chain, key),
        TransientCallSite(:final inner, :final key) =>
          _resolveTransient(inner, chain, key),
        KeyedCallSite(:final inner) => _resolveLifetime(inner, chain),
        _ => _resolveInner(callSite, chain),
      };
    });
  }

  Object _resolveSingleton(
      Type type, CallSite inner, ResolutionChain chain, Object? key) {
    final cached = _singletonCache.get(type, key);
    if (cached != null) {
      _diagnostics.trace('Singleton cache hit: $type', serviceType: type);
      return cached;
    }
    _diagnostics.trace('Singleton cache miss: $type', serviceType: type);
    final instance = _resolveInner(inner, chain);
    _singletonCache.set(type, instance, key);
    _disposalTracker.track(instance);
    return instance;
  }

  Object _resolveScoped(
      Type type, CallSite inner, ResolutionChain chain, Object? key) {
    final cache = _scopedCache;
    if (cache == null) {
      // Being resolved from root — treat as singleton.
      return _resolveSingleton(type, inner, chain, key);
    }
    final cached = cache.get(type, key);
    if (cached != null) {
      _diagnostics.trace('Scoped cache hit: $type', serviceType: type);
      return cached;
    }
    _diagnostics.trace('Scoped cache miss: $type', serviceType: type);
    final instance = _resolveInner(inner, chain);
    cache.set(type, instance, key);
    _disposalTracker.track(instance);
    return instance;
  }

  Object _resolveTransient(CallSite inner, ResolutionChain chain, Object? key) {
    final instance = _resolveInner(inner, chain);
    _disposalTracker.track(instance);
    return instance;
  }

  /// Resolves a lifetime-wrapping call site without re-entering [chain.guard].
  /// Used when the service type is already on the chain (e.g. keyed services
  /// whose outer wrapper type equals the inner type).
  Object _resolveLifetime(CallSite callSite, ResolutionChain chain) {
    return switch (callSite) {
      InstanceCallSite(:final instance) => instance,
      SingletonCallSite(:final serviceType, :final inner, :final key) =>
        _resolveSingleton(serviceType, inner, chain, key),
      ScopedCallSite(:final serviceType, :final inner, :final key) =>
        _resolveScoped(serviceType, inner, chain, key),
      TransientCallSite(:final inner, :final key) =>
        _resolveTransient(inner, chain, key),
      _ => _resolveInner(callSite, chain),
    };
  }

  Future<Object> _resolveLifetimeAsync(
      CallSite callSite, ResolutionChain chain) async {
    return switch (callSite) {
      InstanceCallSite(:final instance) => instance,
      SingletonCallSite(:final serviceType, :final inner, :final key) =>
        await _resolveSingletonAsync(serviceType, inner, chain, key),
      ScopedCallSite(:final serviceType, :final inner, :final key) =>
        await _resolveScopedAsync(serviceType, inner, chain, key),
      TransientCallSite(:final inner, :final key) =>
        await _resolveTransientAsync(inner, chain, key),
      _ => await _resolveInnerAsync(callSite, chain),
    };
  }

  Object _resolveInner(CallSite callSite, ResolutionChain chain) {
    return switch (callSite) {
      ConstructorCallSite(:final implementationType) =>
        _resolveConstructor(implementationType, chain),
      FactoryCallSite(:final factory) => factory(_providerRef),
      AsyncCallSite() =>
        throw StateError('Use resolveAsync() to resolve async call sites for '
            '${callSite.serviceType}.'),
      InstanceCallSite(:final instance) => instance,
      DecoratorCallSite(:final inner, :final decorators) =>
        _resolveDecorated(inner, decorators, chain),
      _ => resolve(callSite, chain),
    };
  }

  Object _resolveDecorated(
    CallSite inner,
    List<Object Function(Object, Object)> decorators,
    ResolutionChain chain,
  ) {
    var instance = _resolveLifetime(inner, chain);
    for (final dec in decorators) {
      instance = dec(instance, _providerRef);
    }
    return instance;
  }

  Object _resolveConstructor(Type implType, ResolutionChain chain) {
    final factory = ReflectionHelper.instance.factoryFor(implType);
    if (factory == null) {
      throw MissingServiceException(implType);
    }
    // The factory receives a resolver callback that propagates the SAME chain
    // so that transitive circular dependencies are detected correctly.
    return factory((Type dep) {
      return resolve(_requireCallSite(dep, chain), chain);
    });
  }

  // -------------------------------------------------------------------------
  // Async resolution
  // -------------------------------------------------------------------------

  Future<Object> resolveAsync(CallSite callSite, ResolutionChain chain) async {
    _diagnostics.trace('Async-resolving ${callSite.serviceType}',
        serviceType: callSite.serviceType);

    return chain.guardAsync(callSite.serviceType, () async {
      return switch (callSite) {
        InstanceCallSite(:final instance) => instance,
        SingletonCallSite(:final serviceType, :final inner, :final key) =>
          await _resolveSingletonAsync(serviceType, inner, chain, key),
        ScopedCallSite(:final serviceType, :final inner, :final key) =>
          await _resolveScopedAsync(serviceType, inner, chain, key),
        TransientCallSite(:final inner, :final key) =>
          await _resolveTransientAsync(inner, chain, key),
        KeyedCallSite(:final inner) =>
          await _resolveLifetimeAsync(inner, chain),
        _ => await _resolveInnerAsync(callSite, chain),
      };
    });
  }

  Future<Object> _resolveSingletonAsync(
      Type type, CallSite inner, ResolutionChain chain, Object? key) async {
    final cached = _singletonCache.get(type, key);
    if (cached != null) return cached;

    final pending = _singletonCache.getPendingCompleter(type, key);
    if (pending != null) return pending.future;

    final completer = Completer<Object>();
    _singletonCache.reserveAsync(type, completer, key);
    try {
      final instance = await _resolveInnerAsync(inner, chain);
      _singletonCache.completeAsync(type, instance, key);
      _disposalTracker.track(instance);
      return instance;
    } catch (e) {
      _singletonCache.remove(type, key);
      completer.completeError(e);
      rethrow;
    }
  }

  Future<Object> _resolveScopedAsync(
      Type type, CallSite inner, ResolutionChain chain, Object? key) async {
    final cache = _scopedCache;
    if (cache == null) {
      return _resolveSingletonAsync(type, inner, chain, key);
    }

    final cached = cache.get(type, key);
    if (cached != null) return cached;

    final pending = cache.getPendingCompleter(type, key);
    if (pending != null) return pending.future;

    final completer = Completer<Object>();
    cache.reserveAsync(type, completer, key);
    try {
      final instance = await _resolveInnerAsync(inner, chain);
      cache.completeAsync(type, instance, key);
      _disposalTracker.track(instance);
      return instance;
    } catch (e) {
      cache.dispose(); // clear poisoned entry
      completer.completeError(e);
      rethrow;
    }
  }

  Future<Object> _resolveTransientAsync(
      CallSite inner, ResolutionChain chain, Object? key) async {
    final instance = await _resolveInnerAsync(inner, chain);
    _disposalTracker.track(instance);
    return instance;
  }

  Future<Object> _resolveInnerAsync(
      CallSite callSite, ResolutionChain chain) async {
    return switch (callSite) {
      ConstructorCallSite(:final implementationType) =>
        _resolveConstructor(implementationType, chain),
      FactoryCallSite(:final factory) => factory(_providerRef),
      AsyncCallSite(:final asyncFactory) => asyncFactory(_providerRef),
      InstanceCallSite(:final instance) => instance,
      DecoratorCallSite(:final inner, :final decorators) =>
        await _resolveDecoratedAsync(inner, decorators, chain),
      _ => resolveAsync(callSite, chain),
    };
  }

  Future<Object> _resolveDecoratedAsync(
    CallSite inner,
    List<Object Function(Object, Object)> decorators,
    ResolutionChain chain,
  ) async {
    var instance = await _resolveLifetimeAsync(inner, chain);
    for (final dec in decorators) {
      instance = dec(instance, _providerRef);
    }
    return instance;
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  /// Returns the [CallSite] for [type] from the provider's map, or throws
  /// [MissingServiceException].
  CallSite _requireCallSite(Type type, ResolutionChain chain) {
    // The provider ref exposes a package-internal lookup hook.
    if (_providerRef case final CallSiteLookup lookup) {
      final cs = lookup.callSiteForType(type);
      if (cs != null) return cs;
    }
    throw MissingServiceException(type);
  }
}
