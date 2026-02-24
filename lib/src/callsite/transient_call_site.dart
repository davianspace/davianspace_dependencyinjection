import 'package:davianspace_dependencyinjection/src/callsite/call_site.dart';
import 'package:davianspace_dependencyinjection/src/callsite/call_site_kind.dart';
import 'package:davianspace_dependencyinjection/src/descriptors/service_lifetime.dart';

/// Wraps an inner [CallSite] without any caching.
///
/// A new instance is created on every resolution. If the instance implements
/// [Disposable] or [AsyncDisposable] and is resolved from a scope, it is
/// registered with the scope's [DisposalTracker].
final class TransientCallSite extends CallSite {
  /// The inner call site that creates the instance.
  final CallSite inner;

  /// Optional keyed-service lookup key.
  final Object? key;

  const TransientCallSite({
    required super.serviceType,
    required this.inner,
    this.key,
  }) : super(kind: CallSiteKind.transient, lifetime: ServiceLifetime.transient);
}
