import 'package:davianspace_dependencyinjection/src/abstractions/service_provider_interface.dart';
import 'package:davianspace_dependencyinjection/src/callsite/call_site.dart';
import 'package:davianspace_dependencyinjection/src/collection/service_module.dart';
import 'package:davianspace_dependencyinjection/src/descriptors/keyed_service_descriptor.dart';
import 'package:davianspace_dependencyinjection/src/descriptors/service_descriptor.dart';
import 'package:davianspace_dependencyinjection/src/descriptors/service_lifetime.dart';
import 'package:davianspace_dependencyinjection/src/diagnostics/container_build_exception.dart';
import 'package:davianspace_dependencyinjection/src/diagnostics/service_provider_diagnostics.dart';
import 'package:davianspace_dependencyinjection/src/factory/service_factory.dart';
import 'package:davianspace_dependencyinjection/src/keyed/keyed_service_registry.dart';
import 'package:davianspace_dependencyinjection/src/lazy/lazy_service.dart';
import 'package:davianspace_dependencyinjection/src/provider/root_service_provider.dart';
import 'package:davianspace_dependencyinjection/src/provider/service_provider.dart';
import 'package:davianspace_dependencyinjection/src/provider/service_provider_options.dart';
import 'package:davianspace_dependencyinjection/src/resolution/call_site_resolver.dart';
import 'package:davianspace_dependencyinjection/src/resolution/call_site_validator.dart';
import 'package:davianspace_dependencyinjection/src/resolution/dependency_graph.dart';
import 'package:davianspace_dependencyinjection/src/utils/type_registry.dart';

/// The mutable registry of service descriptors.
///
/// Analogous to `ServiceCollection` in Microsoft.Extensions.DependencyInjection.
/// Once all services have been registered, call [buildServiceProvider] to
/// produce an immutable, validated [ServiceProvider].
///
/// ```dart
/// final provider = ServiceCollection()
///   ..addSingleton<ILogger, ConsoleLogger>()
///   ..addScoped<IRepository, UserRepository>()
///   ..addTransient<IEmailSender, SmtpEmailSender>()
///   .buildServiceProvider();
/// ```
final class ServiceCollection {
  final _registry = TypeRegistry();
  final _keyedRegistry = KeyedServiceRegistry();
  final _decorators =
      <Type, List<Object Function(Object inner, ServiceProviderBase p)>>{};
  final _buildHooks = <void Function(ServiceProvider provider)>[];
  final _asyncBuildHooks = <Future<void> Function(ServiceProvider provider)>[];
  // Options factories: Type → OptionsFactory<T>  (stored as Object to be
  // generic-safe; casts are done in the extension).
  final optionsFactories = <Type, Object>{};
  bool _built = false;

  // =========================================================================
  // Low-level registration
  // =========================================================================

  /// Adds a [ServiceDescriptor] directly.
  ServiceCollection add(ServiceDescriptor descriptor) {
    _assertNotBuilt();
    _registry.add(descriptor);
    return this;
  }

  /// Adds a [KeyedServiceDescriptor] directly.
  ServiceCollection addKeyed(KeyedServiceDescriptor descriptor) {
    _assertNotBuilt();
    _keyedRegistry.add(descriptor);
    return this;
  }

  /// Adds [descriptor] only if no registration for [serviceType] yet exists.
  ServiceCollection tryAdd(ServiceDescriptor descriptor) {
    _assertNotBuilt();
    if (!_registry.contains(descriptor.serviceType)) {
      _registry.add(descriptor);
    }
    return this;
  }

  /// Adds [descriptor] only if no keyed registration for that type+key exists.
  ServiceCollection tryAddKeyed(KeyedServiceDescriptor descriptor) {
    _assertNotBuilt();
    if (!_keyedRegistry.contains(descriptor.serviceType, descriptor.key)) {
      _keyedRegistry.add(descriptor);
    }
    return this;
  }

  /// Adds all [descriptors] in one call.
  ServiceCollection addRange(Iterable<ServiceDescriptor> descriptors) {
    for (final d in descriptors) {
      add(d);
    }
    return this;
  }

  /// Removes any existing registration for [TService] and adds [TImpl].
  ///
  /// Equivalent to calling [_registry.remove] then [addSingleton] (or the
  /// appropriate lifetime version via the raw [add] overload).
  ServiceCollection replace(ServiceDescriptor descriptor) {
    _assertNotBuilt();
    _registry.removeAll(descriptor.serviceType);
    _registry.add(descriptor);
    return this;
  }

  /// Removes **all** registrations for [TService].
  ///
  /// Useful for test tear-down or overriding a module's registrations:
  /// ```dart
  /// services
  ///   ..addModule(InfrastructureModule())
  ///   ..removeAll<ILogger>()   // remove the module's logger
  ///   ..addInstance<ILogger>(NullLogger());
  /// ```
  ServiceCollection removeAll<TService extends Object>() {
    _assertNotBuilt();
    _registry.removeAll(TService);
    return this;
  }

  // =========================================================================
  // Singleton
  // =========================================================================

  /// Registers [TImpl] as [TService] with a singleton lifetime.
  ServiceCollection
      addSingleton<TService extends Object, TImpl extends TService>() {
    return add(ServiceDescriptor.type(
      serviceType: TService,
      implementationType: TImpl,
      lifetime: ServiceLifetime.singleton,
    ));
  }

  /// Registers [TService] as a singleton using a synchronous [factory].
  ServiceCollection addSingletonFactory<TService extends Object>(
    TService Function(ServiceProviderBase provider) factory,
  ) {
    return add(ServiceDescriptor.factoryFn(
      serviceType: TService,
      lifetime: ServiceLifetime.singleton,
      factory: (p) => factory(p as ServiceProviderBase),
    ));
  }

  /// Registers [TService] as a singleton using an asynchronous [factory].
  ServiceCollection addSingletonAsync<TService extends Object>(
    Future<TService> Function(ServiceProviderBase provider) factory,
  ) {
    return add(ServiceDescriptor.asyncFactoryFn(
      serviceType: TService,
      lifetime: ServiceLifetime.singleton,
      asyncFactory: (p) async => factory(p as ServiceProviderBase),
    ));
  }

  /// Registers a pre-built [instance] as a singleton.
  ServiceCollection addInstance<TService extends Object>(TService instance) {
    return add(ServiceDescriptor.instanceValue(
      serviceType: TService,
      instance: instance,
    ));
  }

  /// Registers [TImpl] as [TService] singleton only if [TService] is not yet
  /// registered (try-add semantics).
  ServiceCollection
      tryAddSingleton<TService extends Object, TImpl extends TService>() {
    return tryAdd(ServiceDescriptor.type(
      serviceType: TService,
      implementationType: TImpl,
      lifetime: ServiceLifetime.singleton,
    ));
  }

  // =========================================================================
  // Scoped
  // =========================================================================

  /// Registers [TImpl] as [TService] with a scoped lifetime.
  ServiceCollection
      addScoped<TService extends Object, TImpl extends TService>() {
    return add(ServiceDescriptor.type(
      serviceType: TService,
      implementationType: TImpl,
      lifetime: ServiceLifetime.scoped,
    ));
  }

  /// Registers [TService] as scoped with a synchronous [factory].
  ServiceCollection addScopedFactory<TService extends Object>(
    TService Function(ServiceProviderBase provider) factory,
  ) {
    return add(ServiceDescriptor.factoryFn(
      serviceType: TService,
      lifetime: ServiceLifetime.scoped,
      factory: (p) => factory(p as ServiceProviderBase),
    ));
  }

  /// Registers [TService] as scoped with an asynchronous [factory].
  ServiceCollection addScopedAsync<TService extends Object>(
    Future<TService> Function(ServiceProviderBase provider) factory,
  ) {
    return add(ServiceDescriptor.asyncFactoryFn(
      serviceType: TService,
      lifetime: ServiceLifetime.scoped,
      asyncFactory: (p) async => factory(p as ServiceProviderBase),
    ));
  }

  /// Registers [TImpl] as [TService] scoped only if [TService] is not yet
  /// registered (try-add semantics).
  ServiceCollection
      tryAddScoped<TService extends Object, TImpl extends TService>() {
    return tryAdd(ServiceDescriptor.type(
      serviceType: TService,
      implementationType: TImpl,
      lifetime: ServiceLifetime.scoped,
    ));
  }

  // =========================================================================
  // Transient
  // =========================================================================

  /// Registers [TImpl] as [TService] with a transient lifetime.
  ServiceCollection
      addTransient<TService extends Object, TImpl extends TService>() {
    return add(ServiceDescriptor.type(
      serviceType: TService,
      implementationType: TImpl,
      lifetime: ServiceLifetime.transient,
    ));
  }

  /// Registers [TService] as transient with a synchronous [factory].
  ServiceCollection addTransientFactory<TService extends Object>(
    TService Function(ServiceProviderBase provider) factory,
  ) {
    return add(ServiceDescriptor.factoryFn(
      serviceType: TService,
      lifetime: ServiceLifetime.transient,
      factory: (p) => factory(p as ServiceProviderBase),
    ));
  }

  /// Registers [TService] as transient with an asynchronous [factory].
  ServiceCollection addTransientAsync<TService extends Object>(
    Future<TService> Function(ServiceProviderBase provider) factory,
  ) {
    return add(ServiceDescriptor.asyncFactoryFn(
      serviceType: TService,
      lifetime: ServiceLifetime.transient,
      asyncFactory: (p) async => factory(p as ServiceProviderBase),
    ));
  }

  /// Registers [TImpl] as [TService] transient only if [TService] is not yet
  /// registered (try-add semantics).
  ServiceCollection
      tryAddTransient<TService extends Object, TImpl extends TService>() {
    return tryAdd(ServiceDescriptor.type(
      serviceType: TService,
      implementationType: TImpl,
      lifetime: ServiceLifetime.transient,
    ));
  }

  // =========================================================================
  // Keyed (singleton)
  // =========================================================================

  /// Registers [TImpl] as [TService] with a singleton lifetime, bound to [key].
  ServiceCollection
      addKeyedSingleton<TService extends Object, TImpl extends TService>(
          Object key) {
    return addKeyed(KeyedServiceDescriptor.type(
      serviceType: TService,
      implementationType: TImpl,
      lifetime: ServiceLifetime.singleton,
      key: key,
    ));
  }

  /// Registers [TService] as a keyed singleton with a synchronous [factory].
  ServiceCollection addKeyedSingletonFactory<TService extends Object>(
    Object key,
    TService Function(ServiceProviderBase provider, Object key) factory,
  ) {
    return addKeyed(KeyedServiceDescriptor.factoryFn(
      serviceType: TService,
      lifetime: ServiceLifetime.singleton,
      key: key,
      keyedFactory: (p, k) => factory(p as ServiceProviderBase, k),
    ));
  }

  /// Registers [TService] as a keyed singleton with an async [factory].
  ServiceCollection addKeyedSingletonAsync<TService extends Object>(
    Object key,
    Future<TService> Function(ServiceProviderBase provider, Object key) factory,
  ) {
    return addKeyed(KeyedServiceDescriptor.asyncFactoryFn(
      serviceType: TService,
      lifetime: ServiceLifetime.singleton,
      key: key,
      keyedAsyncFactory: (p, k) async => factory(p as ServiceProviderBase, k),
    ));
  }

  // =========================================================================
  // Keyed (scoped)
  // =========================================================================

  /// Registers [TImpl] as [TService] with a scoped lifetime, bound to [key].
  ServiceCollection
      addKeyedScoped<TService extends Object, TImpl extends TService>(
          Object key) {
    return addKeyed(KeyedServiceDescriptor.type(
      serviceType: TService,
      implementationType: TImpl,
      lifetime: ServiceLifetime.scoped,
      key: key,
    ));
  }

  /// Registers [TService] as a keyed scoped with a synchronous [factory].
  ServiceCollection addKeyedScopedFactory<TService extends Object>(
    Object key,
    TService Function(ServiceProviderBase provider, Object key) factory,
  ) {
    return addKeyed(KeyedServiceDescriptor.factoryFn(
      serviceType: TService,
      lifetime: ServiceLifetime.scoped,
      key: key,
      keyedFactory: (p, k) => factory(p as ServiceProviderBase, k),
    ));
  }

  /// Registers [TService] as a keyed scoped with an async [factory].
  ServiceCollection addKeyedScopedAsync<TService extends Object>(
    Object key,
    Future<TService> Function(ServiceProviderBase provider, Object key) factory,
  ) {
    return addKeyed(KeyedServiceDescriptor.asyncFactoryFn(
      serviceType: TService,
      lifetime: ServiceLifetime.scoped,
      key: key,
      keyedAsyncFactory: (p, k) async => factory(p as ServiceProviderBase, k),
    ));
  }

  // =========================================================================
  // Keyed (transient)
  // =========================================================================

  /// Registers [TImpl] as [TService] with a transient lifetime, bound to [key].
  ServiceCollection
      addKeyedTransient<TService extends Object, TImpl extends TService>(
          Object key) {
    return addKeyed(KeyedServiceDescriptor.type(
      serviceType: TService,
      implementationType: TImpl,
      lifetime: ServiceLifetime.transient,
      key: key,
    ));
  }

  /// Registers [TService] as a keyed transient with a synchronous [factory].
  ServiceCollection addKeyedTransientFactory<TService extends Object>(
    Object key,
    TService Function(ServiceProviderBase provider, Object key) factory,
  ) {
    return addKeyed(KeyedServiceDescriptor.factoryFn(
      serviceType: TService,
      lifetime: ServiceLifetime.transient,
      key: key,
      keyedFactory: (p, k) => factory(p as ServiceProviderBase, k),
    ));
  }

  /// Registers [TService] as a keyed transient with an async [factory].
  ServiceCollection addKeyedTransientAsync<TService extends Object>(
    Object key,
    Future<TService> Function(ServiceProviderBase provider, Object key) factory,
  ) {
    return addKeyed(KeyedServiceDescriptor.asyncFactoryFn(
      serviceType: TService,
      lifetime: ServiceLifetime.transient,
      key: key,
      keyedAsyncFactory: (p, k) async => factory(p as ServiceProviderBase, k),
    ));
  }

  // =========================================================================
  // Lazy<T> — deferred resolution
  // =========================================================================

  /// Registers `Lazy<TService>` as a singleton that defers creation of
  /// [TService] until the first [Lazy.value] access.
  ///
  /// [TService] must already be registered:
  /// ```dart
  /// services
  ///   ..addSingleton<IDatabase, PostgresDatabase>()
  ///   ..addLazySingleton<IDatabase>();
  /// ```
  ServiceCollection addLazySingleton<TService extends Object>() {
    return addSingletonFactory<Lazy<TService>>(
      (p) => Lazy<TService>(() => p.getRequired<TService>()),
    );
  }

  /// Registers `Lazy<TService>` as a scoped service.
  ServiceCollection addLazyScoped<TService extends Object>() {
    return addScopedFactory<Lazy<TService>>(
      (p) => Lazy<TService>(() => p.getRequired<TService>()),
    );
  }

  /// Registers `Lazy<TService>` as a transient service.
  ///
  /// Each resolved `Lazy<TService>` is its own independent wrapper —
  /// first `.value` access on each wrapper creates a fresh [TService].
  ServiceCollection addLazyTransient<TService extends Object>() {
    return addTransientFactory<Lazy<TService>>(
      (p) => Lazy<TService>(() => p.getRequired<TService>()),
    );
  }

  // =========================================================================
  // ServiceFactory<T> — injectable factory delegate
  // =========================================================================

  /// Registers a `ServiceFactory<TService>` so that services which need to
  /// create **multiple independent instances** of [TService] can do so
  /// without taking a direct dependency on the DI container.
  ///
  /// [TService] must already be registered (typically transient):
  /// ```dart
  /// services
  ///   ..addTransient<IMessageHandler, EmailHandler>()
  ///   ..addServiceFactory<IMessageHandler>() // registers ServiceFactory<IMessageHandler>
  ///   ..addSingleton<MessageDispatcher, MessageDispatcher>();
  /// ```
  /// Each [ServiceFactory.create] call triggers transient resolution.
  ServiceCollection addServiceFactory<TService extends Object>() {
    return addSingletonFactory<ServiceFactory<TService>>(
      (p) => createDefaultServiceFactory<TService>(p),
    );
  }

  // =========================================================================
  // Conditional / environment registration
  // =========================================================================

  /// Registers [TImpl] as [TService] singleton only when [condition] returns
  /// `true` at registration time.
  ///
  /// ```dart
  /// services.addSingletonIf<ILogger, DebugLogger>(() => kDebugMode);
  /// ```
  ServiceCollection
      addSingletonIf<TService extends Object, TImpl extends TService>(
    bool Function() condition,
  ) {
    if (condition()) addSingleton<TService, TImpl>();
    return this;
  }

  /// Registers [TImpl] as [TService] scoped only when [condition] is `true`.
  ServiceCollection
      addScopedIf<TService extends Object, TImpl extends TService>(
    bool Function() condition,
  ) {
    if (condition()) addScoped<TService, TImpl>();
    return this;
  }

  /// Registers [TImpl] as [TService] transient only when [condition] is `true`.
  ServiceCollection
      addTransientIf<TService extends Object, TImpl extends TService>(
    bool Function() condition,
  ) {
    if (condition()) addTransient<TService, TImpl>();
    return this;
  }

  /// Registers a factory singleton for [TService] only when [condition] is
  /// `true`.
  ServiceCollection addSingletonFactoryIf<TService extends Object>(
    bool Function() condition,
    TService Function(ServiceProviderBase provider) factory,
  ) {
    if (condition()) addSingletonFactory<TService>(factory);
    return this;
  }

  /// Runs [configure] when [condition] is `true`, otherwise runs [otherwise]
  /// (if provided).
  ///
  /// Useful for environment-based wiring:
  /// ```dart
  /// services.addEnvironment(
  ///   condition: () => const bool.fromEnvironment('DEV'),
  ///   configure: (s) => s.addSingleton<ILogger, VerboseLogger>(),
  ///   otherwise: (s) => s.addSingleton<ILogger, StructuredLogger>(),
  /// );
  /// ```
  ServiceCollection addEnvironment({
    required bool Function() condition,
    required void Function(ServiceCollection services) configure,
    void Function(ServiceCollection services)? otherwise,
  }) {
    _assertNotBuilt();
    if (condition()) {
      configure(this);
    } else {
      otherwise?.call(this);
    }
    return this;
  }

  // =========================================================================
  // Build
  // =========================================================================

  /// Compiles all registrations into an immutable [ServiceProvider].
  ///
  /// Runs validation according to [options]. Throws [ContainerBuildException]
  /// if any errors are found when [ServiceProviderOptions.validateOnBuild] is
  /// `true`.
  ///
  /// Defaults to [ServiceProviderOptions.production] for safety. Pass
  /// [ServiceProviderOptions.development] to enable scope validation and
  /// additional diagnostics during development.
  ServiceProvider buildServiceProvider([
    ServiceProviderOptions options = ServiceProviderOptions.production,
  ]) {
    _assertNotBuilt();
    _built = true;

    final diagnostics =
        ServiceProviderDiagnostics(enabled: options.enableDiagnostics);
    final graph = DependencyGraph();
    final resolver = CallSiteResolver(
      registry: _registry,
      keyedRegistry: _keyedRegistry,
      graph: graph,
      decorators: Map.unmodifiable(_decorators),
    );

    resolver.build();

    if (options.validateOnBuild) {
      // Detect circular dependencies in the graph.
      graph.detectCycles();

      // Verify all constructor dependencies are registered (fail-fast).
      final depValidator = CallSiteValidator(resolver.callSites);
      final missingDeps = depValidator.validateDependencies();
      if (missingDeps.isNotEmpty) {
        throw ContainerBuildException(missingDeps);
      }
    }

    // Convert keyed call site keys to record format.
    final keyedMap = <(Type, Object), CallSite>{};
    for (final entry in resolver.keyedCallSites.entries) {
      keyedMap[entry.key] = entry.value;
    }

    final root = RootServiceProvider(
      callSites: resolver.callSites,
      allCallSites: resolver.allCallSites,
      keyedCallSites: keyedMap,
      options: options,
      diagnostics: diagnostics,
    );

    if (options.validateScopes) {
      final validator = CallSiteValidator(resolver.callSites);
      final errors = validator.validate();
      if (errors.isNotEmpty) {
        throw ContainerBuildException(errors);
      }
    }

    final provider = ServiceProvider(root);

    // Run synchronous on-build hooks.
    for (final hook in _buildHooks) {
      hook(provider);
    }

    return provider;
  }

  /// Builds the container and runs all registered async on-build hooks.
  ///
  /// Use this when hooks registered via [onContainerBuiltAsync] need to run
  /// (e.g. database migrations, cache warm-up).
  Future<ServiceProvider> buildServiceProviderAsync([
    ServiceProviderOptions options = ServiceProviderOptions.production,
  ]) async {
    final provider = buildServiceProvider(options);
    for (final hook in _asyncBuildHooks) {
      await hook(provider);
    }
    return provider;
  }

  // =========================================================================
  // Introspection
  // =========================================================================

  /// Returns `true` if [TService] has at least one registration.
  bool isRegistered<TService extends Object>() => _registry.contains(TService);

  /// Returns all descriptors registered for [TService].
  List<ServiceDescriptor> descriptorsFor<TService extends Object>() =>
      _registry.getAll(TService);

  /// Total number of distinct service types registered.
  int get count => _registry.length;

  // =========================================================================
  // Modules
  // =========================================================================

  /// Applies a [ServiceModule] to this collection.
  ///
  /// Modules encapsulate a cohesive group of registrations, keeping
  /// large apps organised:
  /// ```dart
  /// services
  ///   ..addModule(DatabaseModule())
  ///   ..addModule(AuthModule());
  /// ```
  ServiceCollection addModule(ServiceModule module) {
    _assertNotBuilt();
    module.register(this);
    return this;
  }

  // =========================================================================
  // Decorators
  // =========================================================================

  /// Wraps every existing (and future) registration of [TService] with a
  /// decorator created by [decoratorFactory].
  ///
  /// The factory receives the resolved inner instance and the current
  /// [ServiceProviderBase] so it can inject extra dependencies:
  /// ```dart
  /// services.decorate<ILogger>(
  ///   (inner, p) => TimingLogger(inner, p.getRequired<IClock>()),
  /// );
  /// ```
  /// Multiple decorators are applied in registration order (outermost last).
  ServiceCollection decorate<TService extends Object>(
    TService Function(TService inner, ServiceProviderBase provider)
        decoratorFactory,
  ) {
    _assertNotBuilt();
    (_decorators[TService] ??= []).add(
      (inner, p) => decoratorFactory(inner as TService, p),
    );
    return this;
  }

  // =========================================================================
  // Post-build hooks (PostConfigure equivalent)
  // =========================================================================

  /// Registers a synchronous hook that runs immediately after
  /// [buildServiceProvider] finishes.
  ///
  /// Use to trigger eager initialization, warm caches, or log startup info:
  /// ```dart
  /// services.onContainerBuilt((p) {
  ///   p.getRequired<IStartupValidator>().validate();
  /// });
  /// ```
  ServiceCollection onContainerBuilt(void Function(ServiceProvider p) hook) {
    _assertNotBuilt();
    _buildHooks.add(hook);
    return this;
  }

  /// Registers an asynchronous hook that runs after
  /// [buildServiceProviderAsync] finishes all sync hooks.
  ///
  /// ```dart
  /// services.onContainerBuiltAsync((p) async {
  ///   await p.getRequired<IDatabase>().migrateAsync();
  /// });
  /// ```
  ServiceCollection onContainerBuiltAsync(
      Future<void> Function(ServiceProvider p) hook) {
    _assertNotBuilt();
    _asyncBuildHooks.add(hook);
    return this;
  }

  // =========================================================================
  // Internal
  // =========================================================================

  void _assertNotBuilt() {
    if (_built) {
      throw StateError(
        'ServiceCollection has already been built into a ServiceProvider. '
        'Create a new ServiceCollection to register additional services.',
      );
    }
  }
}
