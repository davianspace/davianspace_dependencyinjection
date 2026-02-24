import 'package:davianspace_dependencyinjection/src/callsite/call_site.dart';
import 'package:davianspace_dependencyinjection/src/callsite/call_site_kind.dart';

/// A [CallSite] that wraps an existing call site with one or more decorators.
///
/// Created by [CallSiteResolver] when decorators are registered via
/// `ServiceCollection.decorate<T>(...)`.
final class DecoratorCallSite extends CallSite {
  /// The original call site whose instance is passed through the decorators.
  final CallSite inner;

  /// Ordered list of decorator closures.
  ///
  /// Each closure receives the current (decorated) instance and the provider
  /// reference, returning a new wrapper instance.
  final List<Object Function(Object inner, Object providerRef)> decorators;

  DecoratorCallSite({
    required super.serviceType,
    required super.lifetime,
    required this.inner,
    required this.decorators,
  }) : super(kind: CallSiteKind.decorator);
}
