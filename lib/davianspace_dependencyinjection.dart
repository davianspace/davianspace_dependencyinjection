/// A full-featured, enterprise-grade dependency injection container for Dart.
///
/// Equivalent to `Microsoft.Extensions.DependencyInjection` with modern
/// additions: keyed services (.NET 8 style), async service creation, scoped
/// providers, circular dependency detection, decorators, lazy resolution,
/// factory delegates, Options Pattern, service modules, and rich diagnostics.
///
/// ## Quick start
///
/// ```dart
/// import 'package:davianspace_dependencyinjection/davianspace_dependencyinjection.dart';
///
/// // 1. Register services
/// final provider = ServiceCollection()
///   ..addInstance<ILogger>(ConsoleLogger())
///   ..addSingletonFactory<IDatabase>((p) => Database(p.getRequired<ILogger>()))
///   ..addScoped<IUserRepository, UserRepository>()
///   ..addTransient<IEmailSender, SmtpEmailSender>()
///   .buildServiceProvider(ServiceProviderOptions.development);
///
/// // 2. Resolve services
/// final db = provider.getRequired<IDatabase>();
///
/// // 3. Create a scope
/// final scope = provider.createScope();
/// final repo = scope.serviceProvider.getRequired<IUserRepository>();
/// scope.dispose();
///
/// // 4. Dispose root
/// provider.dispose();
/// ```
library;

// --- Abstractions ---
export 'src/abstractions/disposable.dart';
export 'src/abstractions/async_disposable.dart';
export 'src/abstractions/service_provider_interface.dart';
export 'src/abstractions/service_scope_interface.dart';
export 'src/abstractions/service_scope_factory_interface.dart';

// --- Descriptors ---
export 'src/descriptors/service_lifetime.dart';
export 'src/descriptors/service_descriptor.dart';
export 'src/descriptors/keyed_service_descriptor.dart';

// --- Collection ---
export 'src/collection/service_collection.dart';
export 'src/collection/service_module.dart';

// --- Provider ---
export 'src/provider/service_provider.dart';
export 'src/provider/service_provider_options.dart';

// --- Scope ---
export 'src/scope/scope_manager.dart';

// --- Diagnostics ---
export 'src/diagnostics/diagnostic_event.dart';
export 'src/diagnostics/service_provider_diagnostics.dart';
export 'src/diagnostics/circular_dependency_exception.dart';
export 'src/diagnostics/missing_service_exception.dart';
export 'src/diagnostics/scope_violation_exception.dart';
export 'src/diagnostics/disposal_exception.dart';
export 'src/diagnostics/container_build_exception.dart';
export 'src/diagnostics/service_registration_info.dart';

// --- Utilities ---
export 'src/utils/reflection_helper.dart';
export 'src/utils/activator_utilities.dart';

// --- Lazy<T> ---
export 'src/lazy/lazy_service.dart';

// --- ServiceFactory<T> ---
export 'src/factory/service_factory.dart';

// --- Options Pattern (powered by davianspace_options) ---
// Import davianspace_options directly for Options<T>, OptionsSnapshot<T>,
// OptionsMonitor<T>, OptionsChangeNotifier and all supporting types.
// Use configure<T> / postConfigure<T> on ServiceCollection to register.
export 'src/options/options_service_collection_extensions.dart';

// --- Configuration (powered by davianspace_configuration) ---
// Import davianspace_configuration directly for Configuration,
// ConfigurationRoot, ConfigurationBuilder and providers.
// Use addConfiguration / addConfigurationBuilder on ServiceCollection.
export 'src/configuration/configuration_service_collection_extensions.dart';
