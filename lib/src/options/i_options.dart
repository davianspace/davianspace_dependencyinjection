/// Accesses a singleton snapshot of [T] options.
///
/// This is the standard way to inject configuration that does not change
/// after the container is built:
///
/// ```dart
/// class DatabaseService {
///   final IOptions<DatabaseOptions> _opts;
///   DatabaseService(this._opts);
///
///   String get connectionString => _opts.value.connectionString;
/// }
/// ```
///
/// Analogous to `IOptions<T>` in Microsoft.Extensions.Options.
abstract class IOptions<T extends Object> {
  /// The current configured value of [T].
  T get value;
}

/// Accesses a **scoped** snapshot of [T] options, recomputed per scope.
///
/// Useful for multi-tenant scenarios where config differs between scopes.
///
/// Analogous to `IOptionsSnapshot<T>` in Microsoft.Extensions.Options.
abstract class IOptionsSnapshot<T extends Object> {
  /// The options value for the current scope.
  T get value;

  /// Returns the named options value for [name].
  T get(String name);
}

/// Provides access to options and **change notifications** when options are
/// updated at runtime.
///
/// Analogous to `IOptionsMonitor<T>` in Microsoft.Extensions.Options.
abstract class IOptionsMonitor<T extends Object> {
  /// The current options value (default configuration).
  T get currentValue;

  /// Returns the named options value for [name].
  T get(String name);

  /// Registers a [listener] that is called whenever the options change.
  ///
  /// Returns a [OptionsChangeDisposable] — call [OptionsChangeDisposable.dispose]
  /// to deregister the listener.
  OptionsChangeDisposable onChange(
      void Function(T options, String name) listener);
}

/// A handle returned by [IOptionsMonitor.onChange] that can be disposed to
/// stop receiving change notifications.
abstract class OptionsChangeDisposable {
  /// Stops the change notification listener.
  void dispose();
}
