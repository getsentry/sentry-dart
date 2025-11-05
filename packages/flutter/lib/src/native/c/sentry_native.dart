import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../../replay/replay_config.dart';
import '../native_app_start.dart';
import '../sentry_native_binding.dart';
import '../sentry_native_invoker.dart';
import 'binding.dart' as binding;
import 'utils.dart';

@internal
class SentryNative with SentryNativeSafeInvoker implements SentryNativeBinding {
  @override
  final SentryFlutterOptions options;

  @visibleForTesting
  static final native = binding.SentryNative(DynamicLibrary.open(
      '$dynamicLibraryDirectory${Platform.isWindows ? 'sentry.dll' : 'libsentry.so'}'));

  /// If the path is just the library name, the loader will look for it in
  /// the usual places for shared libraries:
  /// - on Linux in /lib and /usr/lib
  /// - on Windows in the working directory and System32
  @visibleForTesting
  static String dynamicLibraryDirectory = '';

  @visibleForTesting
  static String? crashpadPath = _getDefaultCrashpadPath();

  SentryNative(this.options);

  void _logNotSupported(String operation) => options.log(
      SentryLevel.debug, 'SentryNative: $operation is not supported');

  @override
  FutureOr<void> init(Hub hub) {
    if (!options.enableNativeCrashHandling) {
      options.log(SentryLevel.info, 'SentryNative crash handling is disabled');
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
      if (options.nativeDatabasePath != null) {
        native.options_set_database_path(
            cOptions, c.str(options.nativeDatabasePath));
      }
      if (options.proxy != null) {
        // sentry-native expects a single string and it doesn't support different types or authentication
        options.log(SentryLevel.warning,
            'SentryNative: setting a proxy is currently not supported');
      }

      if (crashpadPath != null) {
        native.options_set_handler_path(cOptions, c.str(crashpadPath));
      } else {
        options.log(
            SentryLevel.warning, 'SentryNative: could not find crashpad path');
      }

      return cOptions;
    } finally {
      c.freeAll();
    }
  }

  @override
  FutureOr<void> close() {
    tryCatchSync('close', native.close);
  }

  @override
  FutureOr<NativeAppStart?> fetchNativeAppStart() => null;

  @override
  bool get supportsCaptureEnvelope => false;

  @override
  FutureOr<void> captureEnvelope(
      Uint8List envelopeData, bool containsUnhandledException) {
    throw UnsupportedError('$SentryNative.captureEnvelope() is not supported');
  }

  @override
  FutureOr<void> captureStructuredEnvelope(SentryEnvelope envelope) {
    throw UnsupportedError("Not supported on this platform");
  }

  @override
  FutureOr<void> setUser(SentryUser? user) {
    if (user == null) {
      tryCatchSync('remove_user', native.remove_user);
    } else {
      tryCatchSync('set_user', () {
        var cUser = user.toJson().toNativeValue(options.log);
        native.set_user(cUser);
      });
    }
  }

  @override
  FutureOr<void> addBreadcrumb(Breadcrumb breadcrumb) {
    tryCatchSync('add_breadcrumb', () {
      var cBreadcrumb = breadcrumb.toJson().toNativeValue(options.log);
      native.add_breadcrumb(cBreadcrumb);
    });
  }

  @override
  FutureOr<void> clearBreadcrumbs() {
    _logNotSupported('clearing breadcrumbs');
  }

  @override
  bool get supportsLoadContexts => false;

  @override
  FutureOr<Map<String, dynamic>?> loadContexts() {
    _logNotSupported('loading contexts');
    return null;
  }

  @override
  FutureOr<void> setContexts(String key, dynamic value) {
    tryCatchSync('set_context', () {
      final cValue = dynamicToNativeValue(value, options.log);
      if (cValue != null) {
        final cKey = key.toNativeUtf8();
        native.set_context(cKey.cast(), cValue);
        malloc.free(cKey);
      } else {
        options.log(SentryLevel.warning,
            'SentryNative: failed to set context $key - value couldn\'t be converted to native');
      }
    });
  }

  @override
  FutureOr<void> removeContexts(String key) {
    tryCatchSync('remove_context', () {
      final cKey = key.toNativeUtf8();
      native.remove_context(cKey.cast());
      malloc.free(cKey);
    });
  }

  @override
  FutureOr<void> setExtra(String key, dynamic value) {
    tryCatchSync('set_extra', () {
      final cValue = dynamicToNativeValue(value, options.log);
      if (cValue != null) {
        final cKey = key.toNativeUtf8();
        native.set_extra(cKey.cast(), cValue);
        malloc.free(cKey);
      } else {
        options.log(SentryLevel.warning,
            'SentryNative: failed to set extra $key - value couldn\'t be converted to native');
      }
    });
  }

  @override
  FutureOr<void> removeExtra(String key) {
    tryCatchSync('remove_extra', () {
      final cKey = key.toNativeUtf8();
      native.remove_extra(cKey.cast());
      malloc.free(cKey);
    });
  }

  @override
  FutureOr<void> setTag(String key, String value) {
    tryCatchSync('set_tag', () {
      final c = FreeableFactory();
      native.set_tag(c.str(key), c.str(value));
      c.freeAll();
    });
  }

  @override
  FutureOr<void> removeTag(String key) {
    tryCatchSync('remove_tag', () {
      final cKey = key.toNativeUtf8();
      native.remove_tag(cKey.cast());
      malloc.free(cKey);
    });
  }

  @override
  int? startProfiler(SentryId traceId) =>
      throw UnsupportedError("Not supported on this platform");

  @override
  FutureOr<void> discardProfiler(SentryId traceId) =>
      throw UnsupportedError("Not supported on this platform");

  @override
  FutureOr<Map<String, dynamic>?> collectProfile(
          SentryId traceId, int startTimeNs, int endTimeNs) =>
      throw UnsupportedError("Not supported on this platform");

  @override
  FutureOr<int?> displayRefreshRate() {
    _logNotSupported('collecting display refresh rate');
    return null;
  }

  @override
  FutureOr<List<DebugImage>?> loadDebugImages(SentryStackTrace stackTrace) =>
      tryCatchAsync('get_module_list', () async {
        final cImages = native.get_modules_list();
        try {
          if (native.value_get_type(cImages) !=
              binding.sentry_value_type_t.SENTRY_VALUE_TYPE_LIST) {
            return null;
          }

          final images = List<DebugImage>.generate(
              native.value_get_length(cImages), (index) {
            final cImage = native.value_get_by_index(cImages, index);
            return DebugImage(
              type: cImage.get('type').castPrimitive(options.log) ?? '',
              imageAddr: cImage.get('image_addr').castPrimitive(options.log),
              imageSize: cImage.get('image_size').castPrimitive(options.log),
              codeFile: cImage.get('code_file').castPrimitive(options.log),
              debugId: cImage.get('debug_id').castPrimitive(options.log),
              debugFile: cImage.get('debug_file').castPrimitive(options.log),
              codeId: cImage.get('code_id').castPrimitive(options.log),
            );
          });
          return images;
        } finally {
          native.value_decref(cImages);
        }
      });

  @override
  FutureOr<void> pauseAppHangTracking() {}

  @override
  FutureOr<void> resumeAppHangTracking() {}

  @override
  FutureOr<void> nativeCrash() {
    Pointer.fromAddress(1).cast<Utf8>().toDartString();
  }

  @override
  bool get supportsReplay => false;

  @override
  SentryId? get replayId => null;

  @override
  FutureOr<void> setReplayConfig(ReplayConfig config) {
    _logNotSupported('replay config');
  }

  @override
  FutureOr<SentryId> captureReplay() {
    _logNotSupported('capturing replay');
    return SentryId.empty();
  }

  @override
  FutureOr<void> startSession({bool ignoreDuration = false}) {
    _logNotSupported('starting session');
  }

  @override
  FutureOr<void> captureSession() {
    _logNotSupported('capturing session');
  }

  @override
  FutureOr<Map<dynamic, dynamic>?> getSession() {
    _logNotSupported('getting session');
    return null;
  }

  @override
  FutureOr<void> updateSession({int? errors, String? status}) {
    _logNotSupported('updating session');
  }
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

  T? castPrimitive<T>(SdkLogCallback logger) {
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
    dynamic value, SdkLogCallback logger) {
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
    final cValue = toNativeUtf8();
    final result = SentryNative.native.value_new_string(cValue.cast());
    malloc.free(cValue);
    return result;
  }
}

extension on int {
  binding.sentry_value_u toNativeValue() {
    if (this >= -2147483648 && this <= 2147483647) {
      return SentryNative.native.value_new_int32(this);
    } else {
      return toString().toNativeValue();
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
  binding.sentry_value_u toNativeValue(SdkLogCallback logger) {
    final cObject = SentryNative.native.value_new_object();
    for (final entry in entries) {
      final cValue = dynamicToNativeValue(entry.value, logger);
      cObject.setNativeValue(entry.key, cValue);
    }
    return cObject;
  }
}

extension on List<dynamic> {
  binding.sentry_value_u toNativeValue(SdkLogCallback logger) {
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

String? _getDefaultCrashpadPath() {
  if (Platform.isLinux) {
    final lastSeparator =
        Platform.resolvedExecutable.lastIndexOf(Platform.pathSeparator);
    if (lastSeparator >= 0) {
      final appDir = Platform.resolvedExecutable.substring(0, lastSeparator);
      final candidates = [
        '$appDir${Platform.pathSeparator}crashpad_handler',
        '$appDir${Platform.pathSeparator}bin${Platform.pathSeparator}crashpad_handler',
        '$appDir${Platform.pathSeparator}lib${Platform.pathSeparator}crashpad_handler'
      ];
      return candidates.firstWhereOrNull((path) => File(path).existsSync());
    }
  }
  return null;
}
