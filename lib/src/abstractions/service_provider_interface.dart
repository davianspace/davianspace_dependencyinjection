import 'package:davianspace_dependencyinjection/src/abstractions/service_scope_interface.dart';

/// Core resolution contract for the DI container.
///
/// Analogous to `IServiceProvider` in Microsoft.Extensions.DependencyInjection.
/// The root [ServiceProvider] and every scoped provider implement this.
abstract class ServiceProviderBase {
  /// Returns `T` if registered, otherwise `null`.
  T? tryGet<T extends Object>();

  /// Returns `T` if registered, otherwise throws [MissingServiceException].
  T getRequired<T extends Object>();

  /// Returns all registrations for `T`.
  List<T> getAll<T extends Object>();

  /// Asynchronously resolves `T` (async factories / initialisation).
  Future<T> getAsync<T extends Object>();

  /// Asynchronously resolves `T`, returning `null` if not registered.
  Future<T?> tryGetAsync<T extends Object>();

  /// Resolves `T` by [key] (keyed service resolution).
  T? tryGetKeyed<T extends Object>(Object key);

  /// Resolves `T` by [key], throws if not found.
  T getRequiredKeyed<T extends Object>(Object key);

  /// Asynchronously resolves `T` by [key].
  Future<T> getAsyncKeyed<T extends Object>(Object key);

  /// Creates a new child scope.
  ServiceScopeBase createScope();

  /// Resolves a service by runtime [type] without a compile-time generic.
  ///
  /// Used internally by [ActivatorUtilities] and [ReflectionHelper] factories
  /// to resolve dependencies whose type is only known at runtime.
  /// Throws [MissingServiceException] if not registered.
  Object resolveRequired(Type type);
}
