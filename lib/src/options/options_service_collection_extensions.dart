import 'package:davianspace_options/davianspace_options.dart';

import '../abstractions/disposable.dart';
import '../collection/service_collection.dart';

// =============================================================================
// OptionsServiceCollectionExtensions
// =============================================================================

/// Extension methods that add the full [davianspace_options] Options Pattern
/// to [ServiceCollection].
///
/// Three lifetimes are registered per options type [T]:
///
/// | Interface            | Lifetime  | Notes                           |
/// |----------------------|-----------|---------------------------------|
/// | `Options<T>`         | Singleton | Created once, cached forever    |
/// | `OptionsSnapshot<T>` | Scoped    | Fresh instance per scope        |
/// | `OptionsMonitor<T>`  | Singleton | Live reload via notifier        |
///
/// ## Basic usage
///
/// ```dart
/// final provider = ServiceCollection()
///   ..configure<DatabaseOptions>(
///     factory: DatabaseOptions.new,
///     configure: (opts) {
///       opts.host = env['DB_HOST'] ?? 'localhost';
///       opts.port = int.parse(env['DB_PORT'] ?? '5432');
///     },
///   )
///   ..postConfigure<DatabaseOptions>((opts) => opts.validate())
///   .buildServiceProvider();
///
/// // Singleton access:
/// final opts = provider.getRequired<Options<DatabaseOptions>>().value;
///
/// // Live reload  — signal the notifier registered keyed by the options type:
/// final notifier =
///     provider.getRequiredKeyed<OptionsChangeNotifier>(DatabaseOptions);
/// notifier.notifyChange(Options.defaultName);
/// ```
extension OptionsServiceCollectionExtensions on ServiceCollection {
  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// Registers [T] options with an optional [configure] callback for [name].
  ///
  /// [factory] must return a freshly constructed, mutable [T] on every call.
  ///
  /// Multiple calls with the same [T] **append** configure callbacks; the
  /// [factory] on subsequent calls is ignored (first factory wins). This
  /// mirrors the .NET `services.Configure<T>()` behaviour.
  ///
  /// ```dart
  /// services
  ///   ..configure<AppOptions>(factory: AppOptions.new,
  ///       configure: (o) => o.theme = 'dark')
  ///   ..configure<AppOptions>(factory: AppOptions.new,   // factory ignored
  ///       configure: (o) => o.logLevel = Level.warning);
  /// ```
  ServiceCollection configure<T extends Object>({
    required T Function() factory,
    void Function(T opts)? configure,
    String name = Options.defaultName,
  }) {
    final entry = _getOrCreateEntry<T>(factory);
    if (configure != null) {
      if (name.isEmpty) {
        entry.builder.configure(configure);
      } else {
        entry.builder.configureNamed(name, configure);
      }
    }
    _ensureOptionsRegistered<T>(entry);
    return this;
  }

  /// Adds a post-configure callback for [T] that runs **after** all
  /// [configure] callbacks — ideal for validation or cross-cutting concerns.
  ///
  /// Throws [StateError] if [configure] has not been called for [T] first.
  ///
  /// ```dart
  /// services
  ///   ..configure<AppOptions>(factory: AppOptions.new)
  ///   ..postConfigure<AppOptions>((opts) => opts.validate());
  /// ```
  ServiceCollection postConfigure<T extends Object>(
    void Function(T opts) postConfigureFn, {
    String name = Options.defaultName,
  }) {
    final existing = _entryFor<T>();
    if (existing == null) {
      throw StateError(
        'Cannot call postConfigure<$T> before configure<$T>. '
        'Register options with configure<$T>() first.',
      );
    }
    if (name.isEmpty) {
      existing.builder.postConfigure(postConfigureFn);
    } else {
      existing.builder.postConfigureNamed(name, postConfigureFn);
    }
    return this;
  }

  // -------------------------------------------------------------------------
  // Internals
  // -------------------------------------------------------------------------

  _OptionsEntry<T>? _entryFor<T extends Object>() {
    final e = optionsFactories[T];
    return e == null ? null : e as _OptionsEntry<T>;
  }

  _OptionsEntry<T> _getOrCreateEntry<T extends Object>(
    T Function() defaultFactory,
  ) {
    return (optionsFactories.putIfAbsent(
      T,
      () => _OptionsEntry<T>(defaultFactory),
    ) as _OptionsEntry<T>);
  }

  void _ensureOptionsRegistered<T extends Object>(_OptionsEntry<T> entry) {
    if (isRegistered<Options<T>>()) return;

    // Singleton: cached for the lifetime of the container.
    addSingletonFactory<Options<T>>(
      (_) => OptionsManager<T>(factory: _buildFactory(entry.builder)),
    );

    // Scoped: fresh OptionsManager (and therefore fresh cache) per scope.
    addScopedFactory<OptionsSnapshot<T>>(
      (_) => OptionsManager<T>(factory: _buildFactory(entry.builder)),
    );

    // Singleton monitor: responds to OptionsChangeNotifier.notifyChange().
    // Wrapped in _DisposableOptionsMonitor so the DI container cleans up
    // change-token subscriptions when the root provider is disposed.
    addSingletonFactory<OptionsMonitor<T>>(
      (_) => _DisposableOptionsMonitor<T>(
        OptionsMonitorImpl<T>(
          factory: _buildFactory(entry.builder),
          notifier: entry.notifier,
        ),
      ),
    );

    // Keyed notifier — trigger live reloads without a direct T reference:
    //   provider.getRequiredKeyed<OptionsChangeNotifier>(T)
    //           .notifyChange(Options.defaultName);
    addKeyedSingletonFactory<OptionsChangeNotifier>(
      T,
      (_, __) => entry.notifier,
    );
  }

  /// Builds an [OptionsFactoryImpl] from the *current* state of [builder].
  ///
  /// Called inside each singleton/scoped factory lambda so that configure
  /// callbacks registered after [configure]—but before first resolution—are
  /// still included (lazy evaluation of the action lists).
  static OptionsFactoryImpl<T> _buildFactory<T extends Object>(
    OptionsBuilder<T> builder,
  ) {
    return OptionsFactoryImpl<T>(
      instanceFactory: builder.factory,
      configureOptions: builder.configureActions,
      postConfigureOptions: builder.postConfigureActions,
      validators: builder.validators,
    );
  }
}

// =============================================================================
// _OptionsEntry — private per-type registration state
// =============================================================================

/// Pairs an [OptionsBuilder] with its dedicated [OptionsChangeNotifier].
///
/// One instance is created per distinct options type [T] and stored in
/// [ServiceCollection.optionsFactories] (keyed by [T]).
final class _OptionsEntry<T extends Object> {
  _OptionsEntry(T Function() factory)
      : builder = OptionsBuilder<T>(factory: factory),
        notifier = OptionsChangeNotifier();

  /// Accumulates configure / post-configure / validate callbacks.
  final OptionsBuilder<T> builder;

  /// Drives live-reload notifications for this options type.
  final OptionsChangeNotifier notifier;
}

// =============================================================================
// _DisposableOptionsMonitor — lifecycle-aware wrapper
// =============================================================================

/// Wraps [OptionsMonitorImpl] and implements [Disposable] so the DI container
/// automatically cancels change-token subscriptions when the root provider is
/// disposed — preventing listener leaks in long-running applications.
final class _DisposableOptionsMonitor<T extends Object>
    with Disposable
    implements OptionsMonitor<T> {
  _DisposableOptionsMonitor(this._impl);

  final OptionsMonitorImpl<T> _impl;

  @override
  T get currentValue => _impl.currentValue;

  @override
  T get(String name) => _impl.get(name);

  @override
  OptionsChangeRegistration onChange(
    void Function(T options, String name) listener,
  ) =>
      _impl.onChange(listener);

  @override
  void dispose() => _impl.dispose();
}
