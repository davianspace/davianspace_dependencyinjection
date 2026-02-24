import 'package:davianspace_dependencyinjection/src/collection/service_collection.dart';

/// Base class for encapsulating a cohesive group of DI registrations.
///
/// Analogous to Autofac's `Module` or Scrutor-style installers in .NET.
/// Modules keep large applications organised by grouping related registrations
/// into a single, reusable unit.
///
/// ## Defining a module
///
/// ```dart
/// class DatabaseModule extends ServiceModule {
///   final String connectionString;
///   DatabaseModule(this.connectionString);
///
///   @override
///   void register(ServiceCollection services) {
///     services
///       ..addInstance<String>(connectionString)
///       ..addSingletonFactory<IDatabase>(
///           (p) => PostgresDatabase(p.getRequired<String>()))
///       ..addScoped<IUnitOfWork, EfUnitOfWork>();
///   }
/// }
/// ```
///
/// ## Using a module
///
/// ```dart
/// final provider = ServiceCollection()
///   ..addModule(DatabaseModule('postgres://localhost/mydb'))
///   ..addModule(AuthModule())
///   .buildServiceProvider();
/// ```
abstract class ServiceModule {
  const ServiceModule();

  /// Override to register services into [services].
  void register(ServiceCollection services);
}
