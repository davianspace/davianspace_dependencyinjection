import 'package:davianspace_dependencyinjection/src/diagnostics/circular_dependency_exception.dart';

/// Represents the current call stack of types being resolved.
///
/// Used to detect circular dependencies at runtime. Uses a [Set] for O(1)
/// membership checks and a [List] for ordered error reporting.
final class ResolutionChain {
  /// Ordered list for error message reconstruction.
  final _stack = <Type>[];

  /// Set for O(1) membership lookup.
  final _set = <Type>{};

  /// Returns the current resolution path, oldest-first.
  List<Type> get path => List.unmodifiable(_stack);

  /// Returns `true` if [type] is already in the current resolution chain.
  bool contains(Type type) => _set.contains(type);

  /// Pushes [type] onto the chain.
  ///
  /// Throws [CircularDependencyException] if [type] is already on the chain.
  void push(Type type) {
    if (_set.contains(type)) {
      final chain = [..._stack, type];
      throw CircularDependencyException(
        chain: chain,
        message: chain.map((t) => t.toString()).join(' → '),
      );
    }
    _stack.add(type);
    _set.add(type);
  }

  /// Pops the last type from the chain.
  void pop() {
    if (_stack.isNotEmpty) {
      _set.remove(_stack.removeLast());
    }
  }

  /// Runs [fn] with [type] pushed, guaranteeing a pop regardless of outcome.
  T guard<T>(Type type, T Function() fn) {
    push(type);
    try {
      return fn();
    } finally {
      pop();
    }
  }

  /// Async version of [guard].
  Future<T> guardAsync<T>(Type type, Future<T> Function() fn) async {
    push(type);
    try {
      return await fn();
    } finally {
      pop();
    }
  }

  @override
  String toString() => _stack.map((t) => t.toString()).join(' → ');
}
