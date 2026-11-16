/// Turns off Riverpod's automatic retry of failing providers: a failure shows
/// its error at once, and the screens offer their own "Retry".
Duration? noProviderRetry(int retryCount, Object error) => null;
