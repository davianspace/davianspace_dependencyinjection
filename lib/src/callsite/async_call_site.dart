import 'package:davianspace_dependencyinjection/src/callsite/call_site.dart';
import 'package:davianspace_dependencyinjection/src/callsite/call_site_kind.dart';

/// A call site resolved via an asynchronous factory closure.
final class AsyncCallSite extends CallSite {
  /// The async factory function.
  final Future<Object> Function(Object provider) asyncFactory;

  const AsyncCallSite({
    required super.serviceType,
    required super.lifetime,
    required this.asyncFactory,
  }) : super(kind: CallSiteKind.asyncFactory);
}
