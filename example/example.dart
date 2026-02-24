// ignore_for_file: avoid_print

import 'package:davianspace_dependencyinjection/davianspace_dependencyinjection.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Domain abstractions
// ─────────────────────────────────────────────────────────────────────────────

abstract class ILogger {
  void log(String message);
}

abstract class IDatabase {
  Future<String> query(String sql);
}

abstract class IUserRepository {
  Future<String> findById(int id);
}

abstract class ICacheService {
  String? get(String key);
  void set(String key, String value);
}

// ─────────────────────────────────────────────────────────────────────────────
// Implementations
// ─────────────────────────────────────────────────────────────────────────────

class ConsoleLogger implements ILogger {
  @override
  void log(String message) => print('[LOG] $message');
}

class PostgresDatabase implements IDatabase {
  final ILogger _logger;
  PostgresDatabase(this._logger);

  @override
  Future<String> query(String sql) async {
    _logger.log('Query: $sql');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    return 'pg_result[$sql]';
  }
}

class UserRepository implements IUserRepository {
  final IDatabase _db;
  UserRepository(this._db);

  @override
  Future<String> findById(int id) =>
      _db.query('SELECT * FROM users WHERE id = $id');
}

class MemoryCacheService implements ICacheService {
  final _store = <String, String>{};

  @override
  String? get(String key) => _store[key];

  @override
  void set(String key, String value) => _store[key] = value;
}

class RedisCacheService implements ICacheService {
  final _store = <String, String>{};

  @override
  String? get(String key) => _store[key];

  @override
  void set(String key, String value) => _store[key] = value;
}

// ─────────────────────────────────────────────────────────────────────────────
// Register constructor factories with ReflectionHelper
// (required because Dart has no runtime reflection in AOT)
// ─────────────────────────────────────────────────────────────────────────────
void _registerFactories() {
  ReflectionHelper.instance
    ..register(ConsoleLogger, (_) => ConsoleLogger())
    ..register(
      PostgresDatabase,
      (resolve) => PostgresDatabase(resolve(ILogger) as ILogger),
    )
    ..register(
      UserRepository,
      (resolve) => UserRepository(resolve(IDatabase) as IDatabase),
    )
    ..register(MemoryCacheService, (_) => MemoryCacheService())
    ..register(RedisCacheService, (_) => RedisCacheService());
}

// ─────────────────────────────────────────────────────────────────────────────
// Main
// ─────────────────────────────────────────────────────────────────────────────
Future<void> main() async {
  _registerFactories();

  // ── 1. Build the container ────────────────────────────────────────────────
  final sc = ServiceCollection()
    // Singleton: one ConsoleLogger for the whole app.
    ..addSingleton<ILogger, ConsoleLogger>()
    // Singleton: one PostgresDatabase — async factory.
    ..addSingletonAsync<IDatabase>((p) async {
      final logger = p.getRequired<ILogger>();
      logger.log('Initialising database connection…');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return PostgresDatabase(logger);
    })
    // Scoped: fresh UserRepository per HTTP request / scope.
    ..addScoped<IUserRepository, UserRepository>()
    // Keyed Singleton: two named cache implementations.
    ..addKeyedSingletonFactory<ICacheService>(
      'memory',
      (p, k) => MemoryCacheService(),
    )
    ..addKeyedSingletonFactory<ICacheService>(
      'redis',
      (p, k) => RedisCacheService(),
    );

  final provider = sc.buildServiceProvider(
    const ServiceProviderOptions(
      validateOnBuild: true,
      validateScopes: true,
      enableDiagnostics: true,
    ),
  );

  // ── 2. Subscribe to diagnostics ───────────────────────────────────────────
  // (Must subscribe before resolving when enableDiagnostics is true.)
  print('\n=== davianspace_dependencyinjection example ===\n');
  print(provider.dumpRegistrations());

  // ── 3. Async singleton resolution ────────────────────────────────────────
  final db = await provider.getAsync<IDatabase>();
  final result = await db.query('SELECT 1');
  print('DB result: $result');

  // ── 4. Scoped resolution ─────────────────────────────────────────────────
  final scope1 = provider.createScope();
  final repo1 = scope1.serviceProvider.getRequired<IUserRepository>();
  print(await repo1.findById(1));

  final scope2 = provider.createScope();
  final repo2 = scope2.serviceProvider.getRequired<IUserRepository>();
  print(await repo2.findById(2));

  // repo1 and repo2 are different instances.
  assert(!identical(repo1, repo2));
  print('repo1 == repo2? ${identical(repo1, repo2)}'); // false

  scope1.dispose();
  scope2.dispose();

  // ── 5. Keyed services ────────────────────────────────────────────────────
  final memCache = provider.getRequiredKeyed<ICacheService>('memory');
  final redisCache = provider.getRequiredKeyed<ICacheService>('redis');

  memCache.set('user:1', 'Alice');
  redisCache.set('session:abc', 'active');

  print('MemCache user:1 → ${memCache.get('user:1')}');
  print('RedisCache session:abc → ${redisCache.get('session:abc')}');

  // ── 6. isRegistered / tryGetAsync ────────────────────────────────────────
  print('\nisRegistered<ILogger>: ${provider.isRegistered<ILogger>()}');
  print('isRegistered<String>: ${provider.isRegistered<String>()}');

  final maybeLogger = await provider.tryGetAsync<ILogger>();
  print('tryGetAsync<ILogger>: ${maybeLogger != null ? 'resolved' : 'null'}');

  final nothing = await provider.tryGetAsync<String>();
  print('tryGetAsync<String> (unregistered): $nothing');

  // ── 7. getAll — multi-registration ───────────────────────────────────────
  // Build a fresh container with multiple ILogger implementations.
  final multiSc = ServiceCollection()
    ..addSingleton<ILogger, ConsoleLogger>()
    ..addSingleton<ILogger, ConsoleLogger>(); // register twice for demo

  final multiProvider = multiSc.buildServiceProvider();
  final allLoggers = multiProvider.getAll<ILogger>();
  print('\ngetAll<ILogger> count: ${allLoggers.length}'); // 2
  await multiProvider.disposeAsync();

  // ── 8. replace ────────────────────────────────────────────────────────────
  final replaceSc = ServiceCollection()
    ..addInstance<ILogger>(ConsoleLogger())
    ..replace(ServiceDescriptor.factoryFn(
      serviceType: ILogger,
      lifetime: ServiceLifetime.singleton,
      factory: (_) => ConsoleLogger(), // overrides the instance above
    ));
  print('\nAfter replace, descriptor count: '
      '${replaceSc.descriptorsFor<ILogger>().length}'); // 1

  // ── 9. Dispose the root provider ─────────────────────────────────────────
  await provider.disposeAsync();
  print('\nProvider disposed. Goodbye!');
}
