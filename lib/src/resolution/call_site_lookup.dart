import 'package:davianspace_dependencyinjection/src/callsite/call_site.dart';

/// Internal contract allowing [CallSiteExecutor] to look up call sites for
/// constructor-injected dependencies from the provider without a circular
/// public API.
///
/// Implemented by both [ServiceProvider] and [ScopedServiceProvider].
abstract class CallSiteLookup {
  /// Returns the pre-built [CallSite] for [type], or `null` if not registered.
  CallSite? callSiteForType(Type type);
}
