/// A wrapper that defers the creation of [T] until the first access.
///
/// Analogous to `Lazy<T>` in .NET — the inner service is not created until
/// [value] is first read, reducing startup cost for expensive services.
///
/// ## Registration
///
/// Use `ServiceCollection.addLazySingleton<T>()` (or the scoped / transient
/// variants) instead of registering a `Lazy<T>` manually:
///
/// ```dart
/// services
///   ..addSingleton<IDatabase, PostgresDatabase>()
///   ..addLazySingleton<IDatabase>();   // wraps the singleton above
/// ```
///
/// ## Injection
///
/// ```dart
/// class ReportService {
///   final Lazy<IDatabase> _lazyDb;
///   ReportService(this._lazyDb);
///
///   void generateReport() {
///     // DB not created until this line:
///     final db = _lazyDb.value;
///     // ...
///   }
/// }
///
/// ReflectionHelper.instance.register<ReportService>(
///   ReportService,
///   (resolve) => ReportService(resolve(Lazy<IDatabase>) as Lazy<IDatabase>),
/// );
/// ```
final class Lazy<T extends Object> {
  final T Function() _factory;
  T? _value;
  bool _initialized = false;

  /// Creates a [Lazy] that calls [factory] once on first [value] access.
  Lazy(this._factory);

  /// Resolves (and caches) the wrapped value.
  ///
  /// On first call the [factory] runs; subsequent calls return the cached
  /// result without invoking the factory again.
  T get value {
    if (!_initialized) {
      _value = _factory();
      _initialized = true;
    }
    return _value!;
  }

  /// Returns `true` once [value] has been accessed at least once.
  bool get isValueCreated => _initialized;

  @override
  String toString() => 'Lazy<$T>(${_initialized ? 'created' : 'not created'})';
}
