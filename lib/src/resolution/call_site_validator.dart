import 'package:davianspace_dependencyinjection/src/callsite/call_site.dart';
import 'package:davianspace_dependencyinjection/src/callsite/constructor_call_site.dart';
import 'package:davianspace_dependencyinjection/src/callsite/keyed_call_site.dart';
import 'package:davianspace_dependencyinjection/src/callsite/scoped_call_site.dart';
import 'package:davianspace_dependencyinjection/src/callsite/singleton_call_site.dart';
import 'package:davianspace_dependencyinjection/src/callsite/transient_call_site.dart';
import 'package:davianspace_dependencyinjection/src/descriptors/service_lifetime.dart';
import 'package:davianspace_dependencyinjection/src/diagnostics/scope_violation_exception.dart';
import 'package:davianspace_dependencyinjection/src/utils/reflection_helper.dart';

/// Validates the built call site tree for scope violations and missing
/// dependency registrations.
///
/// Runs during `buildServiceProvider()` when
/// [ServiceProviderOptions.validateScopes] or
/// [ServiceProviderOptions.validateOnBuild] is `true`.
final class CallSiteValidator {
  final Map<Type, CallSite> _callSites;
  final List<String> _errors = [];

  /// When `true`, every call site is visited even after the first violation;
  /// all messages accumulate in [_errors]. When `false`, the first violation
  /// throws [ScopeViolationException] immediately.
  bool _collectAll = true;

  CallSiteValidator(this._callSites);

  // -------------------------------------------------------------------------
  // Scope violation validation  (validateScopes: true)
  // -------------------------------------------------------------------------

  /// Validates every call site for captive-dependency (scope violation) bugs.
  ///
  /// When [collectAll] is `true` (default) all violations are gathered before
  /// returning; the caller decides whether to throw. When `false`, the first
  /// violation immediately throws [ScopeViolationException].
  List<String> validate({bool collectAll = true}) {
    _collectAll = collectAll;
    for (final entry in _callSites.entries) {
      _validateCallSite(entry.value, null, ServiceLifetime.transient);
    }
    return List.unmodifiable(_errors);
  }

  void _validateCallSite(
    CallSite callSite,
    Type? ownerType,
    ServiceLifetime ownerLifetime,
  ) {
    if (ownerLifetime == ServiceLifetime.singleton &&
        callSite.lifetime == ServiceLifetime.scoped) {
      final msg = 'ScopeViolation: '
          '"${ownerType ?? callSite.serviceType}" (singleton) '
          'depends on "${callSite.serviceType}" (scoped).';
      _errors.add(msg);
      if (!_collectAll) {
        throw ScopeViolationException(
          singletonType: ownerType ?? callSite.serviceType,
          scopedType: callSite.serviceType,
        );
      }
    }

    switch (callSite) {
      case SingletonCallSite(inner: final inner, serviceType: final st):
        _validateCallSite(inner, st, ServiceLifetime.singleton);
      case ScopedCallSite(inner: final inner, serviceType: final st):
        _validateCallSite(inner, st, ServiceLifetime.scoped);
      case TransientCallSite(inner: final inner, serviceType: final st):
        _validateCallSite(inner, st, ownerLifetime);
      case KeyedCallSite(inner: final inner, serviceType: final st):
        _validateCallSite(inner, st, callSite.lifetime);
      case ConstructorCallSite(:final implementationType):
        _validateConstructorScope(implementationType, ownerType, ownerLifetime);
      default:
        break;
    }
  }

  void _validateConstructorScope(
    Type implementationType,
    Type? ownerType,
    ServiceLifetime ownerLifetime,
  ) {
    if (ownerLifetime != ServiceLifetime.singleton) return;
    final factory = ReflectionHelper.instance.factoryFor(implementationType);
    if (factory == null) return;
    final requestedTypes = <Type>[];
    try {
      factory((Type dep) {
        requestedTypes.add(dep);
        return _csValidatorSentinel;
      });
    } catch (_) {}
    for (final dep in requestedTypes) {
      final depCallSite = _callSites[dep];
      if (depCallSite == null) continue;
      if (depCallSite.lifetime == ServiceLifetime.scoped) {
        final msg = 'ScopeViolation: '
            '"${ownerType ?? implementationType}" (singleton) '
            'depends on "$dep" (scoped).';
        _errors.add(msg);
        if (!_collectAll) {
          throw ScopeViolationException(
            singletonType: ownerType ?? implementationType,
            scopedType: dep,
          );
        }
      }
    }
  }

  // -------------------------------------------------------------------------
  // Missing-dependency validation  (validateOnBuild: true)
  // -------------------------------------------------------------------------

  /// Probes every [ConstructorCallSite] and verifies all dependencies are
  /// registered in the container.
  List<String> validateDependencies() {
    final missing = <String>[];
    for (final entry in _callSites.entries) {
      _collectMissingDeps(entry.value, missing);
    }
    return List.unmodifiable(missing);
  }

  void _collectMissingDeps(CallSite callSite, List<String> missing) {
    switch (callSite) {
      case SingletonCallSite(inner: final inner):
        _collectMissingDeps(inner, missing);
      case ScopedCallSite(inner: final inner):
        _collectMissingDeps(inner, missing);
      case TransientCallSite(inner: final inner):
        _collectMissingDeps(inner, missing);
      case KeyedCallSite(inner: final inner):
        _collectMissingDeps(inner, missing);
      case ConstructorCallSite(:final implementationType, :final serviceType):
        _collectMissingConstructorDeps(serviceType, implementationType, missing);
      default:
        break;
    }
  }

  void _collectMissingConstructorDeps(
    Type serviceType,
    Type implementationType,
    List<String> missing,
  ) {
    final factory = ReflectionHelper.instance.factoryFor(implementationType);
    if (factory == null) return;
    final requestedTypes = <Type>[];
    try {
      factory((Type dep) {
        requestedTypes.add(dep);
        return _csValidatorSentinel;
      });
    } catch (_) {}
    for (final dep in requestedTypes) {
      if (!_callSites.containsKey(dep)) {
        missing.add(
          'MissingDependency: "$serviceType" ($implementationType) '
          'depends on "$dep" which is not registered.',
        );
      }
    }
  }
}

final _csValidatorSentinel = _CsValidatorSentinel();
final class _CsValidatorSentinel {}
