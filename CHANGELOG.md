# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.3] — 2026-02-25

### Added

- **Options Pattern integration** — `davianspace_options` is now a runtime
  dependency. `configure<T>()` and `postConfigure<T>()` extension methods on
  `ServiceCollection` register `Options<T>` (singleton), `OptionsSnapshot<T>`
  (scoped), and `OptionsMonitor<T>` (singleton) automatically. A keyed
  `OptionsChangeNotifier` is registered per options type to drive live reloads
  without a direct `T` reference.
- **Configuration integration** — `davianspace_configuration` is now a runtime
  dependency. `addConfiguration(config)` and `addConfigurationBuilder(build)`
  extension methods on `ServiceCollection` register `Configuration` (and
  `ConfigurationRoot` when applicable) as injectable singletons.

### Changed

- **SDK lower bound relaxed** from `>=3.3.0` to `>=3.0.0`. Field promotion
  in `CallSiteExecutor` was refactored to use local variable capture to
  remain compatible with Dart 3.0.

### Fixed

- **`CallSiteExecutor._scopedCache` field promotion** — replaced implicit
  `_scopedCache != null` field promotion (Dart ≥3.2 only) with explicit
  local variable capture (`final cache = _scopedCache`) in both the sync
  `_resolveScoped` and async `_resolveScopedAsync` paths.
- **Dispose guard on root `ServiceProvider`** — all resolution methods
  (`tryGet`, `getRequired`, `getAll`, `getAsync`, `tryGetAsync`,
  `tryGetKeyed`, `getRequiredKeyed`, `getAsyncKeyed`, `createScope`,
  `resolveRequired`, `resolveAll`) now throw `StateError` when called on a
  disposed provider, consistent with the guard already in place on
  `ScopedServiceProvider`.
- **`CallSiteValidator.validate()` — `collectAll` parameter honoured** — the
  parameter was previously ignored; violations now accumulate into
  `ContainerBuildException` when `collectAll: true` (default), or throw
  `ScopeViolationException` immediately when `collectAll: false`.
- **`DisposalException` reports all failures** — previously only the first
  disposal error was recorded; every failing service is now captured in the
  `errors` list. The `serviceType` and `cause` convenience getters retain
  first-error access for backward compatibility.
- **`DependencyGraph.detectCycles()` — iterative DFS** — replaced the
  recursive depth-first search with an explicit stack to eliminate the risk
  of a `StackOverflowError` on deep (but acyclic) dependency graphs.
- **`OptionsChangeDisposable.dispose()` is now idempotent** — calling
  `dispose()` twice no longer double-removes the listener or throws.
- **`ScopeManager.disposeAll()` / `disposeAllAsync()` continue on error** —
  all scopes are now disposed even when one throws; the first error is
  rethrown after all scopes have been processed, matching the behaviour of
  `DisposalTracker`.
- **`RootServiceProvider.dispose()` — unawaited `diagnostics.close()`** —
  the fire-and-forget `Future` returned by `StreamController.close()` is now
  explicitly marked `unawaited`, eliminating the implicit discard.

### Performance

- **`CallSiteExecutor` cached per-provider** — both `ServiceProvider` and
  `ScopedServiceProvider` previously allocated a new `CallSiteExecutor`
  (5-argument constructor) on every resolution call. The executor is now
  a `late final` field initialised once per provider, reducing per-call
  allocation to a single `ResolutionChain` object.

### Tests

- Test suite expanded from 52 to 112 tests (+60).
- Added `ActivatorHelper.instance.clear()` to global `setUp` to prevent
  inter-test contamination via the global singleton registry.
- New test groups: **Root provider disposal guard** (11), **`DisposalException`
  multi-error** (3), **Scope violation validator `collectAll`** (2),
  **`CallSiteExecutor` caching** (2), **`ScopeManager`** (11),
  **`Lazy<T>`** (6), **`ActivatorUtilities`** (4), **Options pattern** (10),
  **`ServiceModule`** (2), **`DependencyGraph` iterative DFS** (5).

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
