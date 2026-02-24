/// Thrown when the container cannot find a registration for a requested type.
final class MissingServiceException implements Exception {
  /// The service type that was requested.
  final Type serviceType;

  /// Optional: the key used in a keyed-service lookup.
  final Object? key;

  const MissingServiceException(this.serviceType, {this.key});

  @override
  String toString() {
    if (key != null) {
      return 'MissingServiceException: No service registered for type '
          '"$serviceType" with key "$key".';
    }
    return 'MissingServiceException: No service registered for type '
        '"$serviceType".';
  }
}
