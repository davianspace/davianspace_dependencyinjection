import 'package:davianspace_dependencyinjection/src/callsite/call_site.dart';
import 'package:davianspace_dependencyinjection/src/callsite/call_site_kind.dart';

/// A call site that creates a service via a registered constructor factory
/// from [ReflectionHelper].
///
/// [implementationType] is the concrete class to instantiate.
/// At build time, [ReflectionHelper] must have a factory registered for it.
final class ConstructorCallSite extends CallSite {
  /// The concrete type to instantiate.
  final Type implementationType;

  const ConstructorCallSite({
    required super.serviceType,
    required super.lifetime,
    required this.implementationType,
  }) : super(kind: CallSiteKind.constructor);
}
