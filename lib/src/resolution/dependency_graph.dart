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
  /// Uses an **iterative** DFS to avoid stack-overflow on large (but acyclic)
  /// dependency graphs.
  ///
  /// Throws [CircularDependencyException] on the first cycle found.
  void detectCycles() {
    final visited = <Type>{};
    final onStack = <Type>{};
    final parent = <Type, Type?>{};

    // Stack frames: (node, iterator over remaining neighbors).
    final stack = <(Type, Iterator<Type>)>[];

    for (final start in _adjacency.keys) {
      if (visited.contains(start)) continue;

      visited.add(start);
      onStack.add(start);
      parent[start] = null;
      stack.add((start, (_adjacency[start] ?? const <Type>{}).iterator));

      while (stack.isNotEmpty) {
        final (node, neighbors) = stack.last;

        if (neighbors.moveNext()) {
          final neighbor = neighbors.current;
          parent[neighbor] = node;

          if (!visited.contains(neighbor)) {
            visited.add(neighbor);
            onStack.add(neighbor);
            stack.add(
                (neighbor, (_adjacency[neighbor] ?? const <Type>{}).iterator));
          } else if (onStack.contains(neighbor)) {
            // Back-edge detected — reconstruct and report the cycle.
            final cycle = <Type>[];
            var current = node;
            while (current != neighbor) {
              cycle.add(current);
              current = parent[current]!;
            }
            cycle
              ..add(neighbor)
              ..add(neighbor); // repeat start to show it's a cycle
            final path = cycle.reversed.toList();
            throw CircularDependencyException(
              chain: path,
              message: path.map((t) => t.toString()).join(' → '),
            );
          }
        } else {
          // All neighbors of this node are processed — pop it.
          stack.removeLast();
          onStack.remove(node);
        }
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
