import 'package:davianspace_configuration/davianspace_configuration.dart';

import '../collection/service_collection.dart';

// =============================================================================
// ConfigurationServiceCollectionExtensions
// =============================================================================

/// Extension methods that register [davianspace_configuration] types into
/// [ServiceCollection].
///
/// After calling [addConfiguration] or [addConfigurationBuilder],
/// [Configuration] (and [ConfigurationRoot] when applicable) become injectable
/// singletons throughout the DI container.
///
/// ## Typical setup
///
/// ```dart
/// final config = ConfigurationBuilder()
///     .addJsonFile('appsettings.json')
///     .addEnvironmentVariables()
///     .build();
///
/// final provider = ServiceCollection()
///   ..addConfiguration(config)
///   // Bind options directly from the config at registration time:
///   ..configure<DatabaseOptions>(
///     factory: DatabaseOptions.new,
///     configure: (opts) {
///       final s = config.getSection('Database');
///       opts.host = s['Host'] ?? 'localhost';
///       opts.port = int.parse(s['Port'] ?? '5432');
///     },
///   )
///   .buildServiceProvider();
///
/// // Inject Configuration anywhere:
/// class MyService {
///   MyService(this._config);
///   final Configuration _config;
/// }
/// ```
extension ConfigurationServiceCollectionExtensions on ServiceCollection {
  // -------------------------------------------------------------------------
  // addConfiguration
  // -------------------------------------------------------------------------

  /// Registers [configuration] as a singleton [Configuration].
  ///
  /// If [configuration] is also a [ConfigurationRoot] it is additionally
  /// registered as [ConfigurationRoot] so callers needing the concrete type
  /// can inject it without a cast.
  ///
  /// Uses try-add semantics: if [Configuration] is already registered this
  /// method is a no-op, allowing multiple modules to call it safely.
  ///
  /// ```dart
  /// final cfg = ConfigurationBuilder()
  ///     .addInMemory({'App:Name': 'Demo'})
  ///     .build();
  ///
  /// services.addConfiguration(cfg);
  ///
  /// // Inject:
  /// final name = provider.getRequired<Configuration>()['App:Name'];
  /// ```
  ServiceCollection addConfiguration(Configuration configuration) {
    if (!isRegistered<Configuration>()) {
      addInstance<Configuration>(configuration);
    }
    if (configuration is ConfigurationRoot &&
        !isRegistered<ConfigurationRoot>()) {
      addInstance<ConfigurationRoot>(configuration);
    }
    return this;
  }

  // -------------------------------------------------------------------------
  // addConfigurationBuilder
  // -------------------------------------------------------------------------

  /// Registers a [Configuration] singleton produced by [build].
  ///
  /// [build] receives a fresh [ConfigurationBuilder]; its return value is
  /// stored as the singleton. Uses try-add semantics.
  ///
  /// ```dart
  /// services.addConfigurationBuilder(
  ///   (b) => b
  ///       .addInMemory({'App:Version': '2.0'})
  ///       .addEnvironmentVariables()
  ///       .build(),
  /// );
  /// ```
  ServiceCollection addConfigurationBuilder(
    Configuration Function(ConfigurationBuilder builder) build,
  ) {
    if (!isRegistered<Configuration>()) {
      addSingletonFactory<Configuration>((_) => build(ConfigurationBuilder()));
    }
    return this;
  }
}
