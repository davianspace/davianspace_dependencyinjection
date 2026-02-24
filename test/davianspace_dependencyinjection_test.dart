import 'package:davianspace_dependencyinjection/davianspace_dependencyinjection.dart';
import 'package:davianspace_dependencyinjection/src/resolution/dependency_graph.dart';
import 'package:test/test.dart';

// ignore_for_file: avoid_print

// ─────────────────────────────────────────────────────────────────────────────
// Test doubles
// ─────────────────────────────────────────────────────────────────────────────

abstract class ILogger {
  void log(String message);
}

class ConsoleLogger implements ILogger {
  @override
  void log(String message) => print('[LOG] $message');
}

abstract class IDatabase {
  String query(String sql);
}

class Database implements IDatabase {
  final ILogger logger;
  Database(this.logger);

  @override
  String query(String sql) {
    logger.log(sql);
    return 'result:$sql';
  }
}

abstract class IUserRepository {
  String findById(int id);
}

class UserRepository implements IUserRepository {
  final IDatabase database;
  UserRepository(this.database);

  @override
  String findById(int id) => database.query('SELECT * FROM users WHERE id=$id');
}

abstract class IEmailSender {
  void send(String to, String body);
}

class SmtpEmailSender implements IEmailSender {
  @override
  void send(String to, String body) => print('SMTP: $to — $body');
}

// ─────────────────────────────────────────────────────────────────────────────
// Disposable test doubles
// ─────────────────────────────────────────────────────────────────────────────

class _TestDisposable with Disposable {
  bool disposed = false;
  @override
  void dispose() => disposed = true;
}

class _TestAsyncDisposable with AsyncDisposable {
  bool disposed = false;
  @override
  Future<void> disposeAsync() async => disposed = true;
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper: register factories with ReflectionHelper
// ─────────────────────────────────────────────────────────────────────────────
void _registerFactories() {
  ReflectionHelper.instance
    ..register(ConsoleLogger, (_) => ConsoleLogger())
    ..register(Database, (resolve) => Database(resolve(ILogger) as ILogger))
    ..register(
      UserRepository,
      (resolve) => UserRepository(resolve(IDatabase) as IDatabase),
    )
    ..register(SmtpEmailSender, (_) => SmtpEmailSender());
}

DependencyGraph _buildCyclicGraph() {
  return DependencyGraph()
    ..addEdge(ILogger, IDatabase)
    ..addEdge(IDatabase, ILogger);
}

void main() {
  setUp(() {
    ReflectionHelper.instance.clear();
    _registerFactories();
  });

  // ─────────────────────────────────────────────────────────────────────────
  // ServiceDescriptor
  // ─────────────────────────────────────────────────────────────────────────
  group('ServiceDescriptor', () {
    test('type registration', () {
      final d = ServiceDescriptor.type(
        serviceType: ILogger,
        implementationType: ConsoleLogger,
        lifetime: ServiceLifetime.singleton,
      );
      expect(d.isTypeRegistration, isTrue);
      expect(d.implementationType, equals(ConsoleLogger));
      expect(d.lifetime, equals(ServiceLifetime.singleton));
    });

    test('factory registration', () {
      final d = ServiceDescriptor.factoryFn(
        serviceType: ILogger,
        lifetime: ServiceLifetime.transient,
        factory: (_) => ConsoleLogger(),
      );
      expect(d.isFactoryRegistration, isTrue);
    });

    test('instance registration is always singleton', () {
      final logger = ConsoleLogger();
      final d = ServiceDescriptor.instanceValue(
        serviceType: ILogger,
        instance: logger,
      );
      expect(d.isInstanceRegistration, isTrue);
      expect(d.lifetime, equals(ServiceLifetime.singleton));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // ServiceCollection
  // ─────────────────────────────────────────────────────────────────────────
  group('ServiceCollection', () {
    test('registers services', () {
      final sc = ServiceCollection()
        ..addSingleton<ILogger, ConsoleLogger>()
        ..addScoped<IDatabase, Database>()
        ..addTransient<IEmailSender, SmtpEmailSender>();

      expect(sc.isRegistered<ILogger>(), isTrue);
      expect(sc.isRegistered<IDatabase>(), isTrue);
      expect(sc.isRegistered<IEmailSender>(), isTrue);
      expect(sc.count, equals(3));
    });

    test('tryAdd does not overwrite existing', () {
      final sc = ServiceCollection()..addSingleton<ILogger, ConsoleLogger>();
      sc.tryAdd(ServiceDescriptor.type(
        serviceType: ILogger,
        implementationType: ConsoleLogger,
        lifetime: ServiceLifetime.transient,
      ));
      final descs = sc.descriptorsFor<ILogger>();
      expect(descs, hasLength(1));
      expect(descs.first.lifetime, equals(ServiceLifetime.singleton));
    });

    test('throws after build', () {
      final sc = ServiceCollection()..addSingleton<ILogger, ConsoleLogger>();
      sc.buildServiceProvider(ServiceProviderOptions.production);
      expect(() => sc.addScoped<IDatabase, Database>(), throwsStateError);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Singleton lifetime
  // ─────────────────────────────────────────────────────────────────────────
  group('Singleton lifetime', () {
    late ServiceProvider provider;

    setUp(() {
      final sc = ServiceCollection()..addSingleton<ILogger, ConsoleLogger>();
      provider = sc.buildServiceProvider(ServiceProviderOptions.production);
    });

    tearDown(() => provider.dispose());

    test('same instance returned every time', () {
      final a = provider.getRequired<ILogger>();
      final b = provider.getRequired<ILogger>();
      expect(identical(a, b), isTrue);
    });

    test('same instance across scopes', () {
      final root = provider.getRequired<ILogger>();
      final scope = provider.createScope();
      final scoped = scope.serviceProvider.getRequired<ILogger>();
      expect(identical(root, scoped), isTrue);
      scope.dispose();
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Scoped lifetime
  // ─────────────────────────────────────────────────────────────────────────
  group('Scoped lifetime', () {
    late ServiceProvider provider;

    setUp(() {
      final sc = ServiceCollection()
        ..addSingleton<ILogger, ConsoleLogger>()
        ..addScoped<IDatabase, Database>();
      provider = sc.buildServiceProvider(ServiceProviderOptions.production);
    });

    tearDown(() => provider.dispose());

    test('same instance within a scope', () {
      final scope = provider.createScope();
      final a = scope.serviceProvider.getRequired<IDatabase>();
      final b = scope.serviceProvider.getRequired<IDatabase>();
      expect(identical(a, b), isTrue);
      scope.dispose();
    });

    test('different instance across scopes', () {
      final s1 = provider.createScope();
      final s2 = provider.createScope();
      final a = s1.serviceProvider.getRequired<IDatabase>();
      final b = s2.serviceProvider.getRequired<IDatabase>();
      expect(identical(a, b), isFalse);
      s1.dispose();
      s2.dispose();
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Transient lifetime
  // ─────────────────────────────────────────────────────────────────────────
  group('Transient lifetime', () {
    late ServiceProvider provider;

    setUp(() {
      final sc = ServiceCollection()
        ..addTransient<IEmailSender, SmtpEmailSender>();
      provider = sc.buildServiceProvider(ServiceProviderOptions.production);
    });

    tearDown(() => provider.dispose());

    test('new instance on every resolution', () {
      final a = provider.getRequired<IEmailSender>();
      final b = provider.getRequired<IEmailSender>();
      expect(identical(a, b), isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Factory registration
  // ─────────────────────────────────────────────────────────────────────────
  group('Factory registration', () {
    test('sync factory creates correct instance', () {
      final sc = ServiceCollection()
        ..addSingletonFactory<ILogger>((p) => ConsoleLogger());
      final provider =
          sc.buildServiceProvider(ServiceProviderOptions.production);

      final logger = provider.getRequired<ILogger>();
      expect(logger, isA<ConsoleLogger>());
      provider.dispose();
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Instance registration
  // ─────────────────────────────────────────────────────────────────────────
  group('Instance registration', () {
    test('returns the exact pre-built instance', () {
      final logger = ConsoleLogger();
      final sc = ServiceCollection()..addInstance<ILogger>(logger);
      final provider =
          sc.buildServiceProvider(ServiceProviderOptions.production);

      expect(identical(provider.getRequired<ILogger>(), logger), isTrue);
      provider.dispose();
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Deep dependency resolution
  // ─────────────────────────────────────────────────────────────────────────
  group('Deep dependency resolution', () {
    test('resolves transitive deps correctly', () {
      final sc = ServiceCollection()
        ..addSingleton<ILogger, ConsoleLogger>()
        ..addSingleton<IDatabase, Database>()
        ..addSingleton<IUserRepository, UserRepository>();
      final provider =
          sc.buildServiceProvider(ServiceProviderOptions.production);

      final repo = provider.getRequired<IUserRepository>();
      expect(repo, isA<UserRepository>());
      final result = repo.findById(42);
      expect(result, contains('42'));
      provider.dispose();
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // tryGet
  // ─────────────────────────────────────────────────────────────────────────
  group('tryGet', () {
    test('returns null for unregistered type', () {
      final provider = ServiceCollection()
          .buildServiceProvider(ServiceProviderOptions.production);
      expect(provider.tryGet<ILogger>(), isNull);
      provider.dispose();
    });

    test('returns instance for registered type', () {
      final sc = ServiceCollection()..addSingleton<ILogger, ConsoleLogger>();
      final provider =
          sc.buildServiceProvider(ServiceProviderOptions.production);
      expect(provider.tryGet<ILogger>(), isNotNull);
      provider.dispose();
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // MissingServiceException
  // ─────────────────────────────────────────────────────────────────────────
  group('MissingServiceException', () {
    test('getRequired throws for unregistered type', () {
      final provider = ServiceCollection()
          .buildServiceProvider(ServiceProviderOptions.production);
      expect(
        () => provider.getRequired<IDatabase>(),
        throwsA(isA<MissingServiceException>()),
      );
      provider.dispose();
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Keyed services
  // ─────────────────────────────────────────────────────────────────────────
  group('Keyed services', () {
    test('resolves correct implementation by key', () {
      final sc = ServiceCollection()
        ..addKeyedSingletonFactory<ILogger>(
            'console', (p, k) => ConsoleLogger());
      final provider =
          sc.buildServiceProvider(ServiceProviderOptions.production);

      final logger = provider.getRequiredKeyed<ILogger>('console');
      expect(logger, isA<ConsoleLogger>());
      provider.dispose();
    });

    test('tryGetKeyed returns null for unregistered key', () {
      final provider = ServiceCollection()
          .buildServiceProvider(ServiceProviderOptions.production);
      expect(provider.tryGetKeyed<ILogger>('missing'), isNull);
      provider.dispose();
    });

    test('transient keyed returns different instances each time', () {
      final sc = ServiceCollection()
        ..addKeyedTransientFactory<ILogger>('a', (p, k) => ConsoleLogger())
        ..addKeyedTransientFactory<ILogger>('b', (p, k) => ConsoleLogger());
      final provider =
          sc.buildServiceProvider(ServiceProviderOptions.production);

      final loggerA1 = provider.getRequiredKeyed<ILogger>('a');
      final loggerA2 = provider.getRequiredKeyed<ILogger>('a');
      expect(identical(loggerA1, loggerA2), isFalse);
      provider.dispose();
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Circular dependency
  // ─────────────────────────────────────────────────────────────────────────
  group('Circular dependency detection', () {
    test('detectCycles throws CircularDependencyException', () {
      final graph = _buildCyclicGraph();
      expect(
        () => graph.detectCycles(),
        throwsA(isA<CircularDependencyException>()),
      );
    });

    test('exception chain contains at least 2 entries', () {
      final graph = _buildCyclicGraph();
      CircularDependencyException? caught;
      try {
        graph.detectCycles();
      } on CircularDependencyException catch (e) {
        caught = e;
      }
      expect(caught, isNotNull);
      expect(caught!.chain.length, greaterThanOrEqualTo(2));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Scope violation
  // ─────────────────────────────────────────────────────────────────────────
  group('Scope violation detection', () {
    test('scoped-in-singleton throws ScopeViolationException at build', () {
      expect(
        () {
          final sc = ServiceCollection()
            ..addSingleton<IDatabase, Database>()
            ..addScoped<ILogger, ConsoleLogger>();
          sc.buildServiceProvider(ServiceProviderOptions.development);
        },
        throwsA(isA<ScopeViolationException>()),
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Disposal
  // ─────────────────────────────────────────────────────────────────────────
  group('Disposal', () {
    test('provider dispose does not throw', () {
      final logger = ConsoleLogger();
      final sc = ServiceCollection()..addInstance<ILogger>(logger);
      final provider =
          sc.buildServiceProvider(ServiceProviderOptions.production);
      provider.getRequired<ILogger>();
      provider.dispose();
    });

    test('scope dispose is safe', () {
      final sc = ServiceCollection()
        ..addSingleton<ILogger, ConsoleLogger>()
        ..addScoped<IDatabase, Database>();
      final provider =
          sc.buildServiceProvider(ServiceProviderOptions.production);

      final scope = provider.createScope();
      scope.serviceProvider.getRequired<IDatabase>();
      scope.dispose();
      provider.dispose();
    });

    test('sync Disposable mixin works', () {
      final d = _TestDisposable();
      expect(d.disposed, isFalse);
      d.dispose();
      expect(d.disposed, isTrue);
    });

    test('async AsyncDisposable mixin works', () async {
      final d = _TestAsyncDisposable();
      expect(d.disposed, isFalse);
      await d.disposeAsync();
      expect(d.disposed, isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Async resolution
  // ─────────────────────────────────────────────────────────────────────────
  group('Async resolution', () {
    test('async singleton factory resolves correctly', () async {
      final sc = ServiceCollection()
        ..addSingletonAsync<ILogger>((p) async {
          await Future<void>.delayed(Duration.zero);
          return ConsoleLogger();
        });
      final provider =
          sc.buildServiceProvider(ServiceProviderOptions.production);

      final logger = await provider.getAsync<ILogger>();
      expect(logger, isA<ConsoleLogger>());

      final logger2 = await provider.getAsync<ILogger>();
      expect(identical(logger, logger2), isTrue);

      await provider.disposeAsync();
    });

    test('async keyed resolution works', () async {
      final sc = ServiceCollection()
        ..addKeyedSingletonAsync<ILogger>(
          'async-console',
          (p, k) async {
            await Future<void>.delayed(Duration.zero);
            return ConsoleLogger();
          },
        );
      final provider =
          sc.buildServiceProvider(ServiceProviderOptions.production);

      final logger = await provider.getAsyncKeyed<ILogger>('async-console');
      expect(logger, isA<ConsoleLogger>());
      await provider.disposeAsync();
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Diagnostics
  // ─────────────────────────────────────────────────────────────────────────
  group('Diagnostics', () {
    test('dumpRegistrations contains service name', () async {
      final sc = ServiceCollection()..addSingleton<ILogger, ConsoleLogger>();
      final provider =
          sc.buildServiceProvider(ServiceProviderOptions.development);

      final dump = provider.dumpRegistrations();
      expect(dump, contains('ILogger'));

      await provider.disposeAsync();
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // getAll (multi-registration)
  // ─────────────────────────────────────────────────────────────────────────
  group('getAll — multiple registrations', () {
    test('returns all registered implementations', () {
      final sc = ServiceCollection()
        ..addSingleton<ILogger, ConsoleLogger>()
        ..addSingleton<ILogger,
            ConsoleLogger>(); // register twice intentionally
      final provider =
          sc.buildServiceProvider(ServiceProviderOptions.production);

      final all = provider.getAll<ILogger>();
      expect(all, hasLength(2));
      provider.dispose();
    });

    test('returns empty list when type not registered', () {
      final provider = ServiceCollection()
          .buildServiceProvider(ServiceProviderOptions.production);
      expect(provider.getAll<ILogger>(), isEmpty);
      provider.dispose();
    });

    test('getAll from scope returns all registrations', () {
      final sc = ServiceCollection()
        ..addScoped<ILogger, ConsoleLogger>()
        ..addScoped<ILogger, ConsoleLogger>();
      final provider =
          sc.buildServiceProvider(ServiceProviderOptions.production);
      final scope = provider.createScope();
      final all = scope.serviceProvider.getAll<ILogger>();
      expect(all, hasLength(2));
      scope.dispose();
      provider.dispose();
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Scope disposal guards
  // ─────────────────────────────────────────────────────────────────────────
  group('Scope disposal guard', () {
    test('getRequired on disposed scope throws StateError', () {
      final sc = ServiceCollection()..addScoped<ILogger, ConsoleLogger>();
      final provider =
          sc.buildServiceProvider(ServiceProviderOptions.production);
      final scope = provider.createScope();
      scope.dispose();

      expect(
        () => scope.serviceProvider.getRequired<ILogger>(),
        throwsStateError,
      );
      provider.dispose();
    });

    test('tryGet on disposed scope throws StateError', () {
      final sc = ServiceCollection()..addScoped<ILogger, ConsoleLogger>();
      final provider =
          sc.buildServiceProvider(ServiceProviderOptions.production);
      final scope = provider.createScope();
      scope.dispose();

      expect(() => scope.serviceProvider.tryGet<ILogger>(), throwsStateError);
      provider.dispose();
    });

    test('createScope on disposed scope throws StateError', () {
      final sc = ServiceCollection()..addScoped<ILogger, ConsoleLogger>();
      final provider =
          sc.buildServiceProvider(ServiceProviderOptions.production);
      final scope = provider.createScope();
      scope.dispose();

      expect(() => scope.serviceProvider.createScope(), throwsStateError);
      provider.dispose();
    });

    test('double-dispose of scope is idempotent (no throw)', () {
      final sc = ServiceCollection()..addScoped<ILogger, ConsoleLogger>();
      final provider =
          sc.buildServiceProvider(ServiceProviderOptions.production);
      final scope = provider.createScope();
      scope.dispose();
      expect(() => scope.dispose(), returnsNormally);
      provider.dispose();
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // replace / addRange
  // ─────────────────────────────────────────────────────────────────────────
  group('replace and addRange', () {
    test('replace overrides existing registration', () {
      final sc = ServiceCollection()
        ..addSingleton<ILogger, ConsoleLogger>()
        ..replace(ServiceDescriptor.factoryFn(
          serviceType: ILogger,
          lifetime: ServiceLifetime.singleton,
          factory: (_) => ConsoleLogger(), // same type, verifiable by identity
        ));
      expect(sc.descriptorsFor<ILogger>(), hasLength(1));
      final provider =
          sc.buildServiceProvider(ServiceProviderOptions.production);
      expect(provider.getRequired<ILogger>(), isA<ConsoleLogger>());
      provider.dispose();
    });

    test('addRange adds all descriptors', () {
      final sc = ServiceCollection()
        ..addRange([
          ServiceDescriptor.type(
            serviceType: ILogger,
            implementationType: ConsoleLogger,
            lifetime: ServiceLifetime.singleton,
          ),
          ServiceDescriptor.type(
            serviceType: IEmailSender,
            implementationType: SmtpEmailSender,
            lifetime: ServiceLifetime.transient,
          ),
        ]);
      expect(sc.isRegistered<ILogger>(), isTrue);
      expect(sc.isRegistered<IEmailSender>(), isTrue);
      sc.buildServiceProvider().dispose();
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // tryAdd variants
  // ─────────────────────────────────────────────────────────────────────────
  group('tryAdd convenience methods', () {
    test('tryAddSingleton does not overwrite', () {
      final sc = ServiceCollection()
        ..addInstance<ILogger>(ConsoleLogger())
        ..tryAddSingleton<ILogger, ConsoleLogger>();
      // Still 1 descriptor (original instance-based one), not 2.
      expect(sc.descriptorsFor<ILogger>(), hasLength(1));
      sc.buildServiceProvider().dispose();
    });

    test('tryAddScoped does not overwrite', () {
      final sc = ServiceCollection()
        ..addScoped<IDatabase, Database>()
        ..tryAddScoped<IDatabase, Database>();
      expect(sc.descriptorsFor<IDatabase>(), hasLength(1));
    });

    test('tryAddTransient does not overwrite', () {
      final sc = ServiceCollection()
        ..addTransient<IEmailSender, SmtpEmailSender>()
        ..tryAddTransient<IEmailSender, SmtpEmailSender>();
      expect(sc.descriptorsFor<IEmailSender>(), hasLength(1));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // isRegistered
  // ─────────────────────────────────────────────────────────────────────────
  group('isRegistered', () {
    test('returns true for registered type on root provider', () {
      final sc = ServiceCollection()..addSingleton<ILogger, ConsoleLogger>();
      final provider =
          sc.buildServiceProvider(ServiceProviderOptions.production);
      expect(provider.isRegistered<ILogger>(), isTrue);
      expect(provider.isRegistered<IDatabase>(), isFalse);
      provider.dispose();
    });

    test('tryGet acts as isRegistered for scoped provider', () {
      final sc = ServiceCollection()..addScoped<ILogger, ConsoleLogger>();
      final provider =
          sc.buildServiceProvider(ServiceProviderOptions.production);
      final scope = provider.createScope();
      // tryGet returns non-null iff registered.
      expect(scope.serviceProvider.tryGet<ILogger>(), isNotNull);
      expect(scope.serviceProvider.tryGet<IDatabase>(), isNull);
      scope.dispose();
      provider.dispose();
    });

    test('isKeyedRegistered on root provider', () {
      final sc = ServiceCollection()
        ..addKeyedSingleton<ILogger, ConsoleLogger>('console');
      final provider =
          sc.buildServiceProvider(ServiceProviderOptions.production);
      expect(provider.isKeyedRegistered<ILogger>('console'), isTrue);
      expect(provider.isKeyedRegistered<ILogger>('missing'), isFalse);
      provider.dispose();
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // tryGetAsync
  // ─────────────────────────────────────────────────────────────────────────
  group('tryGetAsync', () {
    test('returns null when type not registered', () async {
      final provider = ServiceCollection()
          .buildServiceProvider(ServiceProviderOptions.production);
      final result = await provider.tryGetAsync<ILogger>();
      expect(result, isNull);
      provider.dispose();
    });

    test('returns instance when registered', () async {
      final sc = ServiceCollection()..addSingleton<ILogger, ConsoleLogger>();
      final provider =
          sc.buildServiceProvider(ServiceProviderOptions.production);
      final logger = await provider.tryGetAsync<ILogger>();
      expect(logger, isA<ConsoleLogger>());
      provider.dispose();
    });

    test('returns null from scope when type not registered', () async {
      final provider = ServiceCollection()
          .buildServiceProvider(ServiceProviderOptions.production);
      final scope = provider.createScope();
      final result = await scope.serviceProvider.tryGetAsync<ILogger>();
      expect(result, isNull);
      scope.dispose();
      provider.dispose();
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Factory resolved from scope (tests ServiceProviderBase cast fix)
  // ─────────────────────────────────────────────────────────────────────────
  group('Factory from scope', () {
    test('scoped factory receives the scoped provider (not root)', () {
      ServiceProviderBase? captured;
      final sc = ServiceCollection()
        ..addScopedFactory<ILogger>((p) {
          captured = p;
          return ConsoleLogger();
        });
      final provider =
          sc.buildServiceProvider(ServiceProviderOptions.production);
      final scope = provider.createScope();
      scope.serviceProvider.getRequired<ILogger>();

      // The factory should receive the scoped provider, NOT the root provider.
      expect(captured, isNotNull);
      expect(captured, isNot(same(provider)));
      scope.dispose();
      provider.dispose();
    });

    test('transient factory receives the provider (no cast exception)', () {
      var callCount = 0;
      final sc = ServiceCollection()
        ..addTransientFactory<ILogger>((p) {
          callCount++;
          return ConsoleLogger();
        });
      final provider =
          sc.buildServiceProvider(ServiceProviderOptions.production);

      provider.getRequired<ILogger>();
      provider.getRequired<ILogger>(); // transient: new instance each time
      expect(callCount, equals(2));
      provider.dispose();
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Keyed async (new APIs)
  // ─────────────────────────────────────────────────────────────────────────
  group('Keyed scoped/transient async', () {
    test('addKeyedScopedAsync resolves correctly', () async {
      final sc = ServiceCollection()
        ..addKeyedScopedAsync<ILogger>('async-scoped', (p, k) async {
          await Future<void>.delayed(Duration.zero);
          return ConsoleLogger();
        });
      final provider =
          sc.buildServiceProvider(ServiceProviderOptions.production);
      final scope = provider.createScope();
      final logger =
          await scope.serviceProvider.getAsyncKeyed<ILogger>('async-scoped');
      expect(logger, isA<ConsoleLogger>());
      scope.dispose();
      await provider.disposeAsync();
    });

    test('addKeyedTransientAsync resolves correctly', () async {
      final sc = ServiceCollection()
        ..addKeyedTransientAsync<ILogger>('async-transient', (p, k) async {
          await Future<void>.delayed(Duration.zero);
          return ConsoleLogger();
        });
      final provider =
          sc.buildServiceProvider(ServiceProviderOptions.production);
      final a = await provider.getAsyncKeyed<ILogger>('async-transient');
      final b = await provider.getAsyncKeyed<ILogger>('async-transient');
      expect(identical(a, b), isFalse); // transient — different instances
      await provider.disposeAsync();
    });
  });
}
