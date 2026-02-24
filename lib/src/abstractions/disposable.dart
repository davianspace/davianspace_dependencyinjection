/// A mixin for services that hold synchronous resources and must be
/// released when their owning scope or the root provider is disposed.
///
/// Analogous to [System.IDisposable] in .NET.
mixin Disposable {
  /// Releases all resources held by this service.
  ///
  /// Implementations must be idempotent — calling [dispose] more than
  /// once must not throw.
  void dispose();
}
