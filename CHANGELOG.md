# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] — 2024-01-01

### Added

- `ServiceCollection` — mutable registration builder with fluent API.
- `ServiceProvider` — immutable, validated root DI container.
- `ScopedServiceProvider` / `ServiceScope` — per-scope provider with isolated
  `ScopedCache` and `DisposalTracker`.
- Service lifetimes: **singleton**, **scoped**, **transient**.
- Factory registration (`addSingletonFactory`, `addScopedFactory`,
  `addTransientFactory`) with `ServiceProviderBase` parameter (no unsafe casts).
- Async factory registration (`addSingletonAsync`, `addScopedAsync`,
  `addTransientAsync`, `addKeyedSingletonAsync`, `addKeyedScopedAsync`,
  `addKeyedTransientAsync`).
- Pre-built instance registration (`addInstance`).
- **Keyed services** — register multiple implementations under a typed key
  (`addKeyedSingleton`, `addKeyedScoped`, `addKeyedTransient`, factory/async
  variants); resolved with `getRequiredKeyed` / `tryGetKeyed` /
  `getAsyncKeyed`.
- **Multi-registration** — `getAll<T>()` returns every registration for `T`
  in insertion order (backed by `Map<Type, List<CallSite>>` for O(1) lookup).
- `tryGet<T>()` — null-safe synchronous resolution.
- `tryGetAsync<T>()` — null-safe asynchronous resolution (on both root and
  scoped providers).
- `replace(ServiceDescriptor)` — override an existing registration.
- `addRange(Iterable<ServiceDescriptor>)` — bulk registration.
- `tryAdd` / `tryAddSingleton` / `tryAddScoped` / `tryAddTransient` /
  `tryAddKeyed` — no-op if type is already registered.
- `isRegistered<T>()` / `isKeyedRegistered<T>(key)` on concrete providers.
- `ResolutionChain` — O(1) Set-backed cycle detection (previously O(n)).
- Cycle detection propagated through the full transitive dependency graph.
- `DisposalTracker.track()` throws `StateError` in production (not just in
  debug mode via `assert`).
- Scope-disposed guard on all `ScopedServiceProvider` resolution methods.
- `ServiceProviderOptions.production` is the new default for
  `buildServiceProvider()` (was `development`).
- `CallSiteValidator` — captive-dependency scope validation (singleton
  depending on scoped service) in development mode.
- `DependencyGraph` — topological cycle detection at build time.
- `ServiceProviderDiagnostics` — structured trace/info/warn/error events.
- Constructor injection via AOT-safe `ReflectionHelper` factory system.
- `dumpRegistrations()` diagnostic helper on `ServiceProvider`.

[1.0.0]: https://github.com/davianspace/davianspace_dependencyinjection/releases/tag/v1.0.0
