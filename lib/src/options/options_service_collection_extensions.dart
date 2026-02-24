import 'package:davianspace_dependencyinjection/src/collection/service_collection.dart';
import 'package:davianspace_dependencyinjection/src/options/i_options.dart';
import 'package:davianspace_dependencyinjection/src/options/options_manager.dart';

/// Extension methods adding the Options Pattern to [ServiceCollection].
///
/// Analogous to `Microsoft.Extensions.Options`  three tiers of options:
///
/// | Name | DI lifetime | Re-computed per scope? |
/// |---|---|---|
/// | `IOptions<T>` | Singleton | No (built once) |
/// | `IOptionsSnapshot<T>` | Scoped | Yes (once per scope) |
/// | `IOptionsMonitor<T>` | Singleton | Yes (via [OptionsMonitor.reload]) |
///
/// These types live here now but will move to `davianspace_options` when that
/// package is published. The extension only uses the public
/// [ServiceCollection] API so extraction will be a clean package boundary.
///
/// ```dart
/// final provider = ServiceCollection()
///   ..configure<DatabaseOptions>(
///     factory: DatabaseOptions.new,
///     configure: (opts) {
///       opts.host = 'localhost';
///       opts.port = 5432;
///     },
///   )
///   ..postConfigure<DatabaseOptions>((opts) => opts.validate())
///   .buildServiceProvider();
///
/// // Inject: provider.getRequired<IOptions<DatabaseOptions>>().value
/// ```
extension OptionsServiceCollectionExtensions on ServiceCollection {
  /// Registers [T] options and adds an optional [configure] callback.
  ///
  /// [factory] must return a freshly constructed [T] with defaults applied.
  /// Automatically registers `IOptions<T>`, `IOptionsSnapshot<T>`, and
  /// `IOptionsMonitor<T>` on the first call for [T].
  ServiceCollection configure<T extends Object>({
    required T Function() factory,
    void Function(T opts)? configure,
    String name = '',
  }) {
    final optFact = _getOrCreateOptionsFactory<T>(factory);
    if (configure != null) {
      optFact.addConfigure(configure, name);
    }
    _ensureOptionsRegistered<T>(optFact);
    return this;
  }

  /// Adds a post-configure callback for [T] that runs after all [configure]
  /// callbacks  suitable for validation or cross-cutting concerns.
  ///
  /// Throws [StateError] if [configure] has not been called for [T] first.
  ServiceCollection postConfigure<T extends Object>(
    void Function(T opts) postConfigureFn, {
    String name = '',
  }) {
    final existing = _optionsFactoryFor<T>();
    if (existing == null) {
      throw StateError(
        'Cannot call postConfigure<$T> before configure<$T>. '
        'Register options with configure<$T>() first.',
      );
    }
    existing.addPostConfigure(postConfigureFn, name);
    return this;
  }

  // Stored on the ServiceCollection instance via optionsFactories field.

  OptionsFactory<T>? _optionsFactoryFor<T extends Object>() {
    final f = optionsFactories[T];
    return f == null ? null : f as OptionsFactory<T>;
  }

  OptionsFactory<T> _getOrCreateOptionsFactory<T extends Object>(
      T Function() defaultFactory) {
    return (optionsFactories.putIfAbsent(
      T,
      () => OptionsFactory<T>(defaultFactory),
    ) as OptionsFactory<T>);
  }

  void _ensureOptionsRegistered<T extends Object>(
      OptionsFactory<T> optionsFactory) {
    if (isRegistered<IOptions<T>>()) return;

    addSingletonFactory<IOptions<T>>(
      (_) => OptionsManager<T>(optionsFactory),
    );
    addScopedFactory<IOptionsSnapshot<T>>(
      (_) => OptionsSnapshot<T>(optionsFactory),
    );
    addSingletonFactory<IOptionsMonitor<T>>(
      (_) => OptionsMonitor<T>(optionsFactory),
    );
  }
}
