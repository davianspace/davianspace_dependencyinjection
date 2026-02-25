/// Thrown when one or more services fail to dispose cleanly.
final class DisposalException implements Exception {
  /// Every service-type/cause pair collected during disposal.
  ///
  /// The list is in reverse creation order (i.e. the first element is the
  /// innermost consumer that was disposed first).
  final List<(Type serviceType, Object cause)> errors;

  /// The service type of the first failing disposal.
  Type get serviceType => errors.first.$1;

  /// The cause of the first failing disposal.
  Object get cause => errors.first.$2;

  /// Creates a [DisposalException] from one or more disposal [errors].
  const DisposalException(this.errors)
      : assert(errors.length > 0, 'errors must not be empty');

  @override
  String toString() {
    if (errors.length == 1) {
      return 'DisposalException: Service "${errors.first.$1}" threw during '
          'disposal. Cause: ${errors.first.$2}';
    }
    final buffer = StringBuffer(
        'DisposalException: ${errors.length} service(s) threw during disposal:\n');
    for (var i = 0; i < errors.length; i++) {
      buffer.writeln('  ${i + 1}. ${errors[i].$1}: ${errors[i].$2}');
    }
    return buffer.toString().trimRight();
  }
}
