/// Thrown when a scoped service is captured by a singleton.
///
/// This would create a hidden memory leak where the scoped service lives for
/// the entire application lifetime — the same bug that .NET's scope validation
/// prevents with `validateScopes: true`.
final class ScopeViolationException implements Exception {
  /// The singleton service that is trying to capture a scoped dependency.
  final Type singletonType;

  /// The scoped service being (incorrectly) injected.
  final Type scopedType;

  const ScopeViolationException({
    required this.singletonType,
    required this.scopedType,
  });

  @override
  String toString() =>
      'ScopeViolationException: Cannot consume scoped service "$scopedType" '
      'from singleton "$singletonType". '
      'This would extend the scoped service\'s lifetime to the application '
      'lifetime, causing a captive dependency bug.';
}
