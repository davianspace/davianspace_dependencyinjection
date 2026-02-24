/// Options controlling the behaviour of [ServiceProvider] at build time and
/// during resolution.
final class ServiceProviderOptions {
  /// When `true`, the container validates the entire call site graph during
  /// `buildServiceProvider()` and throws on any errors.
  ///
  /// Equivalent to `ValidateOnBuild` in .NET.
  final bool validateOnBuild;

  /// When `true`, the container detects and throws [ScopeViolationException]
  /// when a scoped service is captured by a singleton.
  ///
  /// Equivalent to `ValidateScopes` in .NET.
  final bool validateScopes;

  /// When `true`, the container emits [DiagnosticEvent]s to
  /// [ServiceProviderDiagnostics].
  final bool enableDiagnostics;

  const ServiceProviderOptions({
    this.validateOnBuild = true,
    this.validateScopes = true,
    this.enableDiagnostics = false,
  });

  /// Recommended options for production environments.
  static const ServiceProviderOptions production = ServiceProviderOptions(
    validateOnBuild: true,
    validateScopes: false,
    enableDiagnostics: false,
  );

  /// Recommended options for development / testing.
  static const ServiceProviderOptions development = ServiceProviderOptions(
    validateOnBuild: true,
    validateScopes: true,
    enableDiagnostics: true,
  );
}
