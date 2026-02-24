import 'package:davianspace_dependencyinjection/src/abstractions/async_disposable.dart';
import 'package:davianspace_dependencyinjection/src/abstractions/disposable.dart';
import 'package:davianspace_dependencyinjection/src/abstractions/service_provider_interface.dart';

/// Represents a logical scope in the DI container.
///
/// Analogous to `IServiceScope` in Microsoft.Extensions.DependencyInjection.
/// Every scope owns its own scoped-service cache and a disposal tracker.
/// Disposing the scope disposes all scoped and owned-transient services.
abstract class ServiceScopeBase with Disposable, AsyncDisposable {
  /// The [ServiceProviderBase] scoped to this instance's lifetime.
  ServiceProviderBase get serviceProvider;
}
