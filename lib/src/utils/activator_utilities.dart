import 'package:davianspace_dependencyinjection/src/abstractions/service_provider_interface.dart';

/// A secondary factory signature used by [ActivatorUtilities].
///
/// Unlike the standard [ReflectionHelper] factories (which only call
/// `resolve(Type)`), an activator factory also receives runtime
/// [positionalArgs] supplied by the caller at creation time.
typedef ActivatorFactory<T extends Object> = T Function(
  Object Function(Type dep) resolve,
  List<Object> positionalArgs,
);

/// Global registry for [ActivatorFactory] entries.
///
/// Register each class that needs mixed DI + runtime arguments **before**
/// building the [ServiceCollection]:
///
/// ```dart
/// ActivatorHelper.instance.register<OrderBloc>(
///   OrderBloc,
///   (resolve, args) => OrderBloc(
///     resolve(IOrderRepository) as IOrderRepository,
///     resolve(ILogger) as ILogger,
///     args[0] as String, // orderId supplied at runtime
///   ),
/// );
/// ```
final class ActivatorHelper {
  ActivatorHelper._();

  static final ActivatorHelper instance = ActivatorHelper._();

  final _factories = <Type, ActivatorFactory<Object>>{};

  /// Registers [factory] as the activator factory for [type].
  void register<T extends Object>(
    Type type,
    ActivatorFactory<T> factory,
  ) {
    _factories[type] = (resolve, args) => factory(resolve, args);
  }

  /// Returns the factory for [type], or `null`.
  ActivatorFactory<Object>? factoryFor(Type type) => _factories[type];

  /// Returns `true` if a factory is registered for [type].
  bool hasFactory(Type type) => _factories.containsKey(type);

  /// Removes a factory (useful in tests).
  void unregister(Type type) => _factories.remove(type);

  /// Clears all registered factories.
  void clear() => _factories.clear();
}

/// Creates instances that receive a mix of DI-resolved and runtime arguments.
///
/// Analogous to `ActivatorUtilities` in Microsoft.Extensions.DependencyInjection.
///
/// **Typical Flutter use case:** Creating a BLoC/ViewModel that needs both a
/// DI-resolved repository **and** a route parameter (e.g., an entity ID).
///
/// ## Setup (once, e.g. in `main.dart`)
///
/// ```dart
/// ActivatorHelper.instance.register<OrderBloc>(
///   OrderBloc,
///   (resolve, args) => OrderBloc(
///     resolve(IOrderRepository) as IOrderRepository,
///     args[0] as String, // orderId from route
///   ),
/// );
/// ```
///
/// ## Usage (inside a screen/widget)
///
/// ```dart
/// final bloc = ActivatorUtilities.createInstance<OrderBloc>(
///   provider,
///   positionalArgs: [orderId],
/// );
/// ```
abstract final class ActivatorUtilities {
  ActivatorUtilities._();

  /// Creates an instance of [T], resolving DI deps from [provider] and
  /// supplying [positionalArgs] as the extra runtime arguments.
  ///
  /// Throws [StateError] if no [ActivatorHelper] factory is registered for [T].
  static T createInstance<T extends Object>(
    ServiceProviderBase provider, {
    List<Object> positionalArgs = const [],
  }) {
    final factory = ActivatorHelper.instance.factoryFor(T);
    if (factory == null) {
      throw StateError(
        'No ActivatorUtilities factory registered for $T. '
        'Call ActivatorHelper.instance.register<$T>(...) before building '
        'the container.',
      );
    }

    return factory(
      (Type dep) => provider.resolveRequired(dep),
      positionalArgs,
    ) as T;
  }
}
