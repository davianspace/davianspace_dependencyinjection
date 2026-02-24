import 'package:davianspace_dependencyinjection/src/descriptors/service_lifetime.dart';

/// Describes a single service registration in the DI container.
///
/// Analogous to `ServiceDescriptor` in Microsoft.Extensions.DependencyInjection.
/// A descriptor is immutable once created.
///
/// Exactly one of [implementationType], [factory], [asyncFactory], or
/// [instance] must be non-null.
class ServiceDescriptor {
  /// The service type (abstract class / interface / concrete class).
  final Type serviceType;

  /// The concrete implementation type to instantiate, when constructor
  /// injection is used.
  final Type? implementationType;

  /// A synchronous factory that produces the service instance.
  final Object Function(Object provider)? factory;

  /// An asynchronous factory that produces the service instance.
  final Future<Object> Function(Object provider)? asyncFactory;

  /// A pre-built instance (only valid for [ServiceLifetime.singleton]).
  final Object? instance;

  /// The lifetime of the service.
  final ServiceLifetime lifetime;

  ServiceDescriptor.create({
    required this.serviceType,
    required this.lifetime,
    this.implementationType,
    this.factory,
    this.asyncFactory,
    this.instance,
  });

  // -------------------------------------------------------------------------
  // Named constructors
  // -------------------------------------------------------------------------

  /// Registers [serviceType] resolved by constructor injection of
  /// [implementationType] with lifetime [lifetime].
  factory ServiceDescriptor.type({
    required Type serviceType,
    required Type implementationType,
    required ServiceLifetime lifetime,
  }) {
    return ServiceDescriptor.create(
      serviceType: serviceType,
      implementationType: implementationType,
      lifetime: lifetime,
    );
  }

  /// Registers [serviceType] resolved by a synchronous [factory].
  factory ServiceDescriptor.factoryFn({
    required Type serviceType,
    required ServiceLifetime lifetime,
    required Object Function(Object provider) factory,
  }) {
    return ServiceDescriptor.create(
      serviceType: serviceType,
      lifetime: lifetime,
      factory: factory,
    );
  }

  /// Registers [serviceType] resolved by an asynchronous [asyncFactory].
  factory ServiceDescriptor.asyncFactoryFn({
    required Type serviceType,
    required ServiceLifetime lifetime,
    required Future<Object> Function(Object provider) asyncFactory,
  }) {
    return ServiceDescriptor.create(
      serviceType: serviceType,
      lifetime: lifetime,
      asyncFactory: asyncFactory,
    );
  }

  /// Registers [serviceType] as the pre-built [instance] (always singleton).
  factory ServiceDescriptor.instanceValue({
    required Type serviceType,
    required Object instance,
  }) {
    return ServiceDescriptor.create(
      serviceType: serviceType,
      lifetime: ServiceLifetime.singleton,
      instance: instance,
    );
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  bool get isTypeRegistration => implementationType != null;
  bool get isFactoryRegistration => factory != null;
  bool get isAsyncFactoryRegistration => asyncFactory != null;
  bool get isInstanceRegistration => instance != null;

  @override
  String toString() {
    final kind = isTypeRegistration
        ? 'type:$implementationType'
        : isFactoryRegistration
            ? 'factory'
            : isAsyncFactoryRegistration
                ? 'asyncFactory'
                : 'instance:${instance.runtimeType}';
    return 'ServiceDescriptor($serviceType → $kind [${lifetime.name}])';
  }
}
