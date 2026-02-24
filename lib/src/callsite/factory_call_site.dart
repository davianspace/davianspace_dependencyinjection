import 'package:davianspace_dependencyinjection/src/callsite/call_site.dart';
import 'package:davianspace_dependencyinjection/src/callsite/call_site_kind.dart';

/// A call site resolved via a synchronous factory closure.
final class FactoryCallSite extends CallSite {
  /// The factory function.
  final Object Function(Object provider) factory;

  const FactoryCallSite({
    required super.serviceType,
    required super.lifetime,
    required this.factory,
  }) : super(kind: CallSiteKind.factory);
}
