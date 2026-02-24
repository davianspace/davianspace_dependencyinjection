/// The strategy kind for a [CallSite].
enum CallSiteKind {
  /// Resolved via a registered constructor factory from [ReflectionHelper].
  constructor,

  /// Resolved via a synchronous `factory` closure.
  factory,

  /// Resolved via an asynchronous `asyncFactory` closure.
  asyncFactory,

  /// A pre-built instance (singleton only).
  instance,

  /// Wraps another call site; caches result in [SingletonCache].
  singleton,

  /// Wraps another call site; caches result in [ScopedCache].
  scoped,

  /// Wraps another call site; never caches (new instance every time).
  transient,

  /// Routes through [KeyedServiceRegistry] by a key.
  keyed,

  /// Wraps another call site; applies one or more decorator closures.
  decorator,

  /// Wraps another call site's factory in a [Lazy] so that creation is
  /// deferred until the first [Lazy.value] access.
  lazy,

  /// Wraps another call site's factory as an [ServiceFactory] delegate.
  serviceFactory,
}
