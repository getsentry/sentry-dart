import 'sentry_native_wrapper.dart';

class NoOpSentryNativeWrapper implements SentryNativeWrapper {
  @override
  Future<NativeAppStart?> fetchNativeAppStart() async {
    return null;
  }
}
