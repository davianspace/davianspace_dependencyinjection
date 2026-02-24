import 'dart:async';

import 'package:davianspace_dependencyinjection/src/diagnostics/diagnostic_event.dart';

/// Provides observable diagnostics for the DI container.
///
/// Attach a listener via [events] to observe build-time validation,
/// cache hits/misses, scope creation, and disposal events.
final class ServiceProviderDiagnostics {
  final _controller = StreamController<DiagnosticEvent>.broadcast();

  /// Whether diagnostics collection is enabled.
  bool enabled;

  ServiceProviderDiagnostics({this.enabled = false});

  /// A broadcast stream of [DiagnosticEvent]s emitted by the container.
  Stream<DiagnosticEvent> get events => _controller.stream;

  /// Emits a [DiagnosticEvent] if diagnostics are [enabled].
  void emit(DiagnosticEvent event) {
    if (enabled && !_controller.isClosed) {
      _controller.add(event);
    }
  }

  /// Convenience: emits a trace-level event.
  void trace(String message,
      {Type? serviceType, Map<String, Object?> context = const {}}) {
    emit(DiagnosticEvent.trace(message,
        serviceType: serviceType, context: context));
  }

  /// Convenience: emits an info-level event.
  void info(String message,
      {Type? serviceType, Map<String, Object?> context = const {}}) {
    emit(DiagnosticEvent.info(message,
        serviceType: serviceType, context: context));
  }

  /// Convenience: emits a warning-level event.
  void warning(String message,
      {Type? serviceType, Map<String, Object?> context = const {}}) {
    emit(DiagnosticEvent.warning(message,
        serviceType: serviceType, context: context));
  }

  /// Convenience: emits an error-level event.
  void error(String message,
      {Type? serviceType, Map<String, Object?> context = const {}}) {
    emit(DiagnosticEvent.error(message,
        serviceType: serviceType, context: context));
  }

  /// Closes the underlying stream controller.
  Future<void> close() => _controller.close();
}
