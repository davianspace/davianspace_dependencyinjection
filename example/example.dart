// ignore_for_file: avoid_print

import 'package:davianspace_configuration/davianspace_configuration.dart';
import 'package:davianspace_dependencyinjection/davianspace_dependencyinjection.dart';
import 'package:davianspace_options/davianspace_options.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Options & Configuration models (for examples 9 & 10)
// ─────────────────────────────────────────────────────────────────────────────

class ServerOptions {
  String host = 'localhost';
  int port = 8080;
  bool useSsl = false;
}

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

  // Scoped services are isolated per scope — different instances across scopes.
  print(
      'repo1 is repo2? ${identical(repo1, repo2)}'); // false — scoped isolation confirmed

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

  // ── 7. getAll — consume all registered implementations of a service ────────
  // Register two named cache implementations under the same abstract type,
  // then resolve all of them in one call — useful for broadcast patterns
  // (e.g. fan-out notifications, composite health checks).
  final multiSc = ServiceCollection()
    ..addSingleton<ICacheService, MemoryCacheService>()
    ..addSingleton<ICacheService, RedisCacheService>();

  final multiProvider = multiSc.buildServiceProvider();
  final allCaches = multiProvider.getAll<ICacheService>();
  print('\ngetAll<ICacheService> resolved ${allCaches.length} implementations');
  await multiProvider.disposeAsync();

  // ── 8. replace — swap an implementation without rebuilding the collection ──
  // Useful during testing or when environment-specific overrides are applied
  // after the initial service registration pass.
  final overrideSc = ServiceCollection()
    ..addSingleton<ILogger, ConsoleLogger>()
    ..replace(ServiceDescriptor.factoryFn(
      serviceType: ILogger,
      lifetime: ServiceLifetime.singleton,
      factory: (_) => ConsoleLogger(), // swap to a different concrete type
    ));
  final overrideProvider = overrideSc.buildServiceProvider();
  final overriddenLogger = overrideProvider.getRequired<ILogger>();
  overriddenLogger.log('Resolved from overridden registration');
  await overrideProvider.disposeAsync();

  // ── 9. Options Pattern ──────────────────────────────────────────────────────
  // configure<T> registers Options<T> (singleton), OptionsSnapshot<T>
  // (scoped), and OptionsMonitor<T> (singleton) automatically.
  final optionsSc = ServiceCollection()
    ..configure<ServerOptions>(
      factory: ServerOptions.new,
      configure: (opts) {
        opts.host = 'api.prod.internal';
        opts.port = 443;
        opts.useSsl = true;
      },
    );

  final optionsProvider =
      optionsSc.buildServiceProvider(ServiceProviderOptions.production);

  final singletonOpts =
      optionsProvider.getRequired<Options<ServerOptions>>().value;
  print('\n[Options] host=${singletonOpts.host} port=${singletonOpts.port}'
      ' ssl=${singletonOpts.useSsl}');

  // OptionsMonitor supports live reload via keyed OptionsChangeNotifier.
  var reloadCount = 0;
  final monitor = optionsProvider.getRequired<OptionsMonitor<ServerOptions>>();
  final reg = monitor.onChange((opts, _) {
    reloadCount++;
    print('[Options] reloaded: host=${opts.host}');
  });

  final notifier =
      optionsProvider.getRequiredKeyed<OptionsChangeNotifier>(ServerOptions);
  notifier.notifyChange(Options.defaultName); // triggers the listener above
  print('[Options] reload count: $reloadCount');

  reg.dispose();
  optionsProvider.dispose();

  // ── 10. Configuration ───────────────────────────────────────────────
  // addConfiguration registers Configuration (and ConfigurationRoot)
  // as injectable singletons. Options can be bound directly from config.
  final config = ConfigurationBuilder().addMap({
    'server': {'host': 'config.prod.internal', 'port': 443, 'useSsl': true},
  }).build();

  final configSc = ServiceCollection()
    ..addConfiguration(config)
    ..configure<ServerOptions>(
      factory: ServerOptions.new,
      configure: (opts) {
        final s = config.getSection('server');
        opts.host = s['host'] ?? 'localhost';
        opts.port = int.parse(s['port'] ?? '8080');
        opts.useSsl = (s['useSsl'] ?? 'false') == 'true';
      },
    );

  final configProvider =
      configSc.buildServiceProvider(ServiceProviderOptions.production);

  final cfg = configProvider.getRequired<Configuration>();
  print('\n[Configuration] server:host=${cfg['server:host']}');

  final cfgOpts =
      configProvider.getRequired<Options<ServerOptions>>().value;
  print('[Configuration+Options] host=${cfgOpts.host} ssl=${cfgOpts.useSsl}');

  configProvider.dispose();

  // ── 11. Dispose the root provider ─────────────────────────────────────────
  await provider.disposeAsync();
}
