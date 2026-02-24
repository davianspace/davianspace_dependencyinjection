import 'package:davianspace_dependencyinjection/src/callsite/call_site.dart';
import 'package:davianspace_dependencyinjection/src/callsite/call_site_kind.dart';
import 'package:davianspace_dependencyinjection/src/descriptors/service_lifetime.dart';

/// A call site backed by a pre-built [instance].
///
/// Only valid for [ServiceLifetime.singleton].
final class InstanceCallSite extends CallSite {
  /// The pre-built instance.
  final Object instance;

  const InstanceCallSite({
    required super.serviceType,
    required this.instance,
  }) : super(kind: CallSiteKind.instance, lifetime: ServiceLifetime.singleton);
}
