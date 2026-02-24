import 'package:davianspace_dependencyinjection/src/descriptors/service_descriptor.dart';
import 'package:davianspace_dependencyinjection/src/descriptors/service_lifetime.dart';

/// A [ServiceDescriptor] that also carries a [key] for keyed-service lookup.
///
/// Analogous to the keyed service extensions introduced in .NET 8.
final class KeyedServiceDescriptor extends ServiceDescriptor {
  /// The key that disambiguates this registration from other registrations
  /// of the same [serviceType].
  final Object key;

  // ignore: prefer_const_constructors_in_immutables
  KeyedServiceDescriptor._({
    required super.serviceType,
    required super.lifetime,
    required this.key,
    super.implementationType,
    super.factory,
    super.asyncFactory,
    super.instance,
  }) : super.create();

  factory KeyedServiceDescriptor.type({
    required Type serviceType,
    required Type implementationType,
    required ServiceLifetime lifetime,
    required Object key,
  }) {
    return KeyedServiceDescriptor._(
      serviceType: serviceType,
      implementationType: implementationType,
      lifetime: lifetime,
      key: key,
    );
  }

  factory KeyedServiceDescriptor.factoryFn({
    required Type serviceType,
    required ServiceLifetime lifetime,
    required Object key,
    required Object Function(Object provider, Object key) keyedFactory,
  }) {
    return KeyedServiceDescriptor._(
      serviceType: serviceType,
      lifetime: lifetime,
      key: key,
      factory: (p) => keyedFactory(p, key),
    );
  }

  factory KeyedServiceDescriptor.asyncFactoryFn({
    required Type serviceType,
    required ServiceLifetime lifetime,
    required Object key,
    required Future<Object> Function(Object provider, Object key)
        keyedAsyncFactory,
  }) {
    return KeyedServiceDescriptor._(
      serviceType: serviceType,
      lifetime: lifetime,
      key: key,
      asyncFactory: (p) => keyedAsyncFactory(p, key),
    );
  }

  factory KeyedServiceDescriptor.instanceValue({
    required Type serviceType,
    required Object instance,
    required Object key,
  }) {
    return KeyedServiceDescriptor._(
      serviceType: serviceType,
      lifetime: ServiceLifetime.singleton,
      key: key,
      instance: instance,
    );
  }

  @override
  String toString() {
    return 'KeyedServiceDescriptor($serviceType[key=$key] [${lifetime.name}])';
  }
}
