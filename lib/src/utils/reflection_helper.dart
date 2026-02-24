/// Dart does not expose runtime reflection (mirrors) in AOT/non-development
/// modes.  Constructor injection therefore requires each implementation type
/// to register its own **factory function** — a zero-overhead closure that
/// receives a [ServiceProviderBase]-compatible resolver and creates the
/// instance.
///
/// [ReflectionHelper] is the global registry for these closures.
/// Registrations are typically wired by calling [register] before building
/// the [ServiceCollection] into a [ServiceProvider].
final class ReflectionHelper {
  ReflectionHelper._();

  static final ReflectionHelper instance = ReflectionHelper._();

  // Map from implementation Type → factory(resolverFn) → instance
  final _factories = <Type, Object Function(Object Function(Type) resolve)>{};

  /// Registers [factory] as the constructor-injection factory for [type].
  ///
  /// [factory] receives a `resolve` callback it can call for each parameter:
  /// ```dart
  /// ReflectionHelper.instance.register<MyService>(
  ///   MyService,
  ///   (resolve) => MyService(resolve(ILogger) as ILogger),
  /// );
  /// ```
  void register(
    Type type,
    Object Function(Object Function(Type) resolve) factory,
  ) {
    _factories[type] = factory;
  }

  /// Returns the registered factory for [type], or `null` if none.
  Object Function(Object Function(Type) resolve)? factoryFor(Type type) {
    return _factories[type];
  }

  /// Returns `true` if a factory has been registered for [type].
  bool hasFactory(Type type) => _factories.containsKey(type);

  /// Removes the factory for [type] (useful in tests).
  void unregister(Type type) => _factories.remove(type);

  /// Clears all registered factories.
  void clear() => _factories.clear();
}
