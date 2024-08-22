import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
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
  static late final native =
      binding.SentryNative(DynamicLibrary.open('sentry.dll'));

  SentryNative(this.options);

  FutureOr<void> init(SentryFlutterOptions options) {
    assert(this.options == options);

    if (!options.enableNativeCrashHandling) {
      options.logger(
          SentryLevel.info, 'SentryNative crash handling is disabled');
    } else {
      tryCatchSync("init", () {
        final cOptions = createOptions(options);
        final code = native.init(cOptions);
        if (code != 0) {
          throw StateError(
              "Failed to initialize native SDK - init() exit code: $code");
        }
      });
    }
  }

  @visibleForTesting
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

  FutureOr<void> close() => native.close();

  FutureOr<NativeAppStart?> fetchNativeAppStart() => null;

  FutureOr<void> captureEnvelope(
      Uint8List envelopeData, bool containsUnhandledException) {
    throw UnimplementedError();
  }

  FutureOr<void> beginNativeFrames() {}

  FutureOr<NativeFrames?> endNativeFrames(SentryId id) => null;

  FutureOr<void> setUser(SentryUser? user) {
    if (user == null) {
      tryCatchSync('remove_user', native.remove_user);
    } else {
      tryCatchSync('set_user', () {
        // see https://develop.sentry.dev/sdk/event-payloads/user/
        var cUser = native.value_new_object();
        user.id?.toNativeValue(cUser, "id");
        user.username?.toNativeValue(cUser, "username");
        user.email?.toNativeValue(cUser, "email");
        user.ipAddress?.toNativeValue(cUser, "ip_address");
        user.name?.toNativeValue(cUser, "name");
        // TODO
        // user.data
        // user.geo
        native.set_user(cUser);
      });
    }
  }

  FutureOr<void> addBreadcrumb(Breadcrumb breadcrumb) {
    throw UnimplementedError();
  }

  FutureOr<void> clearBreadcrumbs() {
    throw UnimplementedError();
  }

  FutureOr<Map<String, dynamic>?> loadContexts() {
    throw UnimplementedError();
  }

  FutureOr<void> setContexts(String key, dynamic value) {
    throw UnimplementedError();
  }

  FutureOr<void> removeContexts(String key) {
    throw UnimplementedError();
  }

  FutureOr<void> setExtra(String key, dynamic value) {
    throw UnimplementedError();
  }

  FutureOr<void> removeExtra(String key) {
    throw UnimplementedError();
  }

  FutureOr<void> setTag(String key, String value) {
    throw UnimplementedError();
  }

  FutureOr<void> removeTag(String key) {
    throw UnimplementedError();
  }

  int? startProfiler(SentryId traceId) {
    throw UnimplementedError();
  }

  FutureOr<void> discardProfiler(SentryId traceId) {
    throw UnimplementedError();
  }

  FutureOr<int?> displayRefreshRate() {
    throw UnimplementedError();
  }

  FutureOr<Map<String, dynamic>?> collectProfile(
      SentryId traceId, int startTimeNs, int endTimeNs) {
    throw UnimplementedError();
  }

  FutureOr<List<DebugImage>?> loadDebugImages() {
    throw UnimplementedError();
  }

  FutureOr<void> pauseAppHangTracking() {}

  FutureOr<void> resumeAppHangTracking() {}
}

extension on String {
  void toNativeValue(binding.sentry_value_u obj, String key) {
    final cKey = key.toNativeUtf8();
    final cValue = this.toNativeUtf8();
    SentryNative.native.value_set_by_key(
        obj, cKey.cast(), SentryNative.native.value_new_string(cValue.cast()));
    malloc.free(cKey);
    malloc.free(cValue);
  }
}
