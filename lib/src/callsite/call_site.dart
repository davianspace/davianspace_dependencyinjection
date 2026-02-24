import 'package:davianspace_dependencyinjection/src/callsite/call_site_kind.dart';
import 'package:davianspace_dependencyinjection/src/descriptors/service_lifetime.dart';

/// Abstract base for all call sites.
///
/// A call site encodes both **how** to create a service (constructor,
/// factory, async-factory, instance) and **when** to cache it
/// (singleton, scoped, transient wrapper).
///
/// Call sites are built **once** during the container build phase and are
/// immutable after that, making resolution O(1) with a cached map lookup.
abstract base class CallSite {
  /// The type that this call site resolves.
  final Type serviceType;

  /// The strategy kind.
  final CallSiteKind kind;

  /// The lifetime this call site represents.
  final ServiceLifetime lifetime;

  const CallSite({
    required this.serviceType,
    required this.kind,
    required this.lifetime,
  });
}
