/// Severity level of a [DiagnosticEvent].
enum DiagnosticSeverity { trace, info, warning, error }

/// An event emitted by the DI container during build or resolve phases.
///
/// Consumers can subscribe to the [ServiceProviderDiagnostics.events] stream
/// to observe container behaviour without modifying resolution logic.
final class DiagnosticEvent {
  /// When the event occurred.
  final DateTime timestamp;

  /// Human-readable description of the event.
  final String message;

  /// The severity of the event.
  final DiagnosticSeverity severity;

  /// Optional: the service type this event is about.
  final Type? serviceType;

  /// Optional: structured context data.
  final Map<String, Object?> context;

  /// Creates a [DiagnosticEvent] with the given [timestamp], [message],
  /// [severity], and optional [serviceType] and [context].
  const DiagnosticEvent({
    required this.timestamp,
    required this.message,
    required this.severity,
    this.serviceType,
    this.context = const {},
  });

  /// Creates a trace-level [DiagnosticEvent] with [DateTime.now] as timestamp.
  factory DiagnosticEvent.trace(
    String message, {
    Type? serviceType,
    Map<String, Object?> context = const {},
  }) =>
      DiagnosticEvent(
        timestamp: DateTime.now(),
        message: message,
        severity: DiagnosticSeverity.trace,
        serviceType: serviceType,
        context: context,
      );

  /// Creates an info-level [DiagnosticEvent] with [DateTime.now] as timestamp.
  factory DiagnosticEvent.info(
    String message, {
    Type? serviceType,
    Map<String, Object?> context = const {},
  }) =>
      DiagnosticEvent(
        timestamp: DateTime.now(),
        message: message,
        severity: DiagnosticSeverity.info,
        serviceType: serviceType,
        context: context,
      );

  /// Creates a warning-level [DiagnosticEvent] with [DateTime.now] as timestamp.
  factory DiagnosticEvent.warning(
    String message, {
    Type? serviceType,
    Map<String, Object?> context = const {},
  }) =>
      DiagnosticEvent(
        timestamp: DateTime.now(),
        message: message,
        severity: DiagnosticSeverity.warning,
        serviceType: serviceType,
        context: context,
      );

  /// Creates an error-level [DiagnosticEvent] with [DateTime.now] as timestamp.
  factory DiagnosticEvent.error(
    String message, {
    Type? serviceType,
    Map<String, Object?> context = const {},
  }) =>
      DiagnosticEvent(
        timestamp: DateTime.now(),
        message: message,
        severity: DiagnosticSeverity.error,
        serviceType: serviceType,
        context: context,
      );

  @override
  String toString() =>
      '[${severity.name.toUpperCase()}] ${timestamp.toIso8601String()} '
      '${serviceType != null ? "($serviceType) " : ""}$message';
}
