import 'dart:ffi';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../native_app_start.dart';
import '../native_frames.dart';
import '../sentry_native_binding.dart';
import '../sentry_native_invoker.dart';
import 'binding.dart' as binding;
import 'utils.dart';

@internal
class SentryNative with SentryNativeSafeInvoker implements SentryNativeBinding {
  final SentryFlutterOptions options;

  @visibleForTesting
  late final native = binding.SentryNative(DynamicLibrary.open('sentry.dll'));

  SentryNative(this.options);

  Future<void> init(SentryFlutterOptions options) async {
    assert(this.options == options);

    if (!options.enableNativeCrashHandling) {
      options.logger(
          SentryLevel.info, 'SentryNative crash handling is disabled');
      return;
    }

    tryCatchSync("init", () {
      final cOptions = createOptions(options);
      final code = native.init(cOptions);
      if (code != 0) {
        throw StateError(
            "Failed to initialize native SDK - init() exit code: $code");
      }
    });
  }

  Pointer<binding.sentry_options_s> createOptions(
      SentryFlutterOptions options) {
    final c = FreeableFactory();
    try {
      final cOptions = native.options_new();
      native.options_set_dsn(cOptions, c.str(options.dsn));
      native.options_set_debug(cOptions, options.debug ? 1 : 0);
      native.options_set_environment(cOptions, c.str(options.environment));
      native.options_set_release(cOptions, c.str(options.release));
      native.options_set_auto_session_tracking(
          cOptions, options.enableAutoSessionTracking ? 1 : 0);
      native.options_set_dist(cOptions, c.str(options.dist));
      native.options_set_max_breadcrumbs(cOptions, options.maxBreadcrumbs);
      if (options.proxy != null) {
        // sentry-native expects a single string and it doesn't support different types or authentication
        options.logger(SentryLevel.warning,
            'SentryNative: setting a proxy is currently not supported');
      }
      return cOptions;
    } finally {
      c.freeAll();
    }
  }

  Future<void> close() {
    throw UnimplementedError();
  }

  Future<NativeAppStart?> fetchNativeAppStart() {
    throw UnimplementedError();
  }

  Future<void> captureEnvelope(
      Uint8List envelopeData, bool containsUnhandledException) {
    throw UnimplementedError();
  }

  Future<void> beginNativeFrames() {
    throw UnimplementedError();
  }

  Future<NativeFrames?> endNativeFrames(SentryId id) {
    throw UnimplementedError();
  }

  Future<void> setUser(SentryUser? user) {
    throw UnimplementedError();
  }

  Future<void> addBreadcrumb(Breadcrumb breadcrumb) {
    throw UnimplementedError();
  }

  Future<void> clearBreadcrumbs() {
    throw UnimplementedError();
  }

  Future<Map<String, dynamic>?> loadContexts() {
    throw UnimplementedError();
  }

  Future<void> setContexts(String key, dynamic value) {
    throw UnimplementedError();
  }

  Future<void> removeContexts(String key) {
    throw UnimplementedError();
  }

  Future<void> setExtra(String key, dynamic value) {
    throw UnimplementedError();
  }

  Future<void> removeExtra(String key) {
    throw UnimplementedError();
  }

  Future<void> setTag(String key, String value) {
    throw UnimplementedError();
  }

  Future<void> removeTag(String key) {
    throw UnimplementedError();
  }

  int? startProfiler(SentryId traceId) {
    throw UnimplementedError();
  }

  Future<void> discardProfiler(SentryId traceId) {
    throw UnimplementedError();
  }

  Future<int?> displayRefreshRate() {
    throw UnimplementedError();
  }

  Future<Map<String, dynamic>?> collectProfile(
      SentryId traceId, int startTimeNs, int endTimeNs) {
    throw UnimplementedError();
  }

  Future<List<DebugImage>?> loadDebugImages() {
    throw UnimplementedError();
  }

  Future<void> pauseAppHangTracking() {
    throw UnimplementedError();
  }

  Future<void> resumeAppHangTracking() {
    throw UnimplementedError();
  }
}
