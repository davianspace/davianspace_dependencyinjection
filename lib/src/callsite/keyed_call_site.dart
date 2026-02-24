import 'package:davianspace_dependencyinjection/src/callsite/call_site.dart';
import 'package:davianspace_dependencyinjection/src/callsite/call_site_kind.dart';

/// A call site that routes resolution through [KeyedServiceRegistry] by key.
final class KeyedCallSite extends CallSite {
  /// The inner call site selected by the key.
  final CallSite inner;

  /// The key used to look up this registration.
  final Object key;

  const KeyedCallSite({
    required super.serviceType,
    required super.lifetime,
    required this.inner,
    required this.key,
  }) : super(kind: CallSiteKind.keyed);
}
