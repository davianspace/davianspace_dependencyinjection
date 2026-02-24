/// Thrown when the container fails to build due to one or more registration
/// or configuration errors.
final class ContainerBuildException implements Exception {
  /// All errors collected during the build phase.
  final List<String> errors;

  /// Creates a [ContainerBuildException] with the list of build [errors].
  const ContainerBuildException(this.errors);

  @override
  String toString() {
    final buffer = StringBuffer()
      ..writeln('ContainerBuildException: Container failed to build with '
          '${errors.length} error(s):');
    for (var i = 0; i < errors.length; i++) {
      buffer.writeln('  ${i + 1}. ${errors[i]}');
    }
    return buffer.toString().trimRight();
  }
}
