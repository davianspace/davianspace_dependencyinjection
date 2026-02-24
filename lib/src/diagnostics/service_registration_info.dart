/// Describes a single service registration in the built container.
///
/// Returned by [ServiceProvider.getServiceDescriptions] for diagnostic and
/// tooling purposes.
final class ServiceRegistrationInfo {
  /// The registered service type (interface or concrete type).
  final Type serviceType;

  /// Lowercase name of the lifetime: `'singleton'`, `'scoped'`, or `'transient'`.
  final String lifetimeName;

  /// Lowercase name of the resolution strategy: `'constructor'`, `'factory'`,
  /// `'instance'`, `'asyncFactory'`, `'decorator'`, `'lazy'`, etc.
  final String strategyName;

  /// Creates a [ServiceRegistrationInfo].
  const ServiceRegistrationInfo({
    required this.serviceType,
    required this.lifetimeName,
    required this.strategyName,
  });

  @override
  String toString() => '$serviceType [$lifetimeName] via $strategyName';
}
