import 'package:davianspace_dependencyinjection/src/descriptors/service_descriptor.dart';

/// A fast, keyed registry of [ServiceDescriptor]s indexed by [Type].
///
/// Supports multiple registrations per type (the last wins for single-resolution,
/// while [getAll] returns every registration in registration order).
final class TypeRegistry {
  /// Internal storage: `Type → List<ServiceDescriptor>` in insertion order.
  final _map = <Type, List<ServiceDescriptor>>{};

  /// Returns the number of distinct service types registered.
  int get length => _map.length;

  /// Returns `true` if any descriptor is registered for [type].
  bool contains(Type type) => _map.containsKey(type);

  /// Registers [descriptor].
  ///
  /// If [replace] is `true` the existing registrations for the same [Type]
  /// are replaced (used for `.tryAdd*` semantics that preserve the first, or
  /// `.add*` that appends).
  void add(ServiceDescriptor descriptor, {bool replace = false}) {
    if (replace) {
      _map[descriptor.serviceType] = [descriptor];
    } else {
      _map.putIfAbsent(descriptor.serviceType, () => []).add(descriptor);
    }
  }

  /// Returns the **last** registered descriptor for [type], or `null`.
  ServiceDescriptor? getLast(Type type) {
    final list = _map[type];
    if (list == null || list.isEmpty) return null;
    return list.last;
  }

  /// Returns **all** descriptors registered for [type] in insertion order.
  List<ServiceDescriptor> getAll(Type type) {
    return List.unmodifiable(_map[type] ?? const []);
  }

  /// Returns every descriptor in the registry (all types, insertion order).
  List<ServiceDescriptor> get all {
    return _map.values.expand((list) => list).toList(growable: false);
  }

  /// Removes all registrations for [type].
  void removeAll(Type type) => _map.remove(type);

  /// Clears the entire registry.
  void clear() => _map.clear();

  @override
  String toString() {
    final sb = StringBuffer('TypeRegistry(${_map.length} types):\n');
    for (final entry in _map.entries) {
      sb.writeln('  ${entry.key}: ${entry.value.length} descriptor(s)');
    }
    return sb.toString();
  }
}
