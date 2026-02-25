import 'package:davianspace_dependencyinjection/src/abstractions/service_provider_interface.dart';
import 'package:davianspace_dependencyinjection/src/abstractions/service_scope_interface.dart';

/// Manages named [ServiceScopeBase] lifetimes outside the widget tree.
///
/// Use [ScopeManager] when a logical scope needs to span multiple operations
/// (e.g. a single HTTP request, a checkout flow, a user session) and you want
/// explicit control over when the scope starts and ends.
///
/// For Flutter applications, pair this with a `StatefulWidget` to mirror
/// the scope lifetime to the widget lifecycle — full widget tree integration
/// will be available in the upcoming `davianspace_dependencyinjection_flutter`
/// package.
///
/// ## Example
///
/// ```dart
/// final scopeManager = ScopeManager(provider);
///
/// // Start a named scope when a flow begins
/// scopeManager.beginScope('checkout');
///
/// // Resolve scoped services within that flow
/// final cart = scopeManager.getRequired<ICartService>('checkout');
///
/// // End the scope (disposes all scoped services)
/// await scopeManager.endScopeAsync('checkout');
/// ```
final class ScopeManager {
  final ServiceProviderBase _root;
  final _scopes = <String, ServiceScopeBase>{};

  ScopeManager(this._root);

  // -------------------------------------------------------------------------
  // Scope lifecycle
  // -------------------------------------------------------------------------

  /// Creates and stores a new scope under [name].
  ///
  /// Throws [StateError] if a scope with [name] already exists.
  /// Use [hasScope] to check first if re-entry is possible.
  void beginScope(String name) {
    if (_scopes.containsKey(name)) {
      throw StateError(
        'A scope named "$name" already exists. '
        'Call endScope("$name") before beginning a new one.',
      );
    }
    _scopes[name] = _root.createScope();
  }

  /// Begins a scope with [name] if none exists; no-op if it already does.
  void beginScopeIfAbsent(String name) {
    _scopes.putIfAbsent(name, () => _root.createScope());
  }

  /// Returns `true` if a scope named [name] is currently active.
  bool hasScope(String name) => _scopes.containsKey(name);

  /// Returns the active [ServiceScopeBase] for [name].
  ///
  /// Throws [StateError] if not found — call [beginScope] first.
  ServiceScopeBase scope(String name) {
    final s = _scopes[name];
    if (s == null) {
      throw StateError(
        'No active scope named "$name". Call beginScope("$name") first.',
      );
    }
    return s;
  }

  /// Returns the [ServiceProviderBase] for the scope named [name].
  ServiceProviderBase providerFor(String name) => scope(name).serviceProvider;

  // -------------------------------------------------------------------------
  // Resolution helpers
  // -------------------------------------------------------------------------

  /// Resolves [T] from the scope named [name].
  T getRequired<T extends Object>(String name) =>
      providerFor(name).getRequired<T>();

  /// Tries to resolve [T] from the scope named [name]; returns `null` if not
  /// registered.
  T? tryGet<T extends Object>(String name) => providerFor(name).tryGet<T>();

  // -------------------------------------------------------------------------
  // Disposal
  // -------------------------------------------------------------------------

  /// Disposes the scope named [name] synchronously and removes it.
  ///
  /// Throws [StateError] if the scope does not exist.
  void endScope(String name) {
    final s = _scopes.remove(name);
    if (s == null) {
      throw StateError('No active scope named "$name" to end.');
    }
    s.dispose();
  }

  /// Disposes the scope named [name] asynchronously and removes it.
  Future<void> endScopeAsync(String name) async {
    final s = _scopes.remove(name);
    if (s == null) {
      throw StateError('No active scope named "$name" to end.');
    }
    await s.disposeAsync();
  }

  /// Disposes all active scopes synchronously.
  ///
  /// All scopes are disposed even if one throws. The first error encountered
  /// is rethrown after all scopes have been processed.
  void disposeAll() {
    final errors = <(String, Object)>[];
    for (final entry in _scopes.entries) {
      try {
        entry.value.dispose();
      } catch (e) {
        errors.add((entry.key, e));
      }
    }
    _scopes.clear();
    if (errors.isNotEmpty) throw errors.first.$2;
  }

  /// Disposes all active scopes asynchronously.
  ///
  /// All scopes are awaited even if one throws. The first error encountered
  /// is rethrown after all scopes have been processed.
  Future<void> disposeAllAsync() async {
    final errors = <(String, Object)>[];
    for (final entry in _scopes.entries) {
      try {
        await entry.value.disposeAsync();
      } catch (e) {
        errors.add((entry.key, e));
      }
    }
    _scopes.clear();
    if (errors.isNotEmpty) throw errors.first.$2;
  }

  /// Returns the names of all currently active scopes.
  List<String> get activeScopes => List.unmodifiable(_scopes.keys);
}
