/// Thrown when one or more services fail to dispose cleanly.
final class DisposalException implements Exception {
  /// The type of the service that failed to dispose.
  final Type serviceType;

  /// The underlying cause.
  final Object cause;

  const DisposalException({
    required this.serviceType,
    required this.cause,
  });

  @override
  String toString() =>
      'DisposalException: Service "$serviceType" threw during disposal. '
      'Cause: $cause';
}
