import 'package:davianspace_dependencyinjection/src/descriptors/keyed_service_descriptor.dart';

/// Stores all keyed-service registrations indexed by `(Type, key)`.
///
/// Analogous to the keyed-service support introduced in .NET 8
/// (`IKeyedServiceProvider`, `AddKeyedSingleton`, etc.).
final class KeyedServiceRegistry {
  final _map = <_KeyedEntry, List<KeyedServiceDescriptor>>{};

  /// Registers [descriptor].
  void add(KeyedServiceDescriptor descriptor) {
    _map
        .putIfAbsent(
            _KeyedEntry(descriptor.serviceType, descriptor.key), () => [])
        .add(descriptor);
  }

  /// Returns the **last** registered descriptor for ([type], [key]) or `null`.
  KeyedServiceDescriptor? getLast(Type type, Object key) {
    final list = _map[_KeyedEntry(type, key)];
    if (list == null || list.isEmpty) return null;
    return list.last;
  }

  /// Returns all descriptors for ([type], [key]) in registration order.
  List<KeyedServiceDescriptor> getAll(Type type, Object key) {
    return List.unmodifiable(_map[_KeyedEntry(type, key)] ?? const []);
  }

  /// Returns `true` if any registration exists for ([type], [key]).
  bool contains(Type type, Object key) {
    return _map.containsKey(_KeyedEntry(type, key));
  }

  /// All keyed descriptors (flat list).
  List<KeyedServiceDescriptor> get all =>
      _map.values.expand((l) => l).toList(growable: false);
}

final class _KeyedEntry {
  final Type type;
  final Object key;

  const _KeyedEntry(this.type, this.key);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _KeyedEntry && other.type == type && other.key == key);

  @override
  int get hashCode => Object.hash(type, key);
}
