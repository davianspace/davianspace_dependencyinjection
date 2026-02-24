import 'package:davianspace_dependencyinjection/src/callsite/call_site.dart';
import 'package:davianspace_dependencyinjection/src/callsite/call_site_kind.dart';
import 'package:davianspace_dependencyinjection/src/descriptors/service_lifetime.dart';

/// Wraps an inner [CallSite] and caches its result in [SingletonCache].
final class SingletonCallSite extends CallSite {
  /// The inner call site that actually creates the instance.
  final CallSite inner;

  /// Optional keyed-service lookup key.
  final Object? key;

  const SingletonCallSite({
    required super.serviceType,
    required this.inner,
    this.key,
  }) : super(kind: CallSiteKind.singleton, lifetime: ServiceLifetime.singleton);
}
