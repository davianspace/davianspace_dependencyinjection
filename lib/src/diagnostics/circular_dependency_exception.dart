/// Thrown when a circular dependency is detected during the build phase.
///
/// The [chain] lists the exact resolution path that forms the cycle.
final class CircularDependencyException implements Exception {
  /// The ordered list of types in the cycle, with the offending type repeated
  /// at both the start and end: `[A, B, C, A]`.
  final List<Type> chain;

  /// A human-readable description of the cycle.
  final String message;

  /// Creates a [CircularDependencyException] with the dependency [chain] and
  /// a human-readable [message].
  const CircularDependencyException({
    required this.chain,
    required this.message,
  });

  @override
  String toString() => 'CircularDependencyException: $message\n'
      'Chain: ${chain.map((t) => t.toString()).join(' → ')}';
}
