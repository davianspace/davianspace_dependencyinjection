/// The lifetime of a service registration.
///
/// Mirrors [Microsoft.Extensions.DependencyInjection.ServiceLifetime].
enum ServiceLifetime {
  /// A single instance is created and shared for the entire application lifetime.
  singleton,

  /// One instance is created per scope (e.g. per HTTP request).
  scoped,

  /// A new instance is created every time the service is requested.
  transient,
}
