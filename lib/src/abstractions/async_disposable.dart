/// A mixin for services that hold asynchronous resources and must be
/// released when their owning scope or the root provider is disposed.
///
/// Analogous to [System.IAsyncDisposable] in .NET.
mixin AsyncDisposable {
  /// Asynchronously releases all resources held by this service.
  ///
  /// Implementations must be idempotent — calling [disposeAsync] more than
  /// once must not throw.
  Future<void> disposeAsync();
}
