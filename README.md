# davianspace_dependencyinjection

[![pub.dev](https://img.shields.io/pub/v/davianspace_dependencyinjection.svg)](https://pub.dev/packages/davianspace_dependencyinjection)
[![Dart SDK](https://img.shields.io/badge/Dart-%3E%3D3.0.0-blue.svg)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A full-featured, enterprise-grade **dependency injection** (DI) container for Dart,
inspired by `Microsoft.Extensions.DependencyInjection`. Supports singleton, scoped,
and transient lifetimes; keyed services; async factories; constructor injection;
multi-registration; and rich diagnostics — all AOT-safe.

---

## Features

| Feature | Status |
|---|---|
| Singleton / Scoped / Transient lifetimes | ✅ |
| Constructor injection (AOT-safe) | ✅ |
| Factory registration (sync & async) | ✅ |
| Pre-built instance registration | ✅ |
| Keyed services (type + key lookup) | ✅ |
| Multiple registrations (`getAll<T>()`) | ✅ |
| `tryGet` / `tryGetAsync` (null-safe) | ✅ |
| Scoped providers & `createScope()` | ✅ |
| Scope lifecycle / disposal (`IDisposable`) | ✅ |
| Circular dependency detection | ✅ |
| Scope validation (captive dependency) | ✅ |
| Diagnostics & tracing | ✅ |
| `replace<T>()` / `addRange()` | ✅ |
| `tryAdd*` (non-overwriting registration) | ✅ |
| `isRegistered<T>()` on built provider | ✅ |
| **Options Pattern** (`Options<T>`, `OptionsSnapshot<T>`, `OptionsMonitor<T>`) | ✅ |
| **Configuration** (`Configuration`, `ConfigurationRoot`, `ConfigurationBuilder`) | ✅ |

---

## Installation

```yaml
dependencies:
  davianspace_dependencyinjection: ^1.0.3
```

---

## Quick start

```dart
import 'package:davianspace_dependencyinjection/davianspace_dependencyinjection.dart';

// 1. Define services
abstract class ILogger {
  void log(String message);
}

class ConsoleLogger implements ILogger {
  @override
  void log(String message) => print('[LOG] $message');
}

class MyService {
  final ILogger _logger;
  MyService(this._logger);

  void run() => _logger.log('MyService running!');
}

// 2. Register & build
final provider = ServiceCollection()
  ..addSingleton<ILogger, ConsoleLogger>()
  ..addTransient<MyService, MyService>()
  ..buildServiceProvider();

// 3. Resolve
final svc = provider.getRequired<MyService>();
svc.run(); // [LOG] MyService running!
```

> **Constructor injection** requires reflection-free factory wiring via
> `ReflectionHelper` — see [example/example.dart](example/example.dart) for
> a complete walkthrough.

---

## Service lifetimes

| Lifetime | Instances created | Typical use |
|---|---|---|
| **Singleton** | Once per container | Caches, configs, shared state |
| **Scoped** | Once per scope | Per-request context in servers |
| **Transient** | Each resolution | Stateless services, formatters |

```dart
ServiceCollection()
  ..addSingleton<ICache, MemoryCache>()
  ..addScoped<IUnitOfWork, EfUnitOfWork>()
  ..addTransient<IEmailSender, SmtpEmailSender>()
  ..buildServiceProvider();
```

---

## Factory registration

```dart
ServiceCollection()
  ..addSingletonFactory<IConfig>(
    (provider) => AppConfig.fromEnv(),
  )
  ..addScopedFactory<IDbContext>(
    (provider) => DbContext(provider.getRequired<IConfig>().connectionString),
  )
  ..buildServiceProvider();
```

Async factories are also supported:

```dart
..addSingletonAsync<ISecretManager>(
  (provider) async => await SecretManager.loadAsync(),
)
```

Resolve async services with `getAsync<T>()` or `tryGetAsync<T?>()`.

---

## Keyed services

Register multiple implementations of the same interface, distinguished by a key:

```dart
final provider = ServiceCollection()
  ..addKeyedSingleton<IMessageBus, InMemoryBus>('memory')
  ..addKeyedSingleton<IMessageBus, RabbitMqBus>('rabbitmq')
  ..buildServiceProvider();

final bus = provider.getRequiredKeyed<IMessageBus>('rabbitmq');
```

---

## Multiple registrations (`getAll`)

Register many implementations of the same interface and resolve them all:

```dart
final provider = ServiceCollection()
  ..addSingleton<IValidator, NotNullValidator>()
  ..addSingleton<IValidator, LengthValidator>()
  ..addSingleton<IValidator, RegexValidator>()
  ..buildServiceProvider();

final validators = provider.getAll<IValidator>(); // returns all three
```

---

## Scoped resolution

Scoped services live for the lifetime of a scope. Use `createScope()` and
dispose the scope when finished:

```dart
final scope = provider.createScope();
try {
  final uow = scope.serviceProvider.getRequired<IUnitOfWork>();
  await uow.saveChangesAsync();
} finally {
  scope.dispose(); // disposes all scoped IDisposable services
}
```

---

## Null-safe resolution

```dart
final logger = provider.tryGet<ILogger>(); // ILogger? — null if not registered
final config = await provider.tryGetAsync<IConfig>(); // Future<IConfig?>
```

---

## `replace`, `addRange`, `tryAdd`

```dart
final services = ServiceCollection()
  ..addSingleton<ILogger, ConsoleLogger>()                  // initial
  ..replace(ServiceDescriptor.type(                         // overrides ConsoleLogger
      serviceType: ILogger,
      implementationType: FileLogger,
      lifetime: ServiceLifetime.singleton,
  ))
  ..tryAddSingleton<IMetrics, NullMetrics>()                // no-op if already registered
  ..addRange([                                              // bulk add
      ServiceDescriptor.type(serviceType: A, implementationType: A, lifetime: ServiceLifetime.transient),
      ServiceDescriptor.type(serviceType: B, implementationType: B, lifetime: ServiceLifetime.transient),
  ]);
```

---

## `isRegistered`

```dart
if (provider.isRegistered<IFeatureFlag>()) {
  final flag = provider.getRequired<IFeatureFlag>();
  // ...
}
```

---

## Dispose

The root provider and all scoped providers implement `dispose()`/`disposeAsync()`.
Services that implement `Disposable` or `AsyncDisposable` are tracked and disposed
automatically when their owning scope/provider is disposed.

```dart
await provider.disposeAsync();
```

---

## Container options

```dart
// Default — production (no scope validation, no verbose diagnostics)
provider.buildServiceProvider();

// Development — enables scope validation and diagnostics
provider.buildServiceProvider(ServiceProviderOptions.development);
```

| Option | Production | Development |
|---|---|---|
| `validateOnBuild` | false | true |
| `validateScopes` | false | true |
| `enableDiagnostics` | false | true |

---

## Architecture

```
ServiceCollection
    └─ buildServiceProvider()
           ├─ CallSiteResolver  →  Map<Type, CallSite>  (compile phase)
           ├─ DependencyGraph   →  cycle detection
           ├─ CallSiteValidator →  scope captive check
           └─ RootServiceProvider
                  ├─ SingletonCache
                  ├─ DisposalTracker
                  └─ ServiceProvider  (root)
                         └─ createScope() → ScopedServiceProvider
                                              ├─ ScopedCache
                                              └─ DisposalTracker
```

At resolution time `CallSiteExecutor` walks the `CallSite` tree, using
`ResolutionChain` (O(1) Set-backed) for cycle detection.

---

## Options Pattern

The Options Pattern from
[`davianspace_options`](https://pub.dev/packages/davianspace_options) is
natively integrated. Use `configure<T>()` and `postConfigure<T>()` on
`ServiceCollection` — the container registers `Options<T>`,
`OptionsSnapshot<T>`, and `OptionsMonitor<T>` at the correct lifetimes
automatically.

```dart
import 'package:davianspace_options/davianspace_options.dart';
import 'package:davianspace_dependencyinjection/davianspace_dependencyinjection.dart';

class DatabaseOptions {
  String host = 'localhost';
  int    port = 5432;
}

final provider = ServiceCollection()
  ..configure<DatabaseOptions>(
    factory: DatabaseOptions.new,
    configure: (opts) {
      opts.host = 'db.prod.internal';
      opts.port = 5432;
    },
  )
  ..postConfigure<DatabaseOptions>((opts) {
    if (opts.host.isEmpty) throw ArgumentError('host is required');
  })
  .buildServiceProvider();

// Inject by interface.
final opts     = provider.getRequired<Options<DatabaseOptions>>().value;
final snapshot = provider.getRequired<OptionsSnapshot<DatabaseOptions>>().value;
final monitor  = provider.getRequired<OptionsMonitor<DatabaseOptions>>();

// Trigger a live reload.
final notifier =
    provider.getRequiredKeyed<OptionsChangeNotifier>(DatabaseOptions);
notifier.notifyChange(Options.defaultName);
```

| Injectable type      | Lifetime  |
|----------------------|-----------|
| `Options<T>`         | Singleton |
| `OptionsSnapshot<T>` | Scoped    |
| `OptionsMonitor<T>`  | Singleton |

---

## Configuration

The Configuration system from
[`davianspace_configuration`](https://pub.dev/packages/davianspace_configuration)
is also natively integrated. Use `addConfiguration()` or
`addConfigurationBuilder()` to register `Configuration` as an injectable
singleton.

```dart
import 'package:davianspace_configuration/davianspace_configuration.dart';
import 'package:davianspace_dependencyinjection/davianspace_dependencyinjection.dart';

// Option A — register a pre-built root.
final config = ConfigurationBuilder()
    .addJsonFile('appsettings.json')
    .addEnvironmentVariables(prefix: 'APP_')
    .build();

final provider = ServiceCollection()
  ..addConfiguration(config)   // registers Configuration + ConfigurationRoot
  ..configure<DatabaseOptions>(
    factory: DatabaseOptions.new,
    configure: (opts) {
      final s = config.getSection('Database');
      opts.host = s['Host'] ?? 'localhost';
      opts.port = int.parse(s['Port'] ?? '5432');
    },
  )
  .buildServiceProvider();

final cfg = provider.getRequired<Configuration>();

// Option B — let the container build the configuration lazily.
final provider2 = ServiceCollection()
  ..addConfigurationBuilder((builder) {
    builder
      .addJsonFile('appsettings.json')
      .addEnvironmentVariables(prefix: 'APP_');
  })
  .buildServiceProvider();
```

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). All PRs welcome.

## License

MIT — see [LICENSE](LICENSE).

