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

  void _logNotSupported(String operation) => options.logger(
      SentryLevel.debug, 'SentryNative: $operation is not supported');

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
        var cUser = user.toJson().toNativeValue(options.logger);
        native.set_user(cUser);
      });
    }
  }

  FutureOr<void> addBreadcrumb(Breadcrumb breadcrumb) {
    tryCatchSync('add_breadcrumb', () {
      var cBreadcrumb = breadcrumb.toJson().toNativeValue(options.logger);
      native.add_breadcrumb(cBreadcrumb);
    });
  }

  FutureOr<void> clearBreadcrumbs() {
    _logNotSupported('clearing breadcrumbs');
  }

  FutureOr<Map<String, dynamic>?> loadContexts() {
    _logNotSupported('loading contexts');
    return null;
  }

  FutureOr<void> setContexts(String key, dynamic value) {
    tryCatchSync('set_context', () {
      final cValue = dynamicToNativeValue(value, options.logger);
      if (cValue != null) {
        final cKey = key.toNativeUtf8();
        native.set_context(cKey.cast(), cValue);
        malloc.free(cKey);
      } else {
        options.logger(SentryLevel.warning,
            'SentryNative: failed to set context $key - value couldn\'t be converted to native');
      }
    });
  }

  FutureOr<void> removeContexts(String key) {
    tryCatchSync('remove_context', () {
      final cKey = key.toNativeUtf8();
      native.remove_context(cKey.cast());
      malloc.free(cKey);
    });
  }

  FutureOr<void> setExtra(String key, dynamic value) {
    tryCatchSync('set_extra', () {
      final cValue = dynamicToNativeValue(value, options.logger);
      if (cValue != null) {
        final cKey = key.toNativeUtf8();
        native.set_extra(cKey.cast(), cValue);
        malloc.free(cKey);
      } else {
        options.logger(SentryLevel.warning,
            'SentryNative: failed to set extra $key - value couldn\'t be converted to native');
      }
    });
  }

  FutureOr<void> removeExtra(String key) {
    tryCatchSync('remove_extra', () {
      final cKey = key.toNativeUtf8();
      native.remove_extra(cKey.cast());
      malloc.free(cKey);
    });
  }

  FutureOr<void> setTag(String key, String value) {
    tryCatchSync('set_tag', () {
      final c = FreeableFactory();
      native.set_tag(c.str(key), c.str(value));
      c.freeAll();
    });
  }

  FutureOr<void> removeTag(String key) {
    tryCatchSync('set_tag', () {
      final cKey = key.toNativeUtf8();
      native.remove_tag(cKey.cast());
      malloc.free(cKey);
    });
  }

  int? startProfiler(SentryId traceId) =>
      throw UnsupportedError("Not supported on this platform");

  FutureOr<void> discardProfiler(SentryId traceId) =>
      throw UnsupportedError("Not supported on this platform");

  FutureOr<Map<String, dynamic>?> collectProfile(
          SentryId traceId, int startTimeNs, int endTimeNs) =>
      throw UnsupportedError("Not supported on this platform");

  FutureOr<int?> displayRefreshRate() {
    _logNotSupported('collecting display refresh rate');
    return null;
  }

  FutureOr<List<DebugImage>?> loadDebugImages() =>
      tryCatchSync('get_module_list', () {
        final cImages = native.get_modules_list();
        try {
          if (native.value_get_type(cImages) !=
              binding.sentry_value_type_t.SENTRY_VALUE_TYPE_LIST) {
            return null;
          }

          return List<DebugImage>.generate(native.value_get_length(cImages),
              (index) {
            final cImage = native.value_get_by_index(cImages, index);
            return DebugImage(
              type: cImage.get('type').castPrimitive(options.logger) ?? '',
              imageAddr: cImage.get('image_addr').castPrimitive(options.logger),
              imageSize: cImage.get('image_size').castPrimitive(options.logger),
              codeFile: cImage.get('code_file').castPrimitive(options.logger),
              debugId: cImage.get('debug_id').castPrimitive(options.logger),
              debugFile: cImage.get('debug_file').castPrimitive(options.logger),
              codeId: cImage.get('code_id').castPrimitive(options.logger),
            );
          });
        } finally {
          native.value_decref(cImages);
        }
      });

  FutureOr<void> pauseAppHangTracking() {}

  FutureOr<void> resumeAppHangTracking() {}
}

extension on binding.sentry_value_u {
  void setNativeValue(String key, binding.sentry_value_u? value) {
    final cKey = key.toNativeUtf8();
    if (value == null) {
      SentryNative.native.value_remove_by_key(this, cKey.cast());
    } else {
      SentryNative.native.value_set_by_key(this, cKey.cast(), value);
    }
    malloc.free(cKey);
  }

  binding.sentry_value_u get(String key) {
    final cKey = key.toNativeUtf8();
    try {
      return SentryNative.native.value_get_by_key(this, cKey.cast());
    } finally {
      malloc.free(cKey);
    }
  }

  T? castPrimitive<T>(SentryLogger logger) {
    if (SentryNative.native.value_is_null(this) == 1) {
      return null;
    }
    final type = SentryNative.native.value_get_type(this);
    switch (type) {
      case binding.sentry_value_type_t.SENTRY_VALUE_TYPE_NULL:
        return null;
      case binding.sentry_value_type_t.SENTRY_VALUE_TYPE_BOOL:
        return (SentryNative.native.value_is_true(this) == 1) as T;
      case binding.sentry_value_type_t.SENTRY_VALUE_TYPE_INT32:
        return SentryNative.native.value_as_int32(this) as T;
      case binding.sentry_value_type_t.SENTRY_VALUE_TYPE_DOUBLE:
        return SentryNative.native.value_as_double(this) as T;
      case binding.sentry_value_type_t.SENTRY_VALUE_TYPE_STRING:
        return SentryNative.native
            .value_as_string(this)
            .cast<Utf8>()
            .toDartString() as T;
      default:
        logger(SentryLevel.warning,
            'SentryNative: cannot read native value type: $type');
        return null;
    }
  }
}

binding.sentry_value_u? dynamicToNativeValue(
    dynamic value, SentryLogger logger) {
  if (value is String) {
    return value.toNativeValue();
  } else if (value is int) {
    return value.toNativeValue();
  } else if (value is double) {
    return value.toNativeValue();
  } else if (value is bool) {
    return value.toNativeValue();
  } else if (value is Map<String, dynamic>) {
    return value.toNativeValue(logger);
  } else if (value is List) {
    return value.toNativeValue(logger);
  } else if (value == null) {
    return SentryNative.native.value_new_null();
  } else {
    logger(SentryLevel.warning,
        'SentryNative: unsupported data for for conversion: ${value.runtimeType} ($value)');
    return null;
  }
}

extension on String {
  binding.sentry_value_u toNativeValue() {
    final cValue = this.toNativeUtf8();
    final result = SentryNative.native.value_new_string(cValue.cast());
    malloc.free(cValue);
    return result;
  }
}

extension on int {
  binding.sentry_value_u toNativeValue() {
    if (this > 0x7FFFFFFF) {
      return this.toString().toNativeValue();
    } else {
      return SentryNative.native.value_new_int32(this);
    }
  }
}

extension on double {
  binding.sentry_value_u toNativeValue() =>
      SentryNative.native.value_new_double(this);
}

extension on bool {
  binding.sentry_value_u toNativeValue() =>
      SentryNative.native.value_new_bool(this ? 1 : 0);
}

extension on Map<String, dynamic> {
  binding.sentry_value_u toNativeValue(SentryLogger logger) {
    final cObject = SentryNative.native.value_new_object();
    for (final entry in entries) {
      final cValue = dynamicToNativeValue(entry.value, logger);
      cObject.setNativeValue(entry.key, cValue);
    }
    return cObject;
  }
}

extension on List<dynamic> {
  binding.sentry_value_u toNativeValue(SentryLogger logger) {
    final cObject = SentryNative.native.value_new_list();
    for (final value in this) {
      final cValue = dynamicToNativeValue(value, logger);
      if (cValue != null) {
        SentryNative.native.value_append(cObject, cValue);
      }
    }
    return cObject;
  }
}
