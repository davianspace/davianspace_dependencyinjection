import 'package:davianspace_dependencyinjection/src/options/i_options.dart';

// ---------------------------------------------------------------------------
// OptionsRegistration — stores configure/postConfigure callbacks per name
// ---------------------------------------------------------------------------

/// Internal accumulator for a single named options set.
final class OptionsRegistration<T extends Object> {
  final List<void Function(T options)> _configure = [];
  final List<void Function(T options)> _postConfigure = [];

  void addConfigure(void Function(T options) fn) => _configure.add(fn);
  void addPostConfigure(void Function(T options) fn) => _postConfigure.add(fn);

  T build(T Function() factory) {
    final opts = factory();
    for (final fn in _configure) {
      fn(opts);
    }
    for (final fn in _postConfigure) {
      fn(opts);
    }
    return opts;
  }
}

// ---------------------------------------------------------------------------
// OptionsFactory — creates and caches options values
// ---------------------------------------------------------------------------

/// Container for all registered [OptionsRegistration]s of type [T].
final class OptionsFactory<T extends Object> {
  final T Function() _defaultFactory;
  final _named = <String, OptionsRegistration<T>>{};

  static const String _defaultName = '';

  OptionsFactory(this._defaultFactory);

  OptionsRegistration<T> _registrationFor(String name) =>
      _named.putIfAbsent(name, OptionsRegistration<T>.new);

  /// Adds a configure callback for [name] (default `''`).
  void addConfigure(void Function(T opts) fn, [String name = _defaultName]) =>
      _registrationFor(name).addConfigure(fn);

  /// Adds a post-configure callback for [name].
  void addPostConfigure(void Function(T opts) fn,
          [String name = _defaultName]) =>
      _registrationFor(name).addPostConfigure(fn);

  T create([String name = _defaultName]) {
    final reg = _named[name];
    if (reg == null) return _defaultFactory();
    return reg.build(_defaultFactory);
  }
}

// ---------------------------------------------------------------------------
// OptionsManager — IOptions singleton impl
// ---------------------------------------------------------------------------

/// Singleton implementation of [IOptions<T>] — the value is built once.
final class OptionsManager<T extends Object> implements IOptions<T> {
  final OptionsFactory<T> _factory;
  late final T _value = _factory.create();

  OptionsManager(this._factory);

  @override
  T get value => _value;
}

// ---------------------------------------------------------------------------
// OptionsSnapshot — IOptionsSnapshot scoped impl
// ---------------------------------------------------------------------------

/// Scoped implementation of [IOptionsSnapshot<T>] — rebuilt per scope.
final class OptionsSnapshot<T extends Object> implements IOptionsSnapshot<T> {
  final OptionsFactory<T> _factory;
  final _cache = <String, T>{};

  OptionsSnapshot(this._factory);

  @override
  T get value => get('');

  @override
  T get(String name) => _cache.putIfAbsent(name, () => _factory.create(name));
}

// ---------------------------------------------------------------------------
// OptionsMonitor — IOptionsMonitor impl with change notification
// ---------------------------------------------------------------------------

/// Singleton implementation of [IOptionsMonitor<T>] with change streams.
final class OptionsMonitor<T extends Object> implements IOptionsMonitor<T> {
  final OptionsFactory<T> _factory;
  T _currentValue;
  final _listeners = <void Function(T, String)>[];

  OptionsMonitor(this._factory) : _currentValue = _factory.create();

  @override
  T get currentValue => _currentValue;

  @override
  T get(String name) => _factory.create(name);

  @override
  OptionsChangeDisposable onChange(
      void Function(T options, String name) listener) {
    _listeners.add(listener);
    return _OptionsListenerHandle(() => _listeners.remove(listener));
  }

  /// Triggers all registered listeners with [newValue].
  ///
  /// Call this whenever options are reloaded (e.g. on config file change):
  /// ```dart
  /// monitor.reload(updatedOpts, '');
  /// ```
  void reload(T newValue, [String name = '']) {
    _currentValue = newValue;
    for (final l in List.of(_listeners)) {
      l(newValue, name);
    }
  }
}

final class _OptionsListenerHandle implements OptionsChangeDisposable {
  final void Function() _remove;
  _OptionsListenerHandle(this._remove);

  @override
  void dispose() => _remove();
}
