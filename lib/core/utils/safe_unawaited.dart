void safeUnawaited(
  Future<void> future, {
  void Function(Object error, StackTrace st)? onError,
}) {
  future.catchError((Object error, StackTrace st) {
    if (onError != null) {
      onError(error, st);
    }
  });
}
