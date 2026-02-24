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
import 'package:davianspace_dependencyinjection/src/descriptors/keyed_service_descriptor.dart';
import 'package:davianspace_dependencyinjection/src/descriptors/service_descriptor.dart';
import 'package:davianspace_dependencyinjection/src/descriptors/service_lifetime.dart';
import 'package:davianspace_dependencyinjection/src/keyed/keyed_service_registry.dart';
import 'package:davianspace_dependencyinjection/src/resolution/dependency_graph.dart';
import 'package:davianspace_dependencyinjection/src/utils/type_registry.dart';

/// Converts [ServiceDescriptor]s into an immutable map of [CallSite]s.
///
/// Called once during `ServiceCollection.buildServiceProvider()`.
/// The resulting map is stored on the root provider for O(1) lookup.
final class CallSiteResolver {
  final TypeRegistry _registry;
  final KeyedServiceRegistry _keyedRegistry;
  final DependencyGraph _graph;
  final Map<Type, List<Object Function(Object inner, Object providerRef)>>
      _decorators;

  /// The built call site map.  `Type → CallSite` for regular services —
  /// last registration wins (for single-service resolution).
  /// Keyed services are indexed separately.
  final _callSites = <Type, CallSite>{};

  /// All call sites per type; supports multiple registrations for [getAll].
  final _allCallSites = <Type, List<CallSite>>{};

  /// Keyed call site map: `(Type, Object key) → CallSite`.
  final _keyedCallSites = <(Type, Object), CallSite>{};

  CallSiteResolver({
    required TypeRegistry registry,
    required KeyedServiceRegistry keyedRegistry,
    required DependencyGraph graph,
    Map<Type, List<Object Function(Object inner, Object providerRef)>>
        decorators = const {},
  })  : _registry = registry,
        _keyedRegistry = keyedRegistry,
        _graph = graph,
        _decorators = decorators;

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  /// Processes all registered descriptors and populates [callSites] and
  /// [keyedCallSites].
  void build() {
    // Process regular descriptors.
    for (final descriptor in _registry.all) {
      final callSite = _buildFromDescriptor(descriptor);
      _callSites[descriptor.serviceType] = callSite;
      (_allCallSites[descriptor.serviceType] ??= <CallSite>[]).add(callSite);
    }

    // Process keyed descriptors.
    for (final descriptor in _keyedRegistry.all) {
      final callSite = _buildKeyedFromDescriptor(descriptor);
      _keyedCallSites[(descriptor.serviceType, descriptor.key)] = callSite;
    }
  }

  /// Returns the built call site map for regular services (last-wins).
  Map<Type, CallSite> get callSites => Map.unmodifiable(_callSites);

  /// Returns all call sites per type (supports multiple registrations).
  Map<Type, List<CallSite>> get allCallSites => Map.unmodifiable(
      _allCallSites.map((k, v) => MapEntry(k, List<CallSite>.unmodifiable(v))));

  /// Returns the built call site map for keyed services.
  Map<(Type, Object), CallSite> get keyedCallSites =>
      Map.unmodifiable(_keyedCallSites);

  // -------------------------------------------------------------------------
  // Internal helpers
  // -------------------------------------------------------------------------

  CallSite _buildFromDescriptor(ServiceDescriptor descriptor) {
    _graph.addNode(descriptor.serviceType);

    final inner = _buildInner(descriptor);
    final lifetime =
        _wrapLifetime(descriptor.serviceType, inner, descriptor.lifetime);

    // Apply decorators if any are registered for this service type.
    final decs = _decorators[descriptor.serviceType];
    if (decs != null && decs.isNotEmpty) {
      return DecoratorCallSite(
        serviceType: descriptor.serviceType,
        lifetime: descriptor.lifetime,
        inner: lifetime,
        decorators: List.unmodifiable(decs),
      );
    }
    return lifetime;
  }

  CallSite _buildKeyedFromDescriptor(KeyedServiceDescriptor descriptor) {
    _graph.addNode(descriptor.serviceType);

    final inner = _buildInner(descriptor);
    final wrapped =
        _wrapLifetime(descriptor.serviceType, inner, descriptor.lifetime);
    return KeyedCallSite(
      serviceType: descriptor.serviceType,
      lifetime: descriptor.lifetime,
      inner: wrapped,
      key: descriptor.key,
    );
  }

  /// Builds the inner (creation-strategy) call site from a descriptor.
  CallSite _buildInner(ServiceDescriptor descriptor) {
    if (descriptor.isInstanceRegistration) {
      return InstanceCallSite(
        serviceType: descriptor.serviceType,
        instance: descriptor.instance!,
      );
    }

    if (descriptor.isFactoryRegistration) {
      return FactoryCallSite(
        serviceType: descriptor.serviceType,
        lifetime: descriptor.lifetime,
        factory: descriptor.factory!,
      );
    }

    if (descriptor.isAsyncFactoryRegistration) {
      return AsyncCallSite(
        serviceType: descriptor.serviceType,
        lifetime: descriptor.lifetime,
        asyncFactory: descriptor.asyncFactory!,
      );
    }

    if (descriptor.isTypeRegistration) {
      // Record graph edge: implementation depends on… nothing at build time.
      // Real edges are added when the factory is invoked; for graph purposes
      // we mark the implementation as part of the graph.
      _graph.addEdge(descriptor.serviceType, descriptor.implementationType!);
      return ConstructorCallSite(
        serviceType: descriptor.serviceType,
        lifetime: descriptor.lifetime,
        implementationType: descriptor.implementationType!,
      );
    }

    throw StateError(
        'ServiceDescriptor for ${descriptor.serviceType} has no valid '
        'registration strategy.');
  }

  /// Wraps [inner] in the appropriate lifetime call site.
  CallSite _wrapLifetime(
      Type serviceType, CallSite inner, ServiceLifetime lifetime) {
    switch (lifetime) {
      case ServiceLifetime.singleton:
        return SingletonCallSite(serviceType: serviceType, inner: inner);
      case ServiceLifetime.scoped:
        return ScopedCallSite(serviceType: serviceType, inner: inner);
      case ServiceLifetime.transient:
        return TransientCallSite(serviceType: serviceType, inner: inner);
    }
  }
}
