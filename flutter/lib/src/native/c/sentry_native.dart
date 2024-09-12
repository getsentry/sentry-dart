import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:collection/collection.dart';
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
  DebugImage? _appDebugImage;
  final SentryFlutterOptions options;

  @visibleForTesting
  static late final native =
      binding.SentryNative(DynamicLibrary.open('sentry.dll'));

  SentryNative(this.options);

  void _logNotSupported(String operation) => options.logger(
      SentryLevel.debug, 'SentryNative: $operation is not supported');

  FutureOr<void> init(Hub hub) {
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

  bool get supportsCaptureEnvelope => false;

  FutureOr<void> captureEnvelope(
      Uint8List envelopeData, bool containsUnhandledException) {
    throw UnsupportedError('$SentryNative.captureEnvelope() is not suppurted');
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

  bool get supportsLoadContexts => false;

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
              type: cImage.get('type').castPrimitive(options.logger) ?? '',
              imageAddr: cImage.get('image_addr').castPrimitive(options.logger),
              imageSize: cImage.get('image_size').castPrimitive(options.logger),
              codeFile: cImage.get('code_file').castPrimitive(options.logger),
              debugId: cImage.get('debug_id').castPrimitive(options.logger),
              debugFile: cImage.get('debug_file').castPrimitive(options.logger),
              codeId: cImage.get('code_id').castPrimitive(options.logger),
            );
          });

          // On windows, we need to add the ELF debug image of the AOT code.
          // See https://github.com/flutter/flutter/issues/154840
          if (options.platformChecker.platform.isWindows) {
            _appDebugImage ??= await getAppDebugImage(stackTrace, images);
            if (_appDebugImage != null) {
              images.add(_appDebugImage!);
            }
          }

          return images;
        } finally {
          native.value_decref(cImages);
        }
      });

  @visibleForTesting
  Future<DebugImage?> getAppDebugImage(
      SentryStackTrace stackTrace, Iterable<DebugImage> nativeImages) async {
    // ignore: invalid_use_of_internal_member
    final buildId = stackTrace.nativeBuildId;
    // ignore: invalid_use_of_internal_member
    final imageAddr = stackTrace.nativeImageBaseAddr;

    if (buildId == null || imageAddr == null) {
      return null;
    }

    final exePath = nativeImages
        .firstWhereOrNull(
            (image) => image.codeFile?.toLowerCase().endsWith('.exe') ?? false)
        ?.codeFile;
    if (exePath == null) {
      options.logger(
          SentryLevel.debug,
          "Couldn't add AOT ELF image for server-side symbolication because the "
          "app executable is not among the debug images reported by native.");
      return null;
    }

    final appSoFile = options.fileSystem
        .file(exePath)
        .parent
        .childDirectory('data')
        .childFile('app.so');
    if (!await appSoFile.exists()) {
      options.logger(SentryLevel.debug,
          "Couldn't add AOT ELF image because ${appSoFile.path} doesn't exist.");
      return null;
    }

    final stat = await appSoFile.stat();
    return DebugImage(
      type: 'elf',
      imageAddr: imageAddr,
      imageSize: stat.size,
      codeFile: appSoFile.path,
      codeId: buildId,
      debugId: _computeDebugId(buildId),
    );
  }

  /// See https://github.com/getsentry/symbolic/blob/7dc28dd04c06626489c7536cfe8c7be8f5c48804/symbolic-debuginfo/src/elf.rs#L709-L734
  /// Converts an ELF object identifier into a `DebugId`.
  ///
  /// The identifier data is first truncated or extended to match 16 byte size of
  /// Uuids. If the data is declared in little endian, the first three Uuid fields
  /// are flipped to match the big endian expected by the breakpad processor.
  ///
  /// The `DebugId::appendix` field is always `0` for ELF.
  String? _computeDebugId(String buildId) {
    // Make sure that we have exactly UUID_SIZE bytes available
    const uuidSize = 16 * 2;
    final data = Uint8List(uuidSize);
    final len = buildId.length.clamp(0, uuidSize);
    data.setAll(0, buildId.codeUnits.take(len));

    if (Endian.host == Endian.little) {
      // The file ELF file targets a little endian architecture. Convert to
      // network byte order (big endian) to match the Breakpad processor's
      // expectations. For big endian object files, this is not needed.
      // To manipulate this as hex, we create an Uint16 view.
      final data16 = Uint16List.view(data.buffer);
      data16.setRange(0, 4, data16.sublist(0, 4).reversed);
      data16.setRange(4, 6, data16.sublist(4, 6).reversed);
      data16.setRange(6, 8, data16.sublist(6, 8).reversed);
    }

    return String.fromCharCodes(data);
  }

  FutureOr<void> pauseAppHangTracking() {}

  FutureOr<void> resumeAppHangTracking() {}

  FutureOr<void> nativeCrash() {
    Pointer.fromAddress(1).cast<Utf8>().toDartString();
  }

  FutureOr<SentryId> captureReplay(bool isCrash) {
    _logNotSupported('capturing replay');
    return SentryId.empty();
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
