import 'package:davianspace_dependencyinjection/src/abstractions/service_provider_interface.dart';

/// A factory that creates a new instance of [T] on each [create] call.
///
/// Analogous to `IServiceScopeFactory` or factory-delegate injection in .NET.
/// Use when a service needs to create **multiple independent instances** of
/// another service without taking a hard dependency on the full container:
///
/// ```dart
/// class MessageDispatcher {
///   final ServiceFactory<IMessageHandler> _handlerFactory;
///   MessageDispatcher(this._handlerFactory);
///
///   void dispatch(Message msg) {
///     final handler = _handlerFactory.create();
///     handler.handle(msg);
///   }
/// }
/// ```
///
/// ## Registration
///
/// ```dart
/// services
///   ..addTransient<IMessageHandler, EmailMessageHandler>()
///   ..addServiceFactory<IMessageHandler>()  // auto-registers ServiceFactory<IMessageHandler>
///   ..addSingleton<MessageDispatcher, MessageDispatcher>();
/// ```
abstract class ServiceFactory<T extends Object> {
  /// Creates and returns a new instance of [T].
  T create();
}

/// Default implementation backed by a [ServiceProviderBase].
final class _DefaultServiceFactory<T extends Object>
    implements ServiceFactory<T> {
  final ServiceProviderBase _provider;

  _DefaultServiceFactory(this._provider);

  @override
  T create() => _provider.getRequired<T>();
}

/// Creates a [ServiceFactory<T>] that resolves from [provider].
ServiceFactory<T> createDefaultServiceFactory<T extends Object>(
  ServiceProviderBase provider,
) =>
    _DefaultServiceFactory<T>(provider);
