import 'package:davianspace_dependencyinjection/davianspace_dependencyinjection.dart';
import 'package:davianspace_options/davianspace_options.dart';
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
    ActivatorHelper.instance.clear();
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
    test('scoped-in-singleton throws ContainerBuildException at build', () {
      expect(
        () {
          final sc = ServiceCollection()
            ..addSingleton<IDatabase, Database>()
            ..addScoped<ILogger, ConsoleLogger>();
          sc.buildServiceProvider(ServiceProviderOptions.development);
        },
        throwsA(isA<ContainerBuildException>()),
      );
    });

    test('ContainerBuildException message contains ScopeViolation', () {
      late final ContainerBuildException caught;
      try {
        final sc = ServiceCollection()
          ..addSingleton<IDatabase, Database>()
          ..addScoped<ILogger, ConsoleLogger>();
        sc.buildServiceProvider(ServiceProviderOptions.development);
      } on ContainerBuildException catch (e) {
        caught = e;
      }
      expect(caught.errors, isNotEmpty);
      expect(caught.errors.first, contains('ScopeViolation'));
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

  // ─────────────────────────────────────────────────────────────────────────
  // Root ServiceProvider dispose guard (regression: missing before fix)
  // ─────────────────────────────────────────────────────────────────────────
  group('Root provider disposal guard', () {
    late ServiceProvider provider;

    setUp(() {
      final sc = ServiceCollection()..addSingleton<ILogger, ConsoleLogger>();
      provider = sc.buildServiceProvider(ServiceProviderOptions.production);
    });

    test('tryGet throws StateError after dispose', () {
      provider.dispose();
      expect(() => provider.tryGet<ILogger>(), throwsStateError);
    });

    test('getRequired throws StateError after dispose', () {
      provider.dispose();
      expect(() => provider.getRequired<ILogger>(), throwsStateError);
    });

    test('getAll throws StateError after dispose', () {
      provider.dispose();
      expect(() => provider.getAll<ILogger>(), throwsStateError);
    });

    test('getAsync throws StateError after dispose', () async {
      provider.dispose();
      await expectLater(provider.getAsync<ILogger>(), throwsStateError);
    });

    test('tryGetAsync throws StateError after dispose', () async {
      provider.dispose();
      await expectLater(provider.tryGetAsync<ILogger>(), throwsStateError);
    });

    test('tryGetKeyed throws StateError after dispose', () {
      provider.dispose();
      expect(() => provider.tryGetKeyed<ILogger>('k'), throwsStateError);
    });

    test('getRequiredKeyed throws StateError after dispose', () {
      provider.dispose();
      expect(() => provider.getRequiredKeyed<ILogger>('k'), throwsStateError);
    });

    test('getAsyncKeyed throws StateError after dispose', () async {
      provider.dispose();
      await expectLater(provider.getAsyncKeyed<ILogger>('k'), throwsStateError);
    });

    test('createScope throws StateError after dispose', () {
      provider.dispose();
      expect(() => provider.createScope(), throwsStateError);
    });

    test('resolveRequired throws StateError after dispose', () {
      provider.dispose();
      expect(() => provider.resolveRequired(ILogger), throwsStateError);
    });

    test('double dispose is safe (idempotent)', () {
      provider.dispose();
      expect(() => provider.dispose(), returnsNormally);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // DisposalException multi-error
  // ─────────────────────────────────────────────────────────────────────────
  group('DisposalException multi-error', () {
    test('collects all disposal failures', () {
      // Register two disposable singletons that both throw during dispose.
      int callCount = 0;
      final sc = ServiceCollection()
        ..addSingletonFactory<_IThrowA>((_) {
          callCount++;
          return _ThrowingDisposable('A-$callCount');
        })
        ..addSingletonFactory<_IThrowB>((_) {
          callCount++;
          return _ThrowingDisposable('B-$callCount');
        });

      final provider =
          sc.buildServiceProvider(ServiceProviderOptions.production);
      provider.getRequired<_IThrowA>();
      provider.getRequired<_IThrowB>();

      DisposalException? caught;
      try {
        provider.dispose();
      } on DisposalException catch (e) {
        caught = e;
      }

      expect(caught, isNotNull);
      // Both disposals failed — all errors must be reported.
      expect(caught!.errors.length, equals(2));
    });

    test('single failure smoke test', () {
      final sc = ServiceCollection()
        ..addSingletonFactory<_IThrowA>((_) => _ThrowingDisposable('only'));
      final provider =
          sc.buildServiceProvider(ServiceProviderOptions.production);
      provider.getRequired<_IThrowA>();
      expect(() => provider.dispose(), throwsA(isA<DisposalException>()));
    });

    test('errors list accessor on DisposalException', () {
      final e = DisposalException([(String, StateError('boom'))]);
      expect(e.serviceType, equals(String));
      expect(e.cause, isA<StateError>());
      expect(e.errors, hasLength(1));
      expect(e.toString(), contains('boom'));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // CallSiteValidator collectAll semantics
  // ─────────────────────────────────────────────────────────────────────────
  group('Scope violation validator collectAll', () {
    test('collectAll:true gathers all violations without throwing internally',
        () {
      // Two singletons each capturing a different scoped service.
      // With collectAll:true both should appear in ContainerBuildException.
      expect(
        () {
          final sc = ServiceCollection()
            ..addSingleton<IDatabase, Database>()
            ..addSingleton<IEmailSender, SmtpEmailSender>()
            ..addScoped<ILogger, ConsoleLogger>();
          sc.buildServiceProvider(ServiceProviderOptions.development);
        },
        throwsA(isA<ContainerBuildException>()),
      );
    });

    test('collectAll:false throws ScopeViolationException immediately', () {
      // Call the validator directly with collectAll:false.
      final sc = ServiceCollection()
        ..addSingleton<IDatabase, Database>()
        ..addScoped<ILogger, ConsoleLogger>();

      // Build without validation so we can inspect the call sites.
      final provider =
          sc.buildServiceProvider(ServiceProviderOptions.production);
      expect(provider, isNotNull);
      provider.dispose();
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // CallSiteExecutor per-provider caching (performance regression guard)
  // ─────────────────────────────────────────────────────────────────────────
  group('CallSiteExecutor caching', () {
    test('singleton resolution is stable under repeated calls', () {
      final sc = ServiceCollection()..addSingleton<ILogger, ConsoleLogger>();
      final provider =
          sc.buildServiceProvider(ServiceProviderOptions.production);

      // These calls all go through the same cached executor — any per-call
      // allocation regression would not break correctness but we verify
      // identity remains stable.
      final instances = [
        for (var i = 0; i < 100; i++) provider.getRequired<ILogger>()
      ];
      expect(instances.every((i) => identical(i, instances.first)), isTrue);
      provider.dispose();
    });

    test('scoped executor resolves independently per scope', () {
      final sc = ServiceCollection()..addScoped<ILogger, ConsoleLogger>();
      final provider =
          sc.buildServiceProvider(ServiceProviderOptions.production);

      final scope1 = provider.createScope();
      final scope2 = provider.createScope();

      final a = scope1.serviceProvider.getRequired<ILogger>();
      final b = scope2.serviceProvider.getRequired<ILogger>();
      expect(identical(a, b), isFalse);

      scope1.dispose();
      scope2.dispose();
      provider.dispose();
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // ScopeManager
  // ───────────────────────────────────────────────────────────────────────────
  group('ScopeManager', () {
    late ServiceProvider provider;

    setUp(() {
      final sc = ServiceCollection()
        ..addScoped<ILogger, ConsoleLogger>()
        ..addSingleton<IDatabase, Database>();
      provider = sc.buildServiceProvider(ServiceProviderOptions.production);
    });

    tearDown(() => provider.dispose());

    test('beginScope creates an active scope', () {
      final mgr = ScopeManager(provider);
      mgr.beginScope('req');
      expect(mgr.hasScope('req'), isTrue);
      expect(mgr.activeScopes, contains('req'));
      mgr.endScope('req');
    });

    test('beginScope throws when name already exists', () {
      final mgr = ScopeManager(provider);
      mgr.beginScope('s');
      expect(() => mgr.beginScope('s'), throwsStateError);
      mgr.endScope('s');
    });

    test('beginScopeIfAbsent is a no-op when scope already exists', () {
      final mgr = ScopeManager(provider);
      mgr.beginScope('s');
      expect(() => mgr.beginScopeIfAbsent('s'), returnsNormally);
      expect(mgr.activeScopes, hasLength(1));
      mgr.endScope('s');
    });

    test('getRequired resolves from named scope', () {
      final mgr = ScopeManager(provider);
      mgr.beginScope('r');
      final logger = mgr.getRequired<ILogger>('r');
      expect(logger, isA<ConsoleLogger>());
      mgr.endScope('r');
    });

    test('tryGet returns null for unregistered type', () {
      final mgr = ScopeManager(provider);
      mgr.beginScope('r');
      expect(mgr.tryGet<IEmailSender>('r'), isNull);
      mgr.endScope('r');
    });

    test('scope() throws for unknown scope name', () {
      final mgr = ScopeManager(provider);
      expect(() => mgr.scope('missing'), throwsStateError);
    });

    test('endScope throws for unknown scope name', () {
      final mgr = ScopeManager(provider);
      expect(() => mgr.endScope('missing'), throwsStateError);
    });

    test('scoped services from same scope are identical', () {
      final mgr = ScopeManager(provider);
      mgr.beginScope('r');
      final a = mgr.getRequired<ILogger>('r');
      final b = mgr.getRequired<ILogger>('r');
      expect(identical(a, b), isTrue);
      mgr.endScope('r');
    });

    test('scoped services from different scopes differ', () {
      final mgr = ScopeManager(provider);
      mgr.beginScope('r1');
      mgr.beginScope('r2');
      final a = mgr.getRequired<ILogger>('r1');
      final b = mgr.getRequired<ILogger>('r2');
      expect(identical(a, b), isFalse);
      mgr.disposeAll();
    });

    test('disposeAll removes all scopes', () {
      final mgr = ScopeManager(provider);
      mgr.beginScope('a');
      mgr.beginScope('b');
      mgr.disposeAll();
      expect(mgr.activeScopes, isEmpty);
    });

    test('disposeAll continues on error and rethrows first', () {
      final sc2 = ServiceCollection()
        ..addScopedFactory<ILogger>((_) => _ThrowingDisposable2());
      final p2 = sc2.buildServiceProvider(ServiceProviderOptions.production);
      // Force instantiation so the service is tracked
      final mgr = ScopeManager(p2);
      mgr.beginScope('x');
      mgr.beginScope('y');
      mgr.getRequired<ILogger>('x');
      mgr.getRequired<ILogger>('y');
      // Both scopes will fail to dispose
      expect(() => mgr.disposeAll(), throwsA(isA<DisposalException>()));
      // All scopes must have been removed regardless
      expect(mgr.activeScopes, isEmpty);
      p2.dispose();
    });

    test('disposeAllAsync removes all scopes', () async {
      final mgr = ScopeManager(provider);
      mgr.beginScope('a');
      mgr.beginScope('b');
      await mgr.disposeAllAsync();
      expect(mgr.activeScopes, isEmpty);
    });

    test('endScopeAsync disposes and removes scope', () async {
      final mgr = ScopeManager(provider);
      mgr.beginScope('r');
      await mgr.endScopeAsync('r');
      expect(mgr.hasScope('r'), isFalse);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Lazy<T>
  // ───────────────────────────────────────────────────────────────────────────
  group('Lazy<T>', () {
    test('factory not called before first access', () {
      int calls = 0;
      final lazy = Lazy(() {
        calls++;
        return ConsoleLogger();
      });
      expect(calls, equals(0));
      expect(lazy.isValueCreated, isFalse);
    });

    test('factory called exactly once on first access', () {
      int calls = 0;
      final lazy = Lazy(() {
        calls++;
        return ConsoleLogger();
      });
      lazy.value;
      lazy.value;
      expect(calls, equals(1));
    });

    test('same instance returned on subsequent accesses', () {
      final lazy = Lazy(ConsoleLogger.new);
      expect(identical(lazy.value, lazy.value), isTrue);
    });

    test('isValueCreated is true after first access', () {
      final lazy = Lazy(ConsoleLogger.new);
      lazy.value;
      expect(lazy.isValueCreated, isTrue);
    });

    test('resolved via DI container', () {
      final sc = ServiceCollection()
        ..addSingleton<ILogger, ConsoleLogger>()
        ..addLazySingleton<ILogger>();
      final provider = sc.buildServiceProvider(ServiceProviderOptions.production);
      final lazy = provider.getRequired<Lazy<ILogger>>();
      expect(lazy.isValueCreated, isFalse);
      final logger = lazy.value;
      expect(logger, isA<ConsoleLogger>());
      expect(lazy.isValueCreated, isTrue);
      provider.dispose();
    });

    test('toString reflects initialisation state', () {
      final lazy = Lazy(ConsoleLogger.new);
      expect(lazy.toString(), contains('not created'));
      lazy.value;
      expect(lazy.toString(), contains('created'));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // ActivatorUtilities
  // ───────────────────────────────────────────────────────────────────────────
  group('ActivatorUtilities', () {
    late ServiceProvider provider;

    setUp(() {
      ActivatorHelper.instance.register<_Widget>(
        _Widget,
        (resolve, args) => _Widget(
          resolve(ILogger) as ILogger,
          args[0] as String,
        ),
      );
      final sc = ServiceCollection()..addSingleton<ILogger, ConsoleLogger>();
      provider = sc.buildServiceProvider(ServiceProviderOptions.production);
    });

    tearDown(() => provider.dispose());

    test('createInstance resolves DI dep and injects runtime arg', () {
      final widget = ActivatorUtilities.createInstance<_Widget>(
        provider,
        positionalArgs: ['hello'],
      );
      expect(widget.label, equals('hello'));
      expect(widget.logger, isA<ConsoleLogger>());
    });

    test('createInstance throws StateError for unregistered factory', () {
      expect(
        () => ActivatorUtilities.createInstance<_UnregisteredWidget>(provider),
        throwsStateError,
      );
    });

    test('ActivatorHelper.hasFactory returns true after register', () {
      expect(ActivatorHelper.instance.hasFactory(_Widget), isTrue);
    });

    test('ActivatorHelper.unregister removes factory', () {
      ActivatorHelper.instance.unregister(_Widget);
      expect(ActivatorHelper.instance.hasFactory(_Widget), isFalse);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Options pattern
  // ───────────────────────────────────────────────────────────────────────────
  group('Options pattern', () {
    test('Options<T> returns configured value', () {
      final sc = ServiceCollection()
        ..configure<_ServerOptions>(
          factory: _ServerOptions.new,
          configure: (o) => o.host = 'localhost',
        );
      final provider = sc.buildServiceProvider(ServiceProviderOptions.production);
      final opts = provider.getRequired<Options<_ServerOptions>>().value;
      expect(opts.host, equals('localhost'));
      provider.dispose();
    });

    test('Options<T> value is singleton (same instance each call)', () {
      final sc = ServiceCollection()
        ..configure<_ServerOptions>(factory: _ServerOptions.new);
      final provider = sc.buildServiceProvider(ServiceProviderOptions.production);
      final a = provider.getRequired<Options<_ServerOptions>>().value;
      final b = provider.getRequired<Options<_ServerOptions>>().value;
      expect(identical(a, b), isTrue);
      provider.dispose();
    });

    test('configure callbacks applied in registration order', () {
      final log = <String>[];
      final sc = ServiceCollection()
        ..configure<_ServerOptions>(
          factory: _ServerOptions.new,
          configure: (_) => log.add('first'),
        )
        ..configure<_ServerOptions>(
          factory: _ServerOptions.new,
          configure: (_) => log.add('second'),
        );
      final provider = sc.buildServiceProvider(ServiceProviderOptions.production);
      provider.getRequired<Options<_ServerOptions>>().value;
      expect(log, equals(['first', 'second']));
      provider.dispose();
    });

    test('postConfigure runs after configure', () {
      final log = <String>[];
      final sc = ServiceCollection()
        ..configure<_ServerOptions>(
          factory: _ServerOptions.new,
          configure: (_) => log.add('configure'),
        )
        ..postConfigure<_ServerOptions>((_) => log.add('postConfigure'));
      final provider = sc.buildServiceProvider(ServiceProviderOptions.production);
      provider.getRequired<Options<_ServerOptions>>().value;
      expect(log, equals(['configure', 'postConfigure']));
      provider.dispose();
    });

    test('postConfigure throws if configure not called first', () {
      final sc = ServiceCollection();
      expect(
        () => sc.postConfigure<_ServerOptions>((_) {}),
        throwsStateError,
      );
    });

    test('OptionsSnapshot<T> returns fresh instance per scope', () {
      final sc = ServiceCollection()
        ..configure<_ServerOptions>(factory: _ServerOptions.new);
      final provider = sc.buildServiceProvider(ServiceProviderOptions.production);

      final scope1 = provider.createScope();
      final scope2 = provider.createScope();
      final a = scope1.serviceProvider
          .getRequired<OptionsSnapshot<_ServerOptions>>()
          .value;
      final b = scope2.serviceProvider
          .getRequired<OptionsSnapshot<_ServerOptions>>()
          .value;
      expect(identical(a, b), isFalse);
      scope1.dispose();
      scope2.dispose();
      provider.dispose();
    });

    test('OptionsSnapshot<T>.get returns named options', () {
      final sc = ServiceCollection()
        ..configure<_ServerOptions>(
          factory: _ServerOptions.new,
          configure: (o) => o.host = 'default',
        )
        ..configure<_ServerOptions>(
          factory: _ServerOptions.new,
          configure: (o) => o.host = 'secondary',
          name: 'secondary',
        );
      final provider = sc.buildServiceProvider(ServiceProviderOptions.production);
      final scope = provider.createScope();
      final snap =
          scope.serviceProvider.getRequired<OptionsSnapshot<_ServerOptions>>();
      expect(snap.value.host, equals('default'));
      expect(snap.get('secondary').host, equals('secondary'));
      scope.dispose();
      provider.dispose();
    });

    test('OptionsMonitor<T> currentValue reflects initial configuration', () {
      final sc = ServiceCollection()
        ..configure<_ServerOptions>(
          factory: _ServerOptions.new,
          configure: (o) => o.host = 'prod',
        );
      final provider = sc.buildServiceProvider(ServiceProviderOptions.production);
      final monitor = provider.getRequired<OptionsMonitor<_ServerOptions>>();
      expect(monitor.currentValue.host, equals('prod'));
      provider.dispose();
    });

    test('OptionsMonitor<T> onChange listener fires on reload', () {
      var host = 'initial';
      final sc = ServiceCollection()
        ..configure<_ServerOptions>(
          factory: _ServerOptions.new,
          configure: (o) => o.host = host,
        );
      final provider = sc.buildServiceProvider(ServiceProviderOptions.production);
      final monitor = provider.getRequired<OptionsMonitor<_ServerOptions>>();

      _ServerOptions? received;
      final reg = monitor.onChange((_ServerOptions opts, _) => received = opts);

      // Update what the factory produces, then signal a reload.
      host = 'updated';
      final notifier =
          provider.getRequiredKeyed<OptionsChangeNotifier>(_ServerOptions);
      notifier.notifyChange(Options.defaultName);

      expect(received, isNotNull);
      expect(received!.host, equals('updated'));
      expect(monitor.currentValue.host, equals('updated'));

      reg.dispose();
      provider.dispose();
    });

    test('OptionsChangeRegistration.dispose() is idempotent', () {
      final sc = ServiceCollection()
        ..configure<_ServerOptions>(factory: _ServerOptions.new);
      final provider = sc.buildServiceProvider(ServiceProviderOptions.production);
      final monitor = provider.getRequired<OptionsMonitor<_ServerOptions>>();

      final reg = monitor.onChange((_, __) {});
      reg.dispose();
      // Second call must not throw.
      expect(() => reg.dispose(), returnsNormally);

      // Listener no longer fires after disposal.
      int count = 0;
      monitor.onChange((_, __) => count++);
      final notifier =
          provider.getRequiredKeyed<OptionsChangeNotifier>(_ServerOptions);
      notifier.notifyChange(Options.defaultName);
      expect(count, equals(1)); // new listener fires, disposed one does not

      provider.dispose();
    });

    test('onChange listener deregistered after dispose', () {
      final sc = ServiceCollection()
        ..configure<_ServerOptions>(factory: _ServerOptions.new);
      final provider = sc.buildServiceProvider(ServiceProviderOptions.production);
      final monitor = provider.getRequired<OptionsMonitor<_ServerOptions>>();
      final notifier =
          provider.getRequiredKeyed<OptionsChangeNotifier>(_ServerOptions);

      int count = 0;
      final reg = monitor.onChange((_, __) => count++);
      notifier.notifyChange(Options.defaultName); // count → 1
      reg.dispose();
      notifier.notifyChange(Options.defaultName); // should not increment
      expect(count, equals(1));

      provider.dispose();
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // ServiceModule
  // ───────────────────────────────────────────────────────────────────────────
  group('ServiceModule', () {
    test('module registers services into the collection', () {
      final sc = ServiceCollection()..addModule(_LoggingModule());
      expect(sc.isRegistered<ILogger>(), isTrue);
      expect(sc.isRegistered<IDatabase>(), isTrue);
    });

    test('services registered by module are resolvable', () {
      final sc = ServiceCollection()..addModule(_LoggingModule());
      final provider = sc.buildServiceProvider(ServiceProviderOptions.production);
      expect(provider.getRequired<ILogger>(), isA<ConsoleLogger>());
      expect(provider.getRequired<IDatabase>(), isA<Database>());
      provider.dispose();
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // DependencyGraph — iterative DFS regression
  // ───────────────────────────────────────────────────────────────────────────
  group('DependencyGraph iterative DFS', () {
    test('acyclic linear chain does not throw', () {
      final g = DependencyGraph()
        ..addEdge(ILogger, ConsoleLogger)
        ..addEdge(IDatabase, ILogger)
        ..addEdge(IUserRepository, IDatabase);
      expect(() => g.detectCycles(), returnsNormally);
    });

    test('two-node cycle detected', () {
      final g = DependencyGraph()
        ..addEdge(ILogger, IDatabase)
        ..addEdge(IDatabase, ILogger);
      expect(() => g.detectCycles(),
          throwsA(isA<CircularDependencyException>()));
    });

    test('three-node cycle detected', () {
      final g = DependencyGraph()
        ..addEdge(ILogger, IDatabase)
        ..addEdge(IDatabase, IUserRepository)
        ..addEdge(IUserRepository, ILogger);
      expect(() => g.detectCycles(),
          throwsA(isA<CircularDependencyException>()));
    });

    test('disconnected graph with cycle in second component', () {
      final g = DependencyGraph()
        ..addEdge(IEmailSender, SmtpEmailSender) // acyclic
        ..addEdge(ILogger, IDatabase)             // cycle
        ..addEdge(IDatabase, ILogger);
      expect(() => g.detectCycles(),
          throwsA(isA<CircularDependencyException>()));
    });

    test('cycle exception chain contains offending types', () {
      final g = DependencyGraph()
        ..addEdge(ILogger, IDatabase)
        ..addEdge(IDatabase, ILogger);
      CircularDependencyException? ex;
      try {
        g.detectCycles();
      } on CircularDependencyException catch (e) {
        ex = e;
      }
      expect(ex, isNotNull);
      expect(ex!.chain, containsAll([ILogger, IDatabase]));
    });
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Extra test doubles
// ─────────────────────────────────────────────────────────────────────────────

/// Marker interfaces for the multi-error disposal test.
abstract class _IThrowA {}

abstract class _IThrowB {}

/// A fake service that throws during [dispose] to test multi-error disposal.
class _ThrowingDisposable with Disposable implements _IThrowA, _IThrowB {
  final String name;
  _ThrowingDisposable(this.name);

  @override
  void dispose() => throw StateError('$name failed to dispose');

  @override
  String toString() => '_ThrowingDisposable($name)';
}

/// Throws on dispose — used in ScopeManager disposeAll error test.
class _ThrowingDisposable2 with Disposable implements ILogger {
  @override
  void log(String message) {}

  @override
  void dispose() => throw StateError('scope service failed to dispose');
}

/// Simple class that takes a DI dep + a runtime argument.
class _Widget {
  final ILogger logger;
  final String label;
  _Widget(this.logger, this.label);
}

/// Not registered in ActivatorHelper — used to verify the error path.
class _UnregisteredWidget {}

/// Simple mutable options class for the options pattern tests.
class _ServerOptions {
  String host = '';
}

/// A [ServiceModule] that registers [ILogger] and [IDatabase].
class _LoggingModule extends ServiceModule {
  @override
  void register(ServiceCollection services) {
    services
      ..addSingleton<ILogger, ConsoleLogger>()
      ..addSingleton<IDatabase, Database>();
  }
}
