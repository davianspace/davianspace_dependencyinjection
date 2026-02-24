import 'package:davianspace_dependencyinjection/src/abstractions/service_scope_interface.dart';

/// Factory for creating [ServiceScopeBase] instances.
///
/// Analogous to [Microsoft.Extensions.DependencyInjection.IServiceScopeFactory].
/// Registered automatically in every [ServiceProvider] at build time.
abstract class ServiceScopeFactoryBase {
  /// Creates a new [ServiceScopeBase].
  ///
  /// The caller is responsible for disposing the returned scope when work is done.
  ServiceScopeBase createScope();
}
