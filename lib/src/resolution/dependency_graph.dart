import 'package:davianspace_dependencyinjection/src/diagnostics/circular_dependency_exception.dart';

/// A directed graph of service dependencies built during the container's build
/// phase.
///
/// Each edge [from] → [to] means "service [from] depends on service [to]".
/// After all edges are added, [detectCycles] performs a DFS to find any cycles.
final class DependencyGraph {
  final _adjacency = <Type, Set<Type>>{};

  /// Records that [from] depends on [to].
  void addEdge(Type from, Type to) {
    _adjacency.putIfAbsent(from, () => {}).add(to);
    _adjacency.putIfAbsent(to, () => {});
  }

  /// Ensures [type] has a node even if it has no edges.
  void addNode(Type type) {
    _adjacency.putIfAbsent(type, () => {});
  }

  /// Returns all direct dependencies of [type].
  Set<Type> dependenciesOf(Type type) =>
      Set.unmodifiable(_adjacency[type] ?? const {});

  /// Performs a depth-first search over the graph to find cycles.
  ///
  /// Throws [CircularDependencyException] on the first cycle found.
  void detectCycles() {
    final visited = <Type>{};
    final onStack = <Type>{};
    final parent = <Type, Type?>{};

    void dfs(Type node) {
      visited.add(node);
      onStack.add(node);

      for (final neighbor in (_adjacency[node] ?? const <Type>{})) {
        parent[neighbor] = node;
        if (!visited.contains(neighbor)) {
          dfs(neighbor);
        } else if (onStack.contains(neighbor)) {
          // Reconstruct the cycle path.
          final cycle = <Type>[];
          var current = node;
          while (current != neighbor) {
            cycle.add(current);
            current = parent[current]!;
          }
          cycle
            ..add(neighbor)
            ..add(neighbor); // repeat start to show it's a cycle
          throw CircularDependencyException(
            chain: cycle.reversed.toList(),
            message: cycle.reversed.map((t) => t.toString()).join(' → '),
          );
        }
      }

      onStack.remove(node);
    }

    for (final node in _adjacency.keys) {
      if (!visited.contains(node)) {
        dfs(node);
      }
    }
  }

  /// Returns every node in the graph.
  Set<Type> get nodes => Set.unmodifiable(_adjacency.keys);

  @override
  String toString() {
    final sb = StringBuffer('DependencyGraph:\n');
    for (final entry in _adjacency.entries) {
      sb.writeln('  ${entry.key} → ${entry.value.join(', ')}');
    }
    return sb.toString();
  }
}
